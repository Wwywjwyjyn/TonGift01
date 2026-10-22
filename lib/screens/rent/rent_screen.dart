import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/strings.dart';
import '../../core/formatters.dart';
import '../../models/gift_item.dart';
import '../../providers/rent_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/gift_card.dart';
import '../market/gift_detail_screen.dart';

/// بخش اجاره — فید کامل با صفحه‌بندی چندمرحله‌ای + فیلترهای مارکت‌اپ
/// (کالکشن، مدل، بک‌گراند، سمبل + مرتب‌سازی + شبکه/لیست)
class RentScreen extends ConsumerStatefulWidget {
  const RentScreen({super.key});

  @override
  ConsumerState<RentScreen> createState() => _RentScreenState();
}

class _RentScreenState extends ConsumerState<RentScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(rentProvider).items.isEmpty) ref.read(rentProvider.notifier).refresh();
    });
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 500) ref.read(rentProvider.notifier).loadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(rentProvider);
    final s = ref.watch(settingsProvider).s;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.rentTitle),
        actions: [
          IconButton(
            onPressed: () => ref.read(rentProvider.notifier).toggleView(),
            icon: Icon(st.grid ? Icons.view_list_rounded : Icons.grid_view_rounded, size: 20),
          ),
          Stack(
            children: [
              IconButton(
                onPressed: () => _openFilters(),
                icon: const Icon(Icons.tune_rounded, size: 21),
              ),
              if (st.filter.count > 0)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    width: 15,
                    height: 15,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Color(AppColors.yellow), shape: BoxShape.circle),
                    child: Text('${st.filter.count}',
                        style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF111111))),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // مرتب‌سازی — گزینه‌های واقعی API اجاره مارکت‌اپ
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              children: [
                _sortChip(s.sortRecentlyTouch, RentSort.recentlyTouch, st, ''),
                _sortChip(s.sortPriceLow, RentSort.pricePerDayAsc, st, '↑'),
                _sortChip(s.sortPriceHigh, RentSort.minPrice, st, '↓'),
                _sortChip(s.sortDuration, RentSort.durationAsc, st, '↑'),
                _sortChip(s.sortDuration, RentSort.durationDesc, st, '↓'),
                _sortChip(s.sortItemNum, RentSort.itemNumAsc, st, '↑'),
                _sortChip(s.sortItemNum, RentSort.itemNumDesc, st, '↓'),
              ],
            ),
          ),
          if (st.filter.count > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 13, color: Color(AppColors.yellow)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      [
                        if (st.filter.collectionName != null) st.filter.collectionName!,
                        if (st.filter.model != null) '${s.model}: ${st.filter.model}',
                        if (st.filter.backdrop != null) '${s.backdrop}: ${st.filter.backdrop}',
                        if (st.filter.symbol != null) '${s.symbol}: ${st.filter.symbol}',
                      ].join('  •  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: Color(AppColors.textDim)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ref.read(rentProvider.notifier).setFilter(const RentFilter()),
                    child: Text(s.reset,
                        style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, fontWeight: FontWeight.w700, color: Color(AppColors.yellow))),
                  ),
                ],
              ),
            ),
          Expanded(
            child: st.error != null
                ? ErrorPanel(message: st.error!, onRetry: () => ref.read(rentProvider.notifier).refresh())
                : st.loading
                    ? const LoadingGrid()
                    : st.items.isEmpty
                        ? EmptyPanel(title: s.empty, subtitle: s.pullRefresh, icon: Icons.timelapse_rounded)
                        : RefreshIndicator(
                            color: const Color(AppColors.yellow),
                            backgroundColor: const Color(AppColors.card),
                            onRefresh: () => ref.read(rentProvider.notifier).refresh(),
                            child: st.grid ? _grid(st) : _list(st, s),
                          ),
          ),
          if (st.loadingMore)
            const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(AppColors.yellow)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${st.items.length} ${s.giftsLoaded}',
              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10.5, color: Color(AppColors.textDim)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(RentState st) {
    return GridView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _columns(context),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.76,
      ),
      itemCount: st.items.length,
      itemBuilder: (_, i) {
        final g = st.items[i];
        return GiftCard(
          item: g,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GiftDetailScreen(item: g))),
        );
      },
    );
  }

  Widget _list(RentState st, S s) {
    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      itemCount: st.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final g = st.items[i];
        return _RentRow(
          item: g,
          s: s,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GiftDetailScreen(item: g))),
        );
      },
    );
  }

  int _columns(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 900) return 5;
    if (w >= 650) return 4;
    if (w >= 480) return 3;
    return 2;
  }

  Widget _sortChip(String label, RentSort value, RentState st, String arrow) {
    final active = st.sort == value;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: () => ref.read(rentProvider.notifier).setSort(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? const Color(AppColors.yellow) : const Color(AppColors.card),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: active ? const Color(AppColors.yellow) : const Color(AppColors.stroke)),
          ),
          child: Center(
            child: Text(
              '$label $arrow'.trim(),
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? const Color(0xFF111111) : const Color(AppColors.text),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- شیت فیلتر (مثل صفحه Rent مارکت‌اپ) ----------
  void _openFilters() {
    final st = ref.read(rentProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RentFilterSheet(initial: st.filter, s: ref.read(settingsProvider).s),
    );
  }
}

// ---------- ردیف لیستی اجاره ----------
class _RentRow extends StatelessWidget {
  final GiftItem item;
  final S s;
  final VoidCallback onTap;
  const _RentRow({required this.item, required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: const Color(AppColors.card),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(AppColors.stroke)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: GiftImage(item: item, width: 56, height: 56),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.slug,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, color: Color(AppColors.textDim)),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (item.model != null) MiniTag(text: item.model!),
                      if (item.backdrop != null) MiniTag(text: item.backdrop!),
                      if (item.symbol != null) MiniTag(text: item.symbol!),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.diamond_outlined, size: 12, color: Color(AppColors.yellow)),
                    const SizedBox(width: 3),
                    Text(
                      '${fmtTon(item.pricePerDayTon)}${s.perDay}',
                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(AppColors.yellow)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'RENT',
                  style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Color(AppColors.blue)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- شیت فیلتر ----------
class _RentFilterSheet extends ConsumerStatefulWidget {
  final RentFilter initial;
  final S s;
  const _RentFilterSheet({required this.initial, required this.s});

  @override
  ConsumerState<_RentFilterSheet> createState() => _RentFilterSheetState();
}

class _RentFilterSheetState extends ConsumerState<_RentFilterSheet> {
  late RentFilter _f;
  String? _attrsCollection;

  @override
  void initState() {
    super.initState();
    _f = widget.initial;
    _attrsCollection = _f.collectionAddress;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final cols = ref.watch(collectionsProvider);
    final attrs = _attrsCollection == null
        ? const AsyncValue<List<Map<String, dynamic>>>.data([])
        : ref.watch(rentAttributesProvider(_attrsCollection!));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.94,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(AppColors.surface),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            // دستگیره + عنوان
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(s.filters, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 16, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() => _f = const RentFilter());
                      _attrsCollection = null;
                    },
                    child: Text(s.reset, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, color: Color(AppColors.yellow))),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                children: [
                  // کالکشن‌ها (با کف اجاره واقعی هر کدام)
                  _sectionTitle(s.collections),
                  cols.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(14),
                      child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(AppColors.yellow)))),
                    ),
                    error: (e, _) => Text('$e', style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: Color(AppColors.red))),
                    data: (list) {
                      final sorted = [...list]..sort((a, b) => a.rentFloorTon.compareTo(b.rentFloorTon));
                      return Column(
                        children: sorted.map((m) {
                          final active = _f.collectionAddress == m.address;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _f = active
                                    ? _f.copyWith(clearCollection: true, clearModel: true, clearBackdrop: true, clearSymbol: true)
                                    : _f.copyWith(collectionAddress: m.address, collectionName: m.name, clearModel: true, clearBackdrop: true, clearSymbol: true);
                                _attrsCollection = active ? null : m.address;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    active ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                    size: 19,
                                    color: active ? const Color(AppColors.yellow) : const Color(AppColors.textDim),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.w600)),
                                  ),
                                  Text(
                                    m.rentFloorTon > 0 ? '${fmtTon(m.rentFloorTon)}${s.perDay}' : '—',
                                    style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, fontWeight: FontWeight.w700, color: const Color(AppColors.blue).withOpacity(0.9)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  // اتریبیوت‌ها — فقط بعد از انتخاب کالکشن (مثل مارکت‌اپ)
                  if (_attrsCollection != null) ...[
                    _sectionTitle('${s.model} / ${s.backdrop} / ${s.symbol}'),
                    attrs.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(14),
                        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(AppColors.yellow)))),
                      ),
                      error: (e, _) => Text('$e', style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: Color(AppColors.red))),
                      data: (list) {
                        // هر اتریبیوت: trait_type + values
                        final byType = <String, List<String>>{};
                        for (final a in list) {
                          final t = (a['trait_type'] ?? a['type'] ?? '').toString().toLowerCase();
                          final v = (a['value'] ?? '').toString();
                          if (t.isEmpty || v.isEmpty) continue;
                          byType.putIfAbsent(t, () => []).add(v);
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: byType.entries.map((e) {
                            final type = e.key;
                            final label = type == 'model' ? s.model : type == 'backdrop' ? s.backdrop : type == 'symbol' ? s.symbol : type;
                            final selected = type == 'model'
                                ? _f.model
                                : type == 'backdrop'
                                    ? _f.backdrop
                                    : type == 'symbol'
                                        ? _f.symbol
                                        : null;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(label, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, fontWeight: FontWeight.w700, color: Color(AppColors.textDim))),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: e.value
                                        .where((v) => v.isNotEmpty)
                                        .take(60)
                                        .map((v) => GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  if (type == 'model') {
                                                    _f = _f.model == v ? _f.copyWith(clearModel: true) : _f.copyWith(model: v);
                                                  } else if (type == 'backdrop') {
                                                    _f = _f.backdrop == v ? _f.copyWith(clearBackdrop: true) : _f.copyWith(backdrop: v);
                                                  } else if (type == 'symbol') {
                                                    _f = _f.symbol == v ? _f.copyWith(clearSymbol: true) : _f.copyWith(symbol: v);
                                                  }
                                                });
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: selected == v ? const Color(AppColors.yellow) : const Color(AppColors.card),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: selected == v ? const Color(AppColors.yellow) : const Color(AppColors.stroke)),
                                                ),
                                                child: Text(
                                                  v,
                                                  style: TextStyle(
                                                    fontFamily: 'Vazirmatn',
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: selected == v ? const Color(0xFF111111) : const Color(AppColors.text),
                                                  ),
                                                ),
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        s.fa ? 'برای فیلتر مدل/بک‌گراند/سمبل اول یک کالکشن انتخاب کن' : 'Pick a collection first to filter by model / backdrop / symbol',
                        style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: Color(AppColors.textDim), height: 1.8),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            // اعمال
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + MediaQuery.of(context).padding.bottom * 0.4),
              child: Row(
                children: [
                  Expanded(
                    child: GhostButton(label: s.cancel, onTap: () => Navigator.pop(context)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: YellowButton(
                      label: '${s.apply} (${_f.count})',
                      onTap: () {
                        ref.read(rentProvider.notifier).setFilter(_f);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.w800)),
      );
}
