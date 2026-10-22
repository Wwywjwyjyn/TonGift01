import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../models/gift_item.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/core_providers.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';
import '../../widgets/tx_flow.dart';
import '../../widgets/gift_card.dart';
import '../market/gift_detail_screen.dart';

/// سبد خرید — پرداخت واقعی و پشت‌سرهم هر گیفت با کیف پول TON Connect
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _checking = false;
  final Set<String> _done = {};
  final Map<String, String> _failed = {};
  String? _current; // گیفت در حال پرداخت

  Future<void> _checkout() async {
    final s = ref.read(settingsProvider).s;
    final items = ref.read(cartProvider).items;
    if (items.isEmpty) return;
    setState(() {
      _checking = true;
      _done.clear();
      _failed.clear();
    });
    for (final g in items) {
      if (!mounted) return;
      setState(() => _current = g.address);
      try {
        final api = ref.read(apiProvider);
        final r = await api.nftBuy([
          {'nft_address': g.address, 'price': ((g.priceTon ?? 0) * 1e9).round().toString(), 'currency': g.currency},
        ]);
        final tx = (r is Map && r['transaction'] is Map) ? (r['transaction'] as Map).cast<String, dynamic>() : null;
        if (tx == null) throw ApiException(0, s.serverResponseIncomplete);
        if (!mounted) return;
        final sent = await runTxFlow(
          context,
          ref,
          tx: tx,
          title: '${s.cart}: ${g.displayName}',
          subtitle: '${fmtTon(g.priceTon)} ${g.currency}',
          type: OrderType.gift,
        );
        if (!mounted) return;
        if (sent == true) {
          // تراکنش ارسال شد → از سبد حذف می‌شود
          setState(() => _done.add(g.address));
          ref.read(cartProvider.notifier).remove(g.address);
        } else {
          setState(() => _failed[g.address] = s.txRejected);
          break; // کاربر رد کرد — ادامه با بقیه بی‌معناست
        }
      } on ApiException catch (e) {
        if (!mounted) return;
        final msg = e.isPaidRequired
            ? (s.fa ? 'نیازمند فعال‌سازی پلن API در بک‌اند' : 'Needs the API plan activation on the backend')
            : e.detail;
        setState(() => _failed[g.address] = msg);
        // خطای پلن یا موجودی — ادامه با مورد بعدی بی‌معناست؛ متوقف می‌شویم
        if (e.isPaidRequired) break;
      } catch (e) {
        if (!mounted) return;
        setState(() => _failed[g.address] = '$e');
      }
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _current = null;
    });
    final okCount = _done.length;
    if (okCount > 0) toast(context, s.fa ? '$okCount گیفت پرداخت شد ✓' : '$okCount gifts paid ✓');
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final s = ref.watch(settingsProvider).s;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.cart),
        actions: [
          if (cart.items.isNotEmpty && !_checking)
            IconButton(
              onPressed: () {
                ref.read(cartProvider.notifier).clear();
                setState(() {
                  _done.clear();
                  _failed.clear();
                });
                toast(context, s.cartCleared);
              },
              icon: const Icon(Icons.delete_sweep_rounded, size: 20, color: Color(AppColors.red)),
            ),
        ],
      ),
      body: cart.items.isEmpty
          ? EmptyPanel(
              title: s.cartEmpty,
              subtitle: s.cartEmptyDesc,
              icon: Icons.shopping_cart_outlined,
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final g = cart.items[i];
                      final isDone = _done.contains(g.address);
                      final failMsg = _failed[g.address];
                      final isCurrent = _current == g.address;
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(AppColors.card),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDone
                                ? const Color(AppColors.green).withOpacity(0.5)
                                : failMsg != null
                                    ? const Color(AppColors.red).withOpacity(0.5)
                                    : isCurrent
                                        ? const Color(AppColors.yellow).withOpacity(0.6)
                                        : const Color(AppColors.stroke),
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: GiftImage(item: g, width: 58, height: 58),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => GiftDetailScreen(item: g)),
                                    ),
                                    child: Text(
                                      g.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    g.slug,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, color: Color(AppColors.textDim)),
                                  ),
                                  const SizedBox(height: 4),
                                  if (failMsg != null)
                                    Text(
                                      '${s.itemFailed}: $failMsg',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, color: Color(AppColors.red)),
                                    )
                                  else if (isDone)
                                    Text(
                                      '✓ ${s.itemDone}',
                                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(AppColors.green)),
                                    )
                                  else if (isCurrent)
                                    Text(
                                      s.waitingWallet,
                                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10.5, color: Color(AppColors.yellow)),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // قیمت
                            Text(
                              '${fmtTon(g.priceTon)} TON',
                              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(AppColors.yellow)),
                            ),
                            // حذف
                            if (!_checking)
                              GestureDetector(
                                onTap: () => ref.read(cartProvider.notifier).remove(g.address),
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(Icons.close_rounded, size: 17, color: Color(AppColors.textDim)),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // پایین — مجموع و پرداخت
                Container(
                  padding: EdgeInsets.fromLTRB(14, 12, 14, 14 + MediaQuery.of(context).padding.bottom * 0.5),
                  decoration: const BoxDecoration(
                    color: Color(AppColors.surface),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border(top: BorderSide(color: Color(AppColors.stroke))),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            s.total(cart.items.length),
                            style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          const Icon(Icons.diamond_outlined, size: 16, color: Color(AppColors.yellow)),
                          const SizedBox(width: 5),
                          Text(
                            '${fmtTon(cart.totalTon)} TON',
                            style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 16, fontWeight: FontWeight.w800, color: Color(AppColors.yellow)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.sequentialNote,
                        style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10.5, color: Color(AppColors.textDim)),
                      ),
                      const SizedBox(height: 10),
                      YellowButton(
                        label: _checking ? s.loading : s.checkout,
                        busy: _checking,
                        onTap: _checking ? null : _checkout,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
