import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../providers/core_providers.dart';
import '../../providers/tg_provider.dart';
import '../../services/tg_api.dart';
import '../../widgets/common.dart';
import '../../widgets/tg_card.dart';

/// انبار تلگرام — گیفت‌های واقعی اکانت + فروش‌گذاری/انتقال/آپگرید
class TgInventoryView extends ConsumerStatefulWidget {
  const TgInventoryView({super.key});

  @override
  ConsumerState<TgInventoryView> createState() => _TgInventoryViewState();
}

class _TgInventoryViewState extends ConsumerState<TgInventoryView> {
  int _columns() {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1000) return 5;
    if (w >= 720) return 4;
    if (w >= 500) return 3;
    return 2;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final sess = ref.read(tgSessionProvider);
    if (!sess.connected) await ref.read(tgSessionProvider.notifier).check();
    if (!mounted) return;
    if (ref.read(tgSessionProvider).connected) {
      ref.read(tgInventoryProvider.notifier).refresh();
    }
  }

  Future<void> _onGiftTap(TgGift g) async {
    final s = ref.read(settingsProvider).s;
    final inv = ref.read(tgInventoryProvider.notifier);

    final actions = <_Act>[
      if (g.isUnique && g.msgId != null && !g.listed)
        _Act(Icons.sell_rounded, g.listPrice != null ? s.tgSellTg : s.tgSellTg, 'list'),
      if (g.isUnique && g.msgId != null && g.listed) _Act(Icons.price_change_rounded, s.changePrice, 'list'),
      if (g.isUnique && g.msgId != null && g.listed) _Act(Icons.cancel_rounded, s.tgUnlistTg, 'unlist'),
      if (g.isUnique && g.msgId != null && g.canTransferOk) _Act(Icons.send_rounded, s.tgTransferTg, 'transfer'),
      if (!g.isUnique && g.canUpgrade && g.msgId != null) _Act(Icons.auto_awesome_rounded, s.tgUpgradeTg, 'upgrade'),
      if (g.slug.isNotEmpty) _Act(Icons.open_in_new_rounded, s.openInTelegram, 'tg'),
    ];

    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                TgStickerImage(slug: g.isUnique ? g.slug : null, docId: g.modelDocId.isNotEmpty ? g.modelDocId : null, size: 44),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.displayName, style: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w800, fontSize: 14.5)),
                      Text(
                        g.isUnique
                            ? '${g.model}${g.listed ? '  ·  ${s.tgListedBadge}: ${fmtStars(g.listPrice ?? 0)}★' : ''}'
                            : (g.fromName.isNotEmpty ? '${s.from} ${g.fromName}' : s.tgFromCatalog),
                        style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: Color(AppColors.textDim)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (actions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  g.isUnique ? s.tgCanResellSoon : s.tgBuyMinNote,
                  style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, color: Color(AppColors.textDim)),
                ),
              ),
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
      case 'list':
        _askPrice(g, isChange: g.listed);
        break;
      case 'unlist':
        _run(() => inv.unlist(g), s.tgUnlistedDone);
        break;
      case 'transfer':
        _askTransfer(g);
        break;
      case 'upgrade':
        _confirmUpgrade(g);
        break;
      case 'tg':
        launchUrl(Uri.parse(g.tgLink()), mode: LaunchMode.externalApplication);
        break;
    }
  }

  Future<void> _run(Future<bool> Function() f, String okMsg) async {
    final s = ref.read(settingsProvider).s;
    try {
      final ok = await f();
      if (!mounted) return;
      if (ok) toast(context, okMsg);
    } catch (e) {
      if (!mounted) return;
      if (e is TgApiException) {
        toast(context, e.retryAfter != null ? s.tgFloodWait(e.retryAfter!) : e.detail, error: true);
      } else {
        toast(context, '$e', error: true);
      }
    }
  }

  Future<void> _askPrice(TgGift g, {required bool isChange}) async {
    final s = ref.read(settingsProvider).s;
    final cat = ref.read(tgCatalogProvider);
    final ctrl = TextEditingController(text: g.listPrice != null ? '${g.listPrice}' : '');
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
              isChange ? s.changePrice : s.tgSellTg,
              style: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(g.displayName, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, color: Color(AppColors.textDim))),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: s.tgSetPriceTg),
            ),
            const SizedBox(height: 8),
            Text(
              '${s.tgPriceRange} ${fmtStars(cat.meta.minResale)} — ${fmtStars(cat.meta.maxResale)} ★'
              '${cat.meta.commissionPermille != null ? '  ·  ${s.tgCommissionNote((cat.meta.commissionPermille! / 10).toStringAsFixed(1))}' : ''}',
              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10.5, height: 1.8, color: Color(AppColors.textDim)),
            ),
            const SizedBox(height: 14),
            YellowButton(
              label: isChange ? s.changePrice : s.tgSellTg,
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final price = int.tryParse(ctrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (price <= 0) {
      toast(context, s.fa ? 'قیمت معتبر نیست' : 'Invalid price', error: true);
      return;
    }
    await _run(() => ref.read(tgInventoryProvider.notifier).listForSale(g, price),
        s.tgListedForSale(price));
  }

  Future<void> _askTransfer(TgGift g) async {
    final s = ref.read(settingsProvider).s;
    final ctrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.tgTransferTg, style: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 6),
            Text(g.displayName, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, color: Color(AppColors.textDim))),
            if (g.transferStars != null && g.transferStars! > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(AppColors.yellow).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(AppColors.yellow).withOpacity(0.3)),
                ),
                child: Text(
                  s.tgTransferFee(g.transferStars!),
                  style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, color: Color(AppColors.yellow)),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: '@username'),
            ),
            const SizedBox(height: 14),
            YellowButton(label: s.tgTransferTg, onTap: () => Navigator.pop(context, true)),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final uname = ctrl.text.trim().replaceFirst('@', '');
    if (uname.isEmpty) return;
    await _run(() => ref.read(tgInventoryProvider.notifier).transfer(g, uname), s.tgTransferDone);
  }

  Future<void> _confirmUpgrade(TgGift g) async {
    final s = ref.read(settingsProvider).s;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(AppColors.card),
        title: Text(s.tgUpgradeTg, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 15, fontWeight: FontWeight.w800)),
        content: Text(
          g.upgradeStars != null && g.upgradeStars! > 0
              ? '${s.tgUpgradeCost(g.upgradeStars!)}\n${g.displayName}'
              : g.displayName,
          style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, height: 1.8),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel, style: const TextStyle(fontFamily: 'Vazirmatn'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.confirm, style: const TextStyle(fontFamily: 'Vazirmatn', color: const Color(AppColors.yellow))),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    await _run(() => ref.read(tgInventoryProvider.notifier).upgrade(g), s.tgUpgradedDone);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).s;
    final sess = ref.watch(tgSessionProvider);
    final inv = ref.watch(tgInventoryProvider);

    if (sess.phase == TgPhase.unknown || (sess.checking && !sess.connected)) {
      return const Center(child: CircularProgressIndicator(color: Color(AppColors.yellow), strokeWidth: 2));
    }
    if (!sess.connected) {
      return RefreshIndicator(
        color: const Color(AppColors.yellow),
        backgroundColor: const Color(AppColors.card),
        onRefresh: () => ref.read(tgSessionProvider.notifier).check(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 60),
            TgConnectPrompt(),
            const SizedBox(height: 30),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(AppColors.yellow),
      backgroundColor: const Color(AppColors.card),
      onRefresh: () async {
        await ref.read(tgInventoryProvider.notifier).refresh();
        await ref.read(tgSessionProvider.notifier).refreshStars();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // هدر: اکانت + موجودی استارز
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(AppColors.card),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(AppColors.stroke)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.telegram_rounded, size: 18, color: Color(AppColors.yellow)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${sess.user?.name ?? s.tgAccount}${sess.user?.username.isNotEmpty == true ? '  ·  @${sess.user!.username}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.star_rounded, size: 15, color: Color(AppColors.yellow)),
                    const SizedBox(width: 4),
                    Text(
                      sess.stars == null ? '…' : fmtStars(sess.stars!),
                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.w800, color: Color(AppColors.yellow)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // خطا
          if (inv.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: GestureDetector(
                  onTap: () => ref.read(tgInventoryProvider.notifier).refresh(),
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(AppColors.red).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(AppColors.red).withOpacity(0.3)),
                    ),
                    child: Text(
                      inv.floodAfter != null ? s.tgFloodWait(inv.floodAfter!) : inv.error!,
                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, color: Color(AppColors.red), height: 1.7),
                    ),
                  ),
                ),
              ),
            ),
          if (inv.loading && inv.items.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.all(14),
              sliver: SliverToBoxAdapter(child: LoadingGrid(columns: 2)),
            )
          else if (inv.items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyPanel(
                icon: Icons.inventory_2_rounded,
                title: s.tgGiftsCount(0),
                subtitle: s.fa
                    ? 'گیفتی در اکانت تلگرامت نیست — از مارکت بخر یا از تلگرام هدیه بگیر'
                    : 'No gifts in your Telegram account yet — buy from the market or receive one as a gift',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _columns(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.74,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => TgMyGiftCard(
                    gift: inv.items[i],
                    onTap: () => _onGiftTap(inv.items[i]),
                  ),
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

class _Act {
  final IconData icon;
  final String label;
  final String id;
  const _Act(this.icon, this.label, this.id);
}
