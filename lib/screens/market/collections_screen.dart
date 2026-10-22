import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/strings.dart';
import '../../core/formatters.dart';
import '../../providers/rent_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/sparkline.dart';

/// کالکشن‌ها — فقط کف قیمت با چارت خطی لمس‌پذیر و فیلتر بازه زمانی
/// (بدون آمار مالکان/تعداد ساخت/حجم معاملات — طبق درخواست)
class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  String _range = '1m'; // 1d | 1w | 1m | 3m | 6m | 1y
  String? _expanded; // آدرس کالکشن باز شده برای چارت بزرگ

  static const _ranges = [
    ('1d', 'range1D'),
    ('1w', 'range1W'),
    ('1m', 'range1M'),
    ('3m', 'range3M'),
    ('6m', 'range6M'),
    ('1y', 'range1Y'),
  ];

  String _rangeLabel(S s, String key) =>
      key == 'range1D' ? s.range1D : key == 'range1W' ? s.range1W : key == 'range1M' ? s.range1M : key == 'range3M' ? s.range3M : key == 'range6M' ? s.range6M : s.range1Y;

  @override
  Widget build(BuildContext context) {
    final cols = ref.watch(collectionsProvider);
    final s = ref.watch(settingsProvider).s;

    return Scaffold(
      appBar: AppBar(title: Text(s.collections)),
      body: cols.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(AppColors.yellow))),
        error: (e, _) => ErrorPanel(
          message: e.toString().replaceAll('ApiException: ', ''),
          onRetry: () => ref.invalidate(collectionsProvider),
        ),
        data: (list) {
          final items = list;
          if (items.isEmpty) return EmptyPanel(title: s.empty, icon: Icons.collections_rounded);

          // کف صعودی/نزولی برای انتخاب سریع
          final sorted = [...items]..sort((a, b) => a.floorTon.compareTo(b.floorTon));

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
            itemCount: sorted.length,
            itemBuilder: (_, i) {
              final m = sorted[i];
              final isOpen = _expanded == m.address;
              final cover = 'https://nft.fragment.com/gift/${m.name.replaceAll(' ', '').toLowerCase()}.webp';
              return _CollectionCard(
                name: m.name,
                address: m.address,
                floorTon: m.floorTon,
                rentFloorTon: m.rentFloorTon,
                cover: cover,
                range: _range,
                expanded: isOpen,
                onToggle: () => setState(() => _expanded = isOpen ? null : m.address),
                rangeLabel: _rangeLabel(s, _ranges.firstWhere((r) => r.$1 == _range).$2),
                onRange: (r) => setState(() => _range = r),
                s: s,
              );
            },
          );
        },
      ),
    );
  }
}

class _CollectionCard extends ConsumerWidget {
  final String name;
  final String address;
  final double floorTon;
  final double rentFloorTon;
  final String cover;
  final String range;
  final bool expanded;
  final VoidCallback onToggle;
  final String rangeLabel;
  final ValueChanged<String> onRange;
  final S s;

  const _CollectionCard({
    required this.name,
    required this.address,
    required this.floorTon,
    required this.rentFloorTon,
    required this.cover,
    required this.range,
    required this.expanded,
    required this.onToggle,
    required this.rangeLabel,
    required this.onRange,
    required this.s,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hist = ref.watch(floorHistoryFamily([address, range]));
    final pts = hist.asData?.value ?? const FloorPoints();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(AppColors.card),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: expanded ? const Color(AppColors.yellow).withOpacity(0.45) : const Color(AppColors.stroke),
        ),
      ),
      child: Column(
        children: [
          // سربرگ کارت — لمس برای باز/بسته کردن چارت
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.network(
                      cover,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 46,
                        height: 46,
                        color: const Color(AppColors.surface),
                        child: const Icon(Icons.card_giftcard_rounded, size: 22, color: Color(AppColors.textDim)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13.5, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.diamond_outlined, size: 12, color: Color(AppColors.yellow)),
                            const SizedBox(width: 3),
                            Text(
                              '${fmtTon(floorTon)} TON',
                              style: const TextStyle(
                                  fontFamily: 'Vazirmatn', fontSize: 12, fontWeight: FontWeight.w800, color: Color(AppColors.yellow)),
                            ),
                            if (rentFloorTon > 0) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.timelapse_rounded, size: 11, color: const Color(AppColors.blue).withOpacity(0.9)),
                              const SizedBox(width: 2),
                              Text(
                                '${fmtTon(rentFloorTon)}${s.perDay}',
                                style: TextStyle(
                                    fontFamily: 'Vazirmatn', fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(AppColors.blue).withOpacity(0.9)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // اسپارک‌لاین کوچک همیشه دیده می‌شود
                  SizedBox(
                    width: 74,
                    height: 34,
                    child: hist.when(
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                      data: (p) => Sparkline(values: p.values, timesMs: p.times, height: 34, interactive: false),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(AppColors.textDim)),
                  ),
                ],
              ),
            ),
          ),
          // چارت بزرگ با فیلتر بازه زمانی
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.hideFirst,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(11, 0, 11, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // فیلتر بازه: ۱ روز تا ۱ سال (چپ به راست)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _rangesForChips()
                          .map((r) => Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: _rangeChip(r.$1, _chipLabel(r.$2)),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // چارت خط شکسته لمس‌پذیر
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    decoration: BoxDecoration(
                      color: const Color(AppColors.surface),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(AppColors.stroke)),
                    ),
                    child: hist.when(
                      loading: () => SizedBox(
                        height: 130,
                        child: Center(
                          child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: const Color(AppColors.yellow).withOpacity(0.7)),
                          ),
                        ),
                      ),
                      error: (_, __) => SizedBox(
                        height: 110,
                        child: Center(child: Text(s.noFloorData, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, color: Color(AppColors.textDim)))),
                      ),
                      data: (p) => p.isEmpty
                          ? SizedBox(
                              height: 110,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: Text(
                                    '${s.noFloorData}\n${s.collectingData}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10.5, color: Color(AppColors.textDim), height: 1.8),
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(s.floorChart,
                                        style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, fontWeight: FontWeight.w700, color: Color(AppColors.textDim))),
                                    const Spacer(),
                                    Text(rangeLabel,
                                        style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10.5, color: Color(AppColors.textDim))),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Sparkline(values: p.values, timesMs: p.times, height: 150, interactive: true),
                                const SizedBox(height: 2),
                                Text(
                                  s.touchChartHint,
                                  style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 9.5, color: Color(AppColors.textDim)),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _chipLabel(String key) => key == 'range1D'
      ? s.range1D
      : key == 'range1W'
          ? s.range1W
          : key == 'range1M'
              ? s.range1M
              : key == 'range3M'
                  ? s.range3M
                  : key == 'range6M'
                      ? s.range6M
                      : s.range1Y;

  List<(String, String)> _rangesForChips() => const [
        ('1d', 'range1D'),
        ('1w', 'range1W'),
        ('1m', 'range1M'),
        ('3m', 'range3M'),
        ('6m', 'range6M'),
        ('1y', 'range1Y'),
      ];

  Widget _rangeChip(String value, String label) {
    final active = value == range;
    return GestureDetector(
      onTap: () => onRange(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(AppColors.yellow) : const Color(AppColors.surface),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: active ? const Color(AppColors.yellow) : const Color(AppColors.stroke)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? const Color(0xFF111111) : const Color(AppColors.textDim),
          ),
        ),
      ),
    );
  }
}
