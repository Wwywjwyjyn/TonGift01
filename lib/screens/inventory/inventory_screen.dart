import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../models/gift_item.dart';
import '../../providers/core_providers.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/gift_card.dart';
import '../../widgets/common.dart';
import '../../widgets/wallet_sheet.dart';
import '../market/gift_detail_screen.dart';
import 'add_gift_screen.dart';

/// انبار من — گیفت‌های کیف پول متصل + فروش/قیمت/لغو
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final w = ref.read(walletProvider);
      if (w.isConnected) ref.read(inventoryProvider.notifier).refresh();
    });
  }

  Future<void> _onItemTap(GiftItem g) async {
    final s = ref.read(settingsProvider).s;
    final actions = [
      _Action(Icons.sell_rounded, s.sellGift, 'sell'),
      if (g.status == 'for_sale') _Action(Icons.price_change_rounded, s.changePrice, 'price'),
      if (g.status == 'for_sale') _Action(Icons.cancel_rounded, s.cancelSale, 'cancel'),
      _Action(Icons.visibility_rounded, s.openInTelegram, 'tg'),
    ];

    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(g.displayName, style: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w800, fontSize: 15)),
            Text(g.slug, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: Color(AppColors.textDim))),
            const Divider(height: 20),
            ...actions.map((a) => ListTile(
                  leading: Icon(a.icon, size: 21, color: const Color(AppColors.yellow)),
                  title: Text(a.label, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13.5)),
                  onTap: () => Navigator.pop(context, a.id),
                  contentPadding: EdgeInsets.zero,
                )),
          ],
        ),
      ),
    );

    if (picked == null || !mounted) return;
    switch (picked) {
      case 'sell':
      case 'price':
        _askPrice(g, isChange: picked == 'price');
        break;
      case 'cancel':
        _cancelSale(g);
        break;
      case 'tg':
        Navigator.push(context, MaterialPageRoute(builder: (_) => GiftDetailScreen(item: g)));
        break;
    }
  }

  Future<void> _askPrice(GiftItem g, {required bool isChange}) async {
    final s = ref.read(settingsProvider).s;
    final ctrl = TextEditingController(text: g.priceTon != null ? fmtTon(g.priceTon) : '');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isChange ? s.changePrice : s.sellGift,
              style: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text('${g.displayName} — ${g.slug}',
                style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, color: Color(AppColors.textDim))),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(hintText: s.sellPriceHint),
            ),
            const SizedBox(height: 8),
            const Text(
              'پس از تأیید، تراکنش اتصال گیفت به قرارداد فروش را در کیف پولت امضا می‌کنی — کاملاً روی بلاکچین.',
              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, height: 1.9, color: Color(AppColors.textDim)),
            ),
            const SizedBox(height: 14),
            YellowButton(
              label: isChange ? s.changePrice : s.sellGift,
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final price = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
    if (price <= 0) {
      toast(context, 'قیمت معتبر نیست', error: true);
      return;
    }
    try {
      final inv = ref.read(inventoryProvider.notifier);
      final tx = isChange ? await inv.changePrice(g, price) : await inv.sell(g, price);
      if (!mounted) return;
      // تراکنش را از طریق جریان استاندارد بفرست
      final sent = await _sendTx(context, tx, '${isChange ? 'تغییر قیمت' : 'فروش'} ${g.displayName}');
      if (sent && mounted) {
        toast(context, 'درخواست ثبت شد — پس از تأیید شبکه، گیفت در مارکت لیست می‌شود');
        ref.read(inventoryProvider.notifier).refresh();
      }
    } catch (e) {
      if (mounted) toast(context, e.toString().replaceAll('ApiException: ', ''), error: true);
    }
  }

  Future<bool> _sendTx(BuildContext context, Map<String, dynamic> tx, String title) async {
    // استفاده از runTxFlow بدون order جدید (سفارش از قبل ثبت می‌شود داخل آن)
    final res = await showModalBottomSheet<bool>(
      context: context,
      builder: (_) => _SimpleTxSheet(tx: tx, title: title),
    );
    return res == true;
  }

  Future<void> _cancelSale(GiftItem g) async {
    try {
      final tx = await ref.read(inventoryProvider.notifier).cancelSale(g);
      if (!mounted) return;
      final sent = await _sendTx(context, tx, 'لغو فروش ${g.displayName}');
      if (sent && mounted) {
        toast(context, 'لغو فروش ثبت شد');
        ref.read(inventoryProvider.notifier).refresh();
      }
    } catch (e) {
      if (mounted) toast(context, e.toString().replaceAll('ApiException: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).s;
    final wallet = ref.watch(walletProvider);
    final inv = ref.watch(inventoryProvider);

    if (!wallet.isConnected) {
      return EmptyPanel(
        icon: Icons.account_balance_wallet_rounded,
        title: s.connectWallet,
        subtitle: 'برای دیدن و فروش گیفت‌هایت، کیف پول TON را وصل کن — بدون ثبت‌نام',
        action: YellowButton(
          label: s.connectWallet,
          onTap: () => showWalletSheet(context),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(AppColors.yellow),
      backgroundColor: const Color(AppColors.card),
      onRefresh: () => ref.read(inventoryProvider.notifier).refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // آدرس + موجودی
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(AppColors.card),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(AppColors.stroke)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.diamond_outlined, size: 17, color: Color(AppColors.yellow)),
                        const SizedBox(width: 8),
                        Text('${fmtTon(wallet.balanceTon)} TON',
                            style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, fontWeight: FontWeight.w800, color: Color(AppColors.yellow))),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => copyText(context, wallet.address ?? ''),
                          child: Text(shortAddr(wallet.address),
                              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, color: Color(AppColors.textDim))),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.copy_rounded, size: 14, color: Color(AppColors.textDim)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // افزودن گیفت تلگرام
                  YellowButton(
                    label: s.addToInventory,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddGiftScreen()),
                    ),
                  ),
                  if (inv.info != null) ...[
                    const SizedBox(height: 8),
                    Text(inv.info!, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10.5, color: Color(AppColors.textDim))),
                  ],
                ],
              ),
            ),
          ),
          if (inv.loading)
            const SliverPadding(
              padding: EdgeInsets.all(14),
              sliver: SliverToBoxAdapter(child: LoadingGrid()),
            )
          else if (inv.error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorPanel(message: inv.error!, onRetry: () => ref.read(inventoryProvider.notifier).refresh()),
            )
          else if (inv.items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyPanel(
                icon: Icons.inventory_2_rounded,
                title: s.myGifts,
                subtitle: 'گیفتی در این کیف پول پیدا نشد. با «افزودن گیفت تلگرام» لینک گیفتت را بده.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final g = inv.items[i];
                    return Stack(
                      children: [
                        GiftCard(
                          item: g,
                          onTap: () => _onItemTap(g),
                        ),
                        if (g.status == 'for_sale')
                          Positioned(
                            bottom: 56,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${fmtTon(g.priceTon)} ${g.currency}',
                                style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, color: Color(AppColors.green), fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                  childCount: inv.items.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
        ],
      ),
    );
  }
}

