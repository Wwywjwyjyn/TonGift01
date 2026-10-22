import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../models/gift_item.dart';
import '../../providers/core_providers.dart';
import '../../providers/tg_provider.dart';
import '../../services/tg_api.dart';
import '../../widgets/common.dart';
import '../../widgets/tg_card.dart';
import '../market/gift_detail_screen.dart';

/// صفحه یک نوع گیفت از مارکت رسمی تلگرام:
/// ۱) خرید جدید (هدیه به خودت یا یوزرنیم)  ۲) بازار دست‌دوم دیگران (خرید با استارز)
class ResaleScreen extends ConsumerStatefulWidget {
  final TgGiftType gift;
  const ResaleScreen({super.key, required this.gift});

  @override
  ConsumerState<ResaleScreen> createState() => _ResaleScreenState();
}

class _ResaleScreenState extends ConsumerState<ResaleScreen> {
  String _sort = 'price';
  List<TgGift> _items = [];
  int _count = 0;
  String? _next;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int? _flood;
  final _scroll = ScrollController();

  TgGiftType get _g => ref.read(tgCatalogProvider).items.firstWhere(
        (x) => x.id == widget.gift.id,
        orElse: () => widget.gift,
      );

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _loadMore();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _flood = null;
      _items = [];
      _next = null;
      _count = 0;
    });
    try {
      final r = await ref.read(tgApiProvider).listings(widget.gift.id, sort: _sort, limit: 24) as Map<String, dynamic>;
      final items = ((r['items'] ?? []) as List)
          .map((e) => TgGift.fromListing(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = items;
        _count = int.tryParse('${r['count'] ?? 0}') ?? 0;
        _next = (r['next_offset'] ?? '').toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (e is TgApiException) {
          _error = e.detail;
          _flood = e.retryAfter;
        } else {
          _error = '$e';
        }
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _next == null || _next!.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final r = await ref.read(tgApiProvider).listings(widget.gift.id, sort: _sort, offset: _next!, limit: 24) as Map<String, dynamic>;
      final items = ((r['items'] ?? []) as List)
          .map((e) => TgGift.fromListing(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...items];
        _next = (r['next_offset'] ?? '').toString();
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  int get _columns {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1000) return 5;
    if (w >= 720) return 4;
    if (w >= 500) return 3;
    return 2;
  }

  // ---------- خرید ----------
  Future<void> _buyNew() async {
    final s = ref.read(settingsProvider).s;
    final g = _g;
    final ctrl = TextEditingController();
    final msgCtrl = TextEditingController();
    bool forMe = true;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${s.tgBuyNew} — ${g.displayTitle}',
                  style: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w800, fontSize: 14.5)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.star_rounded, size: 16, color: const Color(AppColors.yellow)),
                  const SizedBox(width: 5),
                  Text('${fmtStars(g.stars)} ${s.stars}',
                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.w800, color: Color(AppColors.yellow))),
                  const Spacer(),
                  if (g.upgradeStars != null && g.upgradeStars! > 0)
                    Text('+ ${fmtStars(g.upgradeStars!)} ${s.stars} ↑',
                        style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: Color(AppColors.textDim))),
                ],
              ),
              const SizedBox(height: 14),
              Text(s.tgRecipient, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setSt(() => forMe = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: forMe ? const Color(AppColors.yellow) : const Color(AppColors.card),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: forMe ? const Color(AppColors.yellow) : const Color(AppColors.stroke)),
                        ),
                        child: Text(s.tgRecipientMe,
                            style: TextStyle(
                                fontFamily: 'Vazirmatn', fontSize: 12.5, fontWeight: FontWeight.w700,
                                color: forMe ? const Color(0xFF111111) : const Color(AppColors.text))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setSt(() => forMe = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: !forMe ? const Color(AppColors.yellow) : const Color(AppColors.card),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: !forMe ? const Color(AppColors.yellow) : const Color(AppColors.stroke)),
                        ),
                        child: Text(s.tgRecipientOther,
                            style: TextStyle(
                                fontFamily: 'Vazirmatn', fontSize: 12.5, fontWeight: FontWeight.w700,
                                color: !forMe ? const Color(0xFF111111) : const Color(AppColors.text))),
                      ),
                    ),
                  ),
                ],
              ),
              if (!forMe) ...[
                const SizedBox(height: 10),
                TextField(controller: ctrl, decoration: const InputDecoration(hintText: '@username')),
              ],
              const SizedBox(height: 10),
              TextField(controller: msgCtrl, maxLength: 120, decoration: InputDecoration(hintText: '${s.tgMessage} (${s.optionalField})')),
              const SizedBox(height: 14),
              YellowButton(
                label: '${s.tgBuyNew} · ${fmtStars(g.stars)} ★',
                onTap: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;

    setState(() { _busy0 = true; });
    try {
      await ref.read(tgApiProvider).buyNew(
            g.id,
            toUsername: forMe ? null : ctrl.text.trim(),
            message: msgCtrl.text.trim(),
          );
      if (!mounted) return;
      ref.read(tgSessionProvider.notifier).refreshStars();
      toast(context, s.tgBuyNewDone);
      setState(() { _busy0 = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _busy0 = false; });
      if (e is TgApiException) {
        toast(context, e.retryAfter != null ? s.tgFloodWait(e.retryAfter!) : e.detail, error: true);
      } else {
        toast(context, '$e', error: true);
      }
    }
  }

  bool _busy0 = false;

  Future<void> _buyListing(TgGift l) async {
    final s = ref.read(settingsProvider).s;
    final sess = ref.read(tgSessionProvider);
    final price = l.listPrice ?? 0;
    final stars = sess.stars;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.tgBuyConfirmTitle, style: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 12),
            Row(
              children: [
                TgStickerImage(slug: l.slug, docId: l.modelDocId, size: 54),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.displayName, style: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700, fontSize: 13.5)),
                      if (l.model.isNotEmpty)
                        Text(l.model, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: Color(AppColors.textDim))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _priceRow(s.tgYourBalance, stars == null ? '—' : '${fmtStars(stars)} ★', stars != null && stars < price),
            _priceRow(s.price, '${fmtStars(price)} ★'),
            _priceRow(s.tgAfterBuy, stars == null ? '—' : '${fmtStars(stars - price)} ★', stars != null && stars < price),
            if (stars != null && stars < price) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(AppColors.red).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(AppColors.red).withOpacity(0.3)),
                ),
                child: Text(s.tgInsufficient,
                    style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: Color(AppColors.red), height: 1.7)),
              ),
            ],
            const SizedBox(height: 14),
            YellowButton(label: '${s.tgBuy} · ${fmtStars(price)} ★', onTap: () => Navigator.pop(ctx, true)),
            const SizedBox(height: 8),
            GhostButton(label: s.cancel, onTap: () => Navigator.pop(ctx, false)),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await ref.read(tgApiProvider).buy(l.slug);
      if (!mounted) return;
      ref.read(tgSessionProvider.notifier).refreshStars();
      ref.read(tgCatalogProvider.notifier).refresh();
      toast(context, s.tgBought);
      _reload();
    } catch (e) {
      if (!mounted) return;
      if (e is TgApiException) {
        toast(context, e.retryAfter != null ? s.tgFloodWait(e.retryAfter!) : e.detail, error: true);
      } else {
        toast(context, '$e', error: true);
      }
    }
  }

  Widget _priceRow(String label, String value, [bool warn = false]) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(AppColors.card),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(AppColors.stroke)),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: Color(AppColors.textDim))),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontFamily: 'Vazirmatn', fontSize: 12.5, fontWeight: FontWeight.w800,
                  color: warn ? const Color(AppColors.red) : const Color(AppColors.text))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).s;
    final g = ref.watch(tgCatalogProvider.select((c) {
          try {
            return c.items.firstWhere((x) => x.id == widget.gift.id);
          } catch (_) {
            return widget.gift;
          }
        }));

    return Scaffold(
      appBar: AppBar(
        title: Text(g.displayTitle),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded, size: 21),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(AppColors.yellow),
        backgroundColor: const Color(AppColors.card),
        onRefresh: _reload,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // هدر گیفت
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(AppColors.card),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(AppColors.stroke)),
                  ),
                  child: Row(
                    children: [
                      TgStickerImage(docId: g.stickerDocId, size: 88),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g.displayTitle,
                                style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 16, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Icon(Icons.star_rounded, size: 15, color: const Color(AppColors.yellow)),
                                const SizedBox(width: 4),
                                Text('${fmtStars(g.stars)} ${s.stars}',
                                    style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.w800, color: Color(AppColors.yellow))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (g.availabilityResale != null && g.availabilityResale! > 0)
                                  MiniTag(text: s.tgListingsCount(g.availabilityResale!), color: const Color(AppColors.green)),
                                if (g.limited && g.availabilityTotal != null)
                                  MiniTag(text: '${fmtCompact(g.availabilityRemains ?? 0)} / ${fmtCompact(g.availabilityTotal!)}', color: const Color(AppColors.blue)),
                                if (g.soldOut) MiniTag(text: s.tgSoldOutBadge, color: const Color(AppColors.red)),
                                if (g.auction) MiniTag(text: s.tgAuctionBadge, color: const Color(AppColors.red)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // دکمه خرید جدید
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: YellowButton(
                  label: _busy0
                      ? s.loading
                      : '${s.tgBuyNew} · ${fmtStars(g.stars)} ★',
                  busy: _busy0,
                  onTap: g.soldOut || g.auction ? null : _buyNew,
                ),
              ),
            ),
            // عنوان دست‌دوم + مرتب‌سازی
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${s.tgResale} ($_count)',
                        style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                    _sortChip('price', s.sortPriceLow),
                    const SizedBox(width: 6),
                    _sortChip('num', s.sortItemNum),
                    const SizedBox(width: 6),
                    _sortChip('recent', s.sortRecentlyTouch),
                  ],
                ),
              ),
            ),
            if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorPanel(message: _flood != null ? s.tgFloodWait(_flood!) : _error!, onRetry: _reload),
              )
            else if (_loading)
              SliverPadding(
                padding: const EdgeInsets.all(14),
                sliver: SliverToBoxAdapter(
                  child: LoadingGrid(columns: _columns, count: _columns * 2),
                ),
              )
            else if (_items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyPanel(
                  title: s.tgResaleEmpty,
                  subtitle: s.tgBuyNewDesc,
                  icon: Icons.storefront_rounded,
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _columns,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => TgListingCard(
                      listing: _items[i],
                      onTap: () => _openListingDetail(_items[i]),
                      onBuy: () => _buyListing(_items[i]),
                    ),
                    childCount: _items.length,
                  ),
                ),
              ),
              if (_loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(AppColors.yellow))),
                  ),
                ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }

  void _openListingDetail(TgGift l) {
    // جزئیات کامل با صفحه موجود — با مدل یکتا
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GiftDetailScreen(
          item: tgGiftToItem(l),
        ),
      ),
    );
  }

  Widget _sortChip(String v, String label) {
    final active = _sort == v;
    return GestureDetector(
      onTap: () {
        if (_sort == v) return;
        setState(() => _sort = v);
        _reload();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(AppColors.yellow) : const Color(AppColors.card),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: active ? const Color(AppColors.yellow) : const Color(AppColors.stroke)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: active ? const Color(0xFF111111) : const Color(AppColors.textDim),
          ),
        ),
      ),
    );
  }
}
