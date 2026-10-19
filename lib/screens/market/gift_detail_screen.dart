import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/ton_utils.dart';
import '../../models/gift_item.dart';
import '../../models/models.dart';
import '../../providers/core_providers.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';
import '../../widgets/tx_flow.dart';

/// جزئیات گیفت — عکس واقعی + مشخصات + آیدی گیفت + باز کردن در تلگرام + خرید
class GiftDetailScreen extends ConsumerStatefulWidget {
  final GiftItem item;
  const GiftDetailScreen({super.key, required this.item});

  @override
  ConsumerState<GiftDetailScreen> createState() => _GiftDetailScreenState();
}

class _GiftDetailScreenState extends ConsumerState<GiftDetailScreen> {
  bool _busy = false;
  late GiftItem g;

  @override
  void initState() {
    super.initState();
    g = widget.item;
  }

  Future<void> _buy() async {
    setState(() => _busy = true);
    try {
      final api = ref.read(apiProvider);
      final r = await api.nftBuy([
        {'nft_address': g.address, 'price': (g.priceTon! * 1e9).round().toString(), 'currency': g.currency},
      ]);
      final tx = (r is Map && r['transaction'] is Map) ? (r['transaction'] as Map).cast<String, dynamic>() : null;
      if (tx == null) throw ApiException(0, 'تراکنشی از سرور برنگشت');
      if (!mounted) return;
      await runTxFlow(
        context,
        ref,
        tx: tx,
        title: 'خرید ${g.displayName}',
        subtitle: 'قیمت: ${fmtTon(g.priceTon)} ${g.currency}',
        type: OrderType.gift,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isPaidRequired) {
        toast(context, 'خرید NFT نیازمند فعال‌سازی پلن API در بک‌اند است', error: true);
      } else {
        toast(context, e.detail, error: true);
      }
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rent() async {
    setState(() => _busy = true);
    try {
      final api = ref.read(apiProvider);
      // duration به ثانیه (از فید) و قیمت روزانه دقیقاً همان رشته نانوتون فید
      final int duration =
          (g.raw['min_duration'] is int) ? g.raw['min_duration'] as int : 86400;
      final String ppd = (g.raw['price_per_day'] ?? '').toString();
      if (ppd.isEmpty) throw ApiException(0, 'قیمت اجاره این گیفت در دسترس نیست');
      final r = await api.rentPay(g.address,
          duration: duration, pricePerDayNano: ppd);
      final tx = (r is Map && r['transaction'] is Map) ? (r['transaction'] as Map).cast<String, dynamic>() : null;
      if (tx == null) throw ApiException(0, 'تراکنشی از سرور برنگشت');
      if (!mounted) return;
      final days = (duration / 86400).round();
      await runTxFlow(
        context,
        ref,
        tx: tx,
        title: 'اجاره ${g.displayName}',
        subtitle: 'قیمت روزانه: ${fmtTon(g.pricePerDayTon)} TON • مدت: $days روز',
        type: OrderType.gift,
      );
    } on ApiException catch (e) {
      if (mounted) toast(context, e.detail, error: true);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openTg() async {
    final uri = Uri.parse(g.telegramUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) toast(context, 'تلگرام باز نشد — لینک: ${g.telegramUrl}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).s;
    final wallet = ref.watch(walletProvider);
    final isStars = g.currency.toUpperCase() == 'STARS';
    final isMine = wallet.isConnected && g.owner != null && tonSameAddress(g.owner, wallet.address);

    return Scaffold(
      appBar: AppBar(title: Text(g.displayName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // عکس واقعی گیفت (مدل + بک‌گراند)
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(AppColors.stroke)),
                  color: const Color(AppColors.card),
                ),
                clipBehavior: Clip.antiAlias,
                child: _bigImage(),
              ),
            ),
            const SizedBox(height: 14),
            // آیدی گیفت
            InfoRow(label: s.giftId, value: g.slug, copyable: true),
            // قیمت
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(AppColors.card),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(AppColors.stroke)),
              ),
              child: Row(
                children: [
                  Icon(isStars ? Icons.star_rounded : Icons.diamond_outlined,
                      size: 20, color: const Color(AppColors.yellow)),
                  const SizedBox(width: 8),
                  Text(
                    g.kind == 'rent'
                        ? '${fmtTon(g.pricePerDayTon)} TON / روز'
                        : isStars
                            ? '${fmtStars(parseNumFlexible(g.raw['min_bid']) ?? 0)} ★'
                            : '${fmtTon(g.priceTon)} TON',
                    style: const TextStyle(
                        fontFamily: 'Vazirmatn', fontSize: 18, fontWeight: FontWeight.w800, color: Color(AppColors.yellow)),
                  ),
                  const Spacer(),
                  ChipTag(label: g.kind == 'rent' ? s.forRent : s.forSale),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // مشخصات
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (g.model != null) ChipTag(label: s.model, value: g.model),
                if (g.backdrop != null) ChipTag(label: s.backdrop, value: g.backdrop),
                if (g.symbol != null) ChipTag(label: s.symbol, value: g.symbol),
              ],
            ),
            const SizedBox(height: 10),
            if (g.owner != null && g.owner!.isNotEmpty)
              InfoRow(label: s.from, value: isMine ? s.you : shortAddr(g.owner!), copyable: !isMine),
            const SizedBox(height: 18),
            // دکمه‌ها
            if (g.kind == 'sale' && g.status == 'for_sale' && !isMine)
              YellowButton(label: s.buyWithTon, busy: _busy, onTap: _buy),
            if (g.kind == 'rent') YellowButton(label: s.rentNow, busy: _busy, onTap: _rent),
            const SizedBox(height: 10),
            GhostButton(label: s.openInTelegram, onTap: _openTg),
            const SizedBox(height: 26),
          ],
        ),
      ),
    );
  }

  Widget _bigImage() {
    return Image.network(
      g.effectiveImage,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Image.network(g.imageFallback, fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard_rounded, size: 70, color: Color(AppColors.textDim))),
      loadingBuilder: (c, w, p) => p == null ? w : const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(AppColors.yellow))),
    );
  }
}