/// شیت ساده ارسال تراکنش (برای sale/cancel)
class _SimpleTxSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> tx;
  final String title;
  const _SimpleTxSheet({required this.tx, required this.title});

  @override
  ConsumerState<_SimpleTxSheet> createState() => _SimpleTxSheetState();
}

class _SimpleTxSheetState extends ConsumerState<_SimpleTxSheet> {
  bool _sending = false;
  bool _done = false;
  bool _failed = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await ref.read(tonConnectServiceProvider).sendTransaction(widget.tx);
      _done = true;
    } catch (_) {
      _failed = true;
    }
    if (!mounted) return;
    setState(() => _sending = false);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.pop(context, _done && !_failed);
  }

  @override
  Widget build(BuildContext context) {
    final msgs = (widget.tx['messages'] as List?) ?? const [];
    double amount = 0;
    String to = '';
    if (msgs.isNotEmpty) {
      final m = msgs.first as Map;
      amount = nanoToTon(m['amount']);
      to = (m['address'] ?? '').toString();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _done
                ? 'تراکنش ارسال شد ✓'
                : _failed
                    ? 'رد شد یا خطا رخ داد'
                    : widget.title,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: _done
                  ? const Color(AppColors.green)
                  : _failed
                      ? const Color(AppColors.red)
                      : const Color(AppColors.text),
            ),
          ),
          const Divider(height: 20),
          if (!_done && !_failed) ...[
            InfoRow(label: 'مبلغ', value: '${fmtTon(amount)} TON'),
            if (to.isNotEmpty) InfoRow(label: 'به', value: to, copyable: true),
            const SizedBox(height: 12),
            YellowButton(
              label: _sending ? 'در انتظار کیف پول…' : 'ارسال به کیف پول',
              busy: _sending,
              onTap: _send,
            ),
          ] else
            Center(
              child: Icon(
                _done ? Icons.check_circle_rounded : Icons.error_rounded,
                color: _done ? const Color(AppColors.green) : const Color(AppColors.red),
                size: 50,
              ),
            ),
        ],
      ),
    );
  }
}

class _Action {
  final IconData icon;
  final String label;
  final String id;
  const _Action(this.icon, this.label, this.id);
}
