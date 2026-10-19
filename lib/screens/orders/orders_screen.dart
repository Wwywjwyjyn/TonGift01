import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../providers/core_providers.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/common.dart';

/// سفارش‌های من — وضعیت واقعی هر تراکنش
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ordersProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).s;
    final orders = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.myOrders)),
      body: orders.isEmpty
          ? EmptyPanel(
              icon: Icons.receipt_long_rounded,
              title: s.empty,
              subtitle: 'هر خرید یا فروشی که انجام بدهی اینجا با وضعیت واقعی ثبت می‌شود',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final o = orders[i];
                return Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(AppColors.card),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(AppColors.stroke)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            o.type == OrderType.stars
                                ? Icons.star_rounded
                                : o.type == OrderType.premium
                                    ? Icons.workspace_premium_rounded
                                    : Icons.card_giftcard_rounded,
                            size: 19,
                            color: const Color(AppColors.yellow),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              o.title,
                              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13.5, fontWeight: FontWeight.w800),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _statusChip(o.status),
                        ],
                      ),
                      if (o.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          o.subtitle,
                          style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: Color(AppColors.textDim), height: 1.8),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (o.amountTon != null && o.amountTon! > 0) ...[
                            const Icon(Icons.diamond_outlined, size: 13, color: Color(AppColors.yellow)),
                            const SizedBox(width: 4),
                            Text(
                              '${fmtTon(o.amountTon)} TON',
                              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(AppColors.yellow)),
                            ),
                            const SizedBox(width: 10),
                          ],
                          const Spacer(),
                          Text(
                            timeAgoFa(DateTime.fromMillisecondsSinceEpoch(o.createdAt), true),
                            style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10.5, color: Color(AppColors.textDim)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _statusChip(OrderStatus st) {
    String label;
    Color c;
    switch (st) {
      case OrderStatus.created:
        label = 'ایجاد شد';
        c = const Color(AppColors.blue);
        break;
      case OrderStatus.sentToWallet:
        label = 'در کیف پول';
        c = const Color(AppColors.yellow);
        break;
      case OrderStatus.confirmed:
        label = 'تأیید شد';
        c = const Color(AppColors.green);
        break;
      case OrderStatus.failed:
        label = 'ناموفق';
        c = const Color(AppColors.red);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }
}
