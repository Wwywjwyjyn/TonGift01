import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../providers/core_providers.dart';
import '../../providers/tg_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/tg_card.dart';
import 'resale_screen.dart';

/// نمای مارکت رسمی تلگرام — کاتالوگ کامل گیفت‌های استارزی
class TgMarketView extends ConsumerStatefulWidget {
  const TgMarketView({super.key});

  @override
  ConsumerState<TgMarketView> createState() => _TgMarketViewState();
}

class _TgMarketViewState extends ConsumerState<TgMarketView> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  String _search = '';
  int _lastFloorsAt = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadFloors);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    final sess = ref.read(tgSessionProvider);
    if (!sess.connected) {
      await ref.read(tgSessionProvider.notifier).check();
    }
    if (!mounted) return;
    if (ref.read(tgSessionProvider).connected) {
      ref.read(tgCatalogProvider.notifier).refresh();
    }
  }

  void _maybeLoadFloors() {
    if (_scroll.position.extentAfter > 900) return;
    _loadFloorsForVisible();
  }

  Future<void> _loadFloorsForVisible() async {
    final cat = ref.read(tgCatalogProvider);
    if (!ref.read(tgSessionProvider).connected) return;
    if (cat.items.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFloorsAt < 2500) return;
    _lastFloorsAt = now;
    final q = _search.trim().toLowerCase();
    final visible = q.isEmpty ? cat.items : cat.filtered(q);
    final ids = visible.map((g) => g.id).take(24).toList();
    if (ids.isNotEmpty) ref.read(tgCatalogProvider.notifier).loadFloors(ids);
  }

  int get _columns {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1000) return 5;
    if (w >= 720) return 4;
    if (w >= 500) return 3;
    return 2;
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).s;
    final sess = ref.watch(tgSessionProvider);
    final cat = ref.watch(tgCatalogProvider);
    final items = cat.filtered(_search);

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
        await ref.read(tgCatalogProvider.notifier).refresh();
        await ref.read(tgSessionProvider.notifier).refreshStars();
      },
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // جستجو + موجودی
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) {
                        setState(() => _search = v);
                        _loadFloorsForVisible();
                      },
                      decoration: InputDecoration(
                        hintText: '${s.searchHint}  ·  ${s.tgMarket}',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(AppColors.textDim)),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // چیپ موجودی استارز
                  GestureDetector(
                    onTap: () => ref.read(tgSessionProvider.notifier).refreshStars(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(AppColors.yellow).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(AppColors.yellow).withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: Color(AppColors.yellow)),
                          const SizedBox(width: 4),
                          Text(
                            sess.stars == null ? '…' : fmtStarsShort(sess.stars!),
                            style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(AppColors.yellow)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // خطا
          if (cat.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                child: GestureDetector(
                  onTap: () => ref.read(tgCatalogProvider.notifier).refresh(),
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(AppColors.red).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(AppColors.red).withOpacity(0.3)),
                    ),
                    child: Text(
                      cat.floodAfter != null ? s.tgFloodWait(cat.floodAfter!) : cat.error!,
                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, color: Color(AppColors.red), height: 1.7),
                    ),
                  ),
                ),
              ),
            )
          else if (cat.loading && cat.items.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(14),
              sliver: SliverToBoxAdapter(child: LoadingGrid(columns: _columns, count: _columns * 2)),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.78,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final g = items[i];
                    final f = cat.floors[g.id];
                    return TgTypeCard(
                      gift: g,
                      floorMin: f?.min,
                      floorCount: f?.count,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ResaleScreen(gift: g)),
                        );
                        // بعد از برگشت — کف‌ها و موجودی تازه شود
                        ref.read(tgSessionProvider.notifier).refreshStars();
                        _lastFloorsAt = 0;
                        _loadFloorsForVisible();
                      },
                    );
                  },
                  childCount: items.length,
                ),
              ),
            ),
            if (cat.loading && cat.items.isNotEmpty)
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
    );
  }
}

String fmtStarsShort(int v) {
  if (v >= 1000000) return '${(v / 1e6).toStringAsFixed(1)}M';
  if (v >= 10000) return '${(v / 1e3).toStringAsFixed(1)}K';
  return '$v';
}
