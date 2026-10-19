import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../models/gift_item.dart';
import '../../providers/core_providers.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';
import 'inventory_screen.dart';

/// افزودن گیفت تلگرام — با لینک، مثل MRKT:
/// گیفت را در تلگرام باز کن ← کپی لینک ← اینجا بچسبان
class AddGiftScreen extends ConsumerStatefulWidget {
  const AddGiftScreen({super.key});

  @override
  ConsumerState<AddGiftScreen> createState() => _AddGiftScreenState();
}

class _AddGiftScreenState extends ConsumerState<AddGiftScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  GiftItem? _found;

  Future<void> _detect() async {
    final link = _ctrl.text.trim();
    if (link.isEmpty) {
      setState(() => _error = 'لینک گیفت را بچسبان');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _found = null;
    });
    try {
      final api = ref.read(apiProvider);
      final r = await api.resolveGift(link);
      final g = GiftItem.fromResolved((r as Map).cast<String, dynamic>());
      // اگر کیف پول وصل است، اول انبار را تازه کن بعد ببین مال توست
      final inv = ref.read(inventoryProvider.notifier);
      final wallet = ref.read(walletProvider);
      if (wallet.isConnected && inv.state.items.isEmpty) {
        await inv.refresh();
      }
      final mine = inv.findMine(g.name, g.number);
      setState(() => _found = mine ?? g);
    } on ApiException catch (e) {
      setState(() => _error = e.detail);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openTelegram() async {
    try {
      await launchUrl(Uri.parse('tg://'), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) toast(context, 'تلگرام باز نشد — آیا تلگرام نصب است؟', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).s;
    final wallet = ref.watch(walletProvider);
    final isMine = _found != null && _found!.kind == 'owner';

    return Scaffold(
      appBar: AppBar(title: Text(s.addToInventory)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // مراحل
            _step(s.step1, Icons.telegram_rounded),
            _step(s.step2, Icons.more_vert_rounded),
            _step(s.step3, Icons.content_paste_rounded),
            const SizedBox(height: 14),
            GhostButton(label: s.openTelegram, onTap: _openTelegram),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(hintText: s.pasteLinkHint),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: Color(AppColors.red))),
            ],
            const SizedBox(height: 14),
            YellowButton(label: s.detectGift, busy: _loading, onTap: _detect),
            const SizedBox(height: 20),
            // نتیجه
            if (_found != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(AppColors.card),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isMine ? const Color(AppColors.green).withOpacity(0.5) : const Color(AppColors.stroke),
                  ),
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 170,
                        height: 170,
                        child: Image.network(
                          _found!.effectiveImage,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Image.network(_found!.imageFallback,
                              fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard_rounded, size: 54, color: Color(AppColors.textDim))),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(_found!.displayName, style: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    InfoRow(label: s.giftId, value: _found!.slug, copyable: true),
                    Row(
                      children: [
                        Icon(
                          isMine ? Icons.check_circle_rounded : Icons.info_rounded,
                          size: 16,
                          color: isMine ? const Color(AppColors.green) : const Color(AppColors.yellow),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isMine
                                ? '${s.from}: ${s.you} — آماده فروش است'
                                : wallet.isConnected
                                    ? s.notInYourWallet
                                    : s.notInYourWallet,
                            style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, height: 1.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (isMine)
                YellowButton(
                  label: s.sellGift,
                  onTap: () {
                    Navigator.pop(context);
                    toast(context, 'از انبار روی گیفت بزن و «فروش گیفت» را انتخاب کن');
                  },
                )
              else ...[
                if (!wallet.isConnected)
                  YellowButton(
                    label: s.connectWallet,
                    onTap: () {
                      Navigator.pop(context);
                      toast(context, 'از بالای صفحه کیف پول را وصل کن تا انبارت خودکار پر شود');
                    },
                  ),
              ],
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _step(String text, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(AppColors.card),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(AppColors.stroke)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(AppColors.yellow)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, height: 1.8)),
          ),
        ],
      ),
    );
  }
}
