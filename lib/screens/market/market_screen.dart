import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../models/gift_item.dart';
import '../../providers/market_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/gift_card.dart';
import '../../widgets/common.dart';
import 'gift_detail_screen.dart';
import 'collections_screen.dart';

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) {
        ref.read(marketProvider.notifier).loadMore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(marketProvider);
    final s = ref.watch(settingsProvider).s;

    return RefreshIndicator(
      color: const Color(AppColors.yellow),
      backgroundColor: const Color(AppColors.card),
      onRefresh: () => ref.read(marketProvider.notifier).refresh(),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // جستجو
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => ref.read(marketProvider.notifier).setSearch(v),
                decoration: InputDecoration(
                  hintText: s.searchHint,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(AppColors.textDim)),
                  isDense: true,
                ),
              ),
            ),
          ),
          // تب‌ها
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
              child: Row(
                children: [
                  _tab(s.tonTab, MarketTab.ton, Icons.diamond_outlined),
                  const SizedBox(width: 8),
                  _tab(s.starsTab, MarketTab.stars, Icons.star_rounded),
                  const SizedBox(width: 8),
                  _tab(s.all, MarketTab.all, Icons.apps_rounded),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CollectionsScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(AppColors.card),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(AppColors.stroke)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.grid_view_rounded, size: 14, color: Color(AppColors.yellow)),
                          const SizedBox(width: 5),
                          Text(s.collections,
                              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // هشدار پلن (فقط وقتی فید فروش در دسترس نبود)
          if (st.paidRequired)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(AppColors.yellow).withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(AppColors.yellow).withOpacity(0.3)),
                  ),
                  child: Text(
                    s.paidPlanNeeded,
                    style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, height: 1.9, color: Color(AppColors.yellow)),
                  ),
                ),
              ),
            ),
          // خطا
          if (st.error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorPanel(message: st.error!, onRetry: () => ref.read(marketProvider.notifier).refresh()),
            )
          // لودینگ اولیه
          else if (st.loading)
            const SliverPadding(
              padding: EdgeInsets.all(14),
              sliver: SliverToBoxAdapter(child: LoadingGrid()),
            )
          // خالی
          else if (st.filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyPanel(
                title: s.empty,
                subtitle: s.pullRefresh,
                icon: Icons.storefront_rounded,
              ),
            )
          // گرید گیفت‌ها
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final GiftItem g = st.filtered[i];
                    return GiftCard(
                      item: g,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => GiftDetailScreen(item: g)),
                      ),
                    );
                  },
                  childCount: st.filtered.length,
                ),
              ),
            ),
            if (st.loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(AppColors.yellow))),
                ),
              ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
        ],
      ),
    );
  }

  Widget _tab(String label, MarketTab t, IconData icon) {
    final st = ref.watch(marketProvider);
    final active = st.tab == t;
    return GestureDetector(
      onTap: () => ref.read(marketProvider.notifier).setTab(t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(AppColors.yellow) : const Color(AppColors.card),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: active ? const Color(AppColors.yellow) : const Color(AppColors.stroke),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? const Color(0xFF111111) : const Color(AppColors.textDim)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? const Color(0xFF111111) : const Color(AppColors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
