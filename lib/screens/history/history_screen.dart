import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/strings.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../providers/core_providers.dart';
import '../../providers/inventory_provider.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';

/// تاریخچه — خریدها/فروش‌ها/اجاره‌ها/استارز/پریمیوم
/// منابع واقعی: رکوردهای محلی تراکنش‌ها + تاریخچه اجاره از API مارکت‌اپ
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

enum _HistFilter { all, gifts, stars, premium, rents }

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _HistFilter _f = _HistFilter.all;
  List<dynamic> _rentHistory = [];
  bool _rentLoading = false;
  String? _rentError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ordersProvider.notifier).refresh();
      _loadRentHistory();
    });
  }

  Future<void> _loadRentHistory() async {
    setState(() {
      _rentLoading = true;
      _rentError = null;
    });
    try {
      final r = await ref.read(apiProvider).rentHistory(category: 'gifts', limit: 30);
      final list = r is Map ? (r['items'] ?? r['data']?['items'] ?? r['history']) : r;
      setState(() => _rentHistory = (list as List? ?? []).toList());
    } on ApiException catch (e) {
      // بدون اجاره/بدون دسترسی — خطا مهم نیست، فقط خالی نشان داده می‌شود
      setState(() => _rentError = e.isPaidRequired ? null : e.detail);
    } catch (_) {
      setState(() => _rentError = null);
    } finally {
      if (mounted) setState(() => _rentLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).s;
    final orders = ref.watch(ordersProvider);

    // ترکیب و فیلتر
    final filteredOrders = orders.where((o) {
      switch (_f) {
        case _HistFilter.all:
          return true;
        case _HistFilter.gifts:
          return o.type == OrderType.gift;
        case _HistFilter.stars:
          return o.type == OrderType.stars;
        case _HistFilter.premium:
          return o.type == OrderType.premium;
        case _HistFilter.rents:
          return false;
      }
    }).toList();

    final showRents = _f == _HistFilter.all || _f == _HistFilter.rents;
    final isEmpty = filteredOrders.isEmpty && (!showRents || (_rentHistory.isEmpty && !_rentLoading));

    return Scaffold(
      appBar: AppBar(
        title: Text(s.historyTitle),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(ordersProvider.notifier).refresh();
              _loadRentHistory();
            },
            icon: const Icon(Icons.refresh_rounded, size: 21),
          ),
        ],
      ),
      body: Column(
        children: [
          // فیلترها
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              children: [
                _chip(s.filterAll, _HistFilter.all),
                _chip(s.filterGifts, _HistFilter.gifts),
                _chip(s.filterStars, _HistFilter.stars),
                _chip(s.filterPremium, _HistFilter.premium),
                _chip(s.filterRents, _HistFilter.rents),
              ],
            ),
          ),
          Expanded(
            child: isEmpty
                ? EmptyPanel(
                    title: s.historyEmpty,
                    subtitle: s.historyEmptyDesc,
                    icon: Icons.history_rounded,
                  )
                : RefreshIndicator(
                    color: const Color(AppColors.yellow),
                    backgroundColor: const Color(AppColors.card),
                    onRefresh: () async {
                      ref.read(ordersProvider.notifier).refresh();
                      await _loadRentHistory();
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                      itemCount: filteredOrders.length +
                          (showRents ? _rentHistory.length + (_rentLoading ? 1 : 0) : 0),
                      itemBuilder: (_, i) {
                        if (i < filteredOrders.length) {
                          return _OrderRow(rec: filteredOrders[i], s: s);
                        }
                        final ri = i - filteredOrders.length;
                        if (_rentLoading && ri == 0) {
                          return const Padding(
                            padding: EdgeInsets.all(14),
                            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(AppColors.yellow)))),
                          );
                        }
                        final idx = _rentLoading ? ri - 1 : ri;
                        if (idx < 0 || idx >= _rentHistory.length) return const SizedBox();
                        final e = _rentHistory[idx];
                        if (e is Map) return _RentHistoryRow(raw: Map<String, dynamic>.from(e), s: s);
                        return const SizedBox();
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, _HistFilter f) {
    final active = _f == f;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: () => setState(() => _f = f),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? const Color(AppColors.yellow) : const Color(AppColors.card),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: active ? const Color(AppColors.yellow) : const Color(AppColors.stroke)),
          ),
          child: Center(
            child: Text(
              label,
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
}

// ---------- ردیف سفارش محلی ----------
class _OrderRow extends StatelessWidget {
  final OrderRecord rec;
  final S s;
  const _OrderRow({required this.rec, required this.s});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (rec.type) {
      OrderType.stars => (Icons.star_rounded, const Color(AppColors.yellow)),
      OrderType.premium => (Icons.workspace_premium_rounded, const Color(AppColors.blue)),
      OrderType.gift => (Icons.card_giftcard_rounded, const Color(AppColors.green)),
    };
    final (statusLabel, statusColor) = switch (rec.status) {
      OrderStatus.created => (s.created, const Color(AppColors.textDim)),
      OrderStatus.sentToWallet => (s.sent, const Color(AppColors.yellow)),
      OrderStatus.confirmed => (s.confirmed, const Color(AppColors.green)),
      OrderStatus.failed => (s.failed, const Color(AppColors.red)),
    };
    final d = DateTime.fromMillisecondsSinceEpoch(rec.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(AppColors.card),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(AppColors.stroke)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}'
                  '  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, color: Color(AppColors.textDim)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (rec.amountTon != null)
                Text(
                  '${fmtTon(rec.amountTon)} TON',
                  style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(AppColors.yellow)),
                ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 9.5, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------- ردیف تاریخچه اجاره (API واقعی مارکت‌اپ) ----------
class _RentHistoryRow extends StatelessWidget {
  final Map<String, dynamic> raw;
  final S s;
  const _RentHistoryRow({required this.raw, required this.s});

  @override
  Widget build(BuildContext context) {
    final nft = (raw['nft_name'] ?? raw['name'] ?? '').toString();
    final renter = (raw['renter'] ?? raw['renter_address'] ?? raw['owner'] ?? '').toString();
    final pricePerDay = double.tryParse((raw['price_per_day'] ?? '0').toString()) ?? 0;
    final ts = int.tryParse('${raw['rented_at'] ?? raw['created_at'] ?? raw['ts'] ?? 0}') ?? 0;
    final status = (raw['status'] ?? '').toString();

    final d = ts > 0 ? DateTime.fromMillisecondsSinceEpoch(ts * (ts < 100000000000 ? 1000 : 1)) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(AppColors.card),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(AppColors.stroke)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(AppColors.blue).withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.timelapse_rounded, size: 19, color: Color(AppColors.blue)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nft.isEmpty ? s.rentHistory : nft,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (renter.isNotEmpty) '${s.rentedBy}: ${shortAddr(renter)}',
                    if (d != null) '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
                    if (status.isNotEmpty) status,
                  ].join('  •  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, color: Color(AppColors.textDim)),
                ),
              ],
            ),
          ),
          if (pricePerDay > 0)
            Text(
              '${fmtTon(pricePerDay / 1e9)}${s.perDay}',
              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(AppColors.yellow)),
            ),
        ],
      ),
    );
  }
}
