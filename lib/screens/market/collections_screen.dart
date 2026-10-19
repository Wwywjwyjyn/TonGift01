import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../providers/market_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';

/// لیست کالکشن‌های گیفت با آمار واقعی (کف قیمت، حجم، مالکان)
class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          if (items.isEmpty) return const EmptyPanel(title: 'کالکشنی یافت نشد');
          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final m = items[i];
              return Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(AppColors.card),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(AppColors.stroke)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            m.name,
                            style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 14.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const Icon(Icons.diamond_outlined, size: 15, color: Color(AppColors.yellow)),
                        const SizedBox(width: 4),
                        Text(
                          '${fmtTon(m.floorTon)} TON',
                          style: const TextStyle(
                              fontFamily: 'Vazirmatn', fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(AppColors.yellow)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'کف قیمت: ${fmtTon(m.floorTon)} • ${m.items} عدد • ${m.owners} مالک • ${m.onSaleAll} در فروش • حجم ۷روز: ${fmtCompact(m.volume7dTon)} TON',
                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: Color(AppColors.textDim), height: 1.9),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
