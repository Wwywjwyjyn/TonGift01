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
import '../rent/rent_screen.dart';
import '../tg/tg_market_view.dart';
import '../../core/strings.dart';

/// بازار — بخش خرید و فروش با مارکت رسمی تلگرام (استارز) + فید NFT تون
class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  bool _tgMode = true; // پیش‌فرض: مارکت رسمی تلگرام

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) {
        ref.read(marketProvider.notifier).loadMore();
      }
    });
  }

  int _columns(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1000) return 5;
    if (w >= 720) return 4;
    if (w >= 500) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).s;
    final st = ref.watch(marketProvider);

    // مارکت رسمی تلگرام — کاتالوگ و دست‌دوم با استارز
    if (_tgMode) {
      return Column(
        children: [
          _sourceSwitch(s),
          const Expanded(child: TgMarketView()),
        ],
      );
    }

    return Column(
      children: [
        _sourceSwitch(s),
        Expanded(
          child: RefreshIndicator(
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
          // تب‌ها + ورودی اجاره/کالکشن‌ها
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _tab(s.all, MarketTab.all, Icons.apps_rounded),
                          const SizedBox(width: 7),
                          _tab(s.tonTab, MarketTab.ton, Icons.diamond_outlined),
                          const SizedBox(width: 7),
                          _tab(s.starsTab, MarketTab.stars, Icons.star_rounded),
                        ],
                      ),
                    ),
                  ),
                  _entryButton(
                    icon: Icons.timelapse_rounded,
                    label: s.rent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RentScreen())),
                  ),
                  const SizedBox(width: 6),
                  _entryButton(
                    icon: Icons.grid_view_rounded,
                    label: s.collections,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CollectionsScreen())),
                  ),
                ],
              ),
            ),
          ),
          // هشدار پلن (فقط وقتی فید فروش در دسترس نبود — فید اجاره جایگزین می‌شود)
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
            SliverPadding(
              padding: const EdgeInsets.all(14),
              sliver: SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (context, box) => LoadingGrid(columns: _columns(context)),
                ),
              ),
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
          // گرید ریسپانسیو گیفت‌ها
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _columns(context),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.76,
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
        ),
        ),
      ],
    );
  }

  /// سوییچ منبع: گیفت تلگرام (استارز) | NFT تون
  Widget _sourceSwitch(S s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tgMode = true),
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _tgMode ? const Color(AppColors.yellow) : const Color(AppColors.card),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _tgMode ? const Color(AppColors.yellow) : const Color(AppColors.stroke)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.telegram_rounded, size: 15, color: _tgMode ? const Color(0xFF111111) : const Color(AppColors.textDim)),
                    const SizedBox(width: 6),
                    Text(
                      s.tgSource,
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _tgMode ? const Color(0xFF111111) : const Color(AppColors.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tgMode = false),
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !_tgMode ? const Color(AppColors.yellow) : const Color(AppColors.card),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: !_tgMode ? const Color(AppColors.yellow) : const Color(AppColors.stroke)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.diamond_outlined, size: 15, color: !_tgMode ? const Color(0xFF111111) : const Color(AppColors.textDim)),
                    const SizedBox(width: 6),
                    Text(
                      s.tonSource,
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: !_tgMode ? const Color(0xFF111111) : const Color(AppColors.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(AppColors.yellow) : const Color(AppColors.card),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? const Color(AppColors.yellow) : const Color(AppColors.stroke),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: active ? const Color(0xFF111111) : const Color(AppColors.textDim)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: active ? const Color(0xFF111111) : const Color(AppColors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(AppColors.card),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(AppColors.stroke)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: const Color(AppColors.yellow)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
