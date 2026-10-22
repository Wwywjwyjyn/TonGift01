import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/gift_item.dart';
import '../models/models.dart';
import 'core_providers.dart';
import 'wallet_provider.dart';
import '../services/api_client.dart';

class InventoryState {
  final bool loading;
  final List<GiftItem> items;
  final String? error;
  final bool busy; // هنگام انجام تراکنش
  final String? info; // پیام وضعیت (مثل نیاز به پلن)

  const InventoryState({
    this.loading = false,
    this.items = const [],
    this.error,
    this.busy = false,
    this.info,
  });

  InventoryState copyWith({
    bool? loading,
    List<GiftItem>? items,
    String? error,
    bool clearError = false,
    bool? busy,
    String? info,
    bool clearInfo = false,
  }) =>
      InventoryState(
        loading: loading ?? this.loading,
        items: items ?? this.items,
        error: clearError ? null : (error ?? this.error),
        busy: busy ?? this.busy,
        info: clearInfo ? null : (info ?? this.info),
      );
}

class InventoryNotifier extends StateNotifier<InventoryState> {
  final Ref ref;
  InventoryNotifier(this.ref) : super(const InventoryState());

  String? get _addr => ref.read(walletProvider).address;

  Future<void> refresh() async {
    final addr = _addr;
    if (addr == null || addr.isEmpty) {
      state = state.copyWith(items: const [], clearError: true);
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final api = ref.read(apiProvider);
      final r = await api.nftsOwner(addr);
      final items = ((r is Map ? r['items'] : r) as List? ?? [])
          .map((e) => GiftItem.fromOwnerNft(e as Map<String, dynamic>))
          .toList();
      final fallback = r is Map && r['fallback'] == 'tonapi';
      state = state.copyWith(
        items: items,
        info: fallback ? 'قیمت/وضعیت فروش از TON API' : null,
      );
    } on ApiException catch (e) {
      state = state.copyWith(error: e.detail);
    } catch (e) {
      state = state.copyWith(error: '$e');
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  GiftItem? findMine(String name, int? number) {
    for (final g in state.items) {
      if (number != null && g.number == number && g.name.toLowerCase() == name.toLowerCase()) {
        return g;
      }
    }
    return null;
  }

  // ---------- فروش ----------
  /// برمی‌گرداند: تراکنش برای امضا (یا خطا)
  Future<Map<String, dynamic>> sell(GiftItem g, double priceTon,
      {String currency = 'TON'}) async {
    final addr = _addr;
    if (addr == null) throw ApiException(0, 'اول کیف پول را وصل کن');
    state = state.copyWith(busy: true, clearError: true);
    try {
      final api = ref.read(apiProvider);
      final priceNanos = (priceTon * 1e9).round().toString();
      final r = await api.nftSale(addr, [
        {'nft_address': g.address, 'price': priceNanos, 'currency': currency},
      ]);
      return _txOf(r);
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<Map<String, dynamic>> changePrice(GiftItem g, double priceTon,
      {String currency = 'TON'}) async {
    final addr = _addr;
    if (addr == null) throw ApiException(0, 'اول کیف پول را وصل کن');
    state = state.copyWith(busy: true, clearError: true);
    try {
      final api = ref.read(apiProvider);
      final priceNanos = (priceTon * 1e9).round().toString();
      final r = await api.nftChangePrice(addr, [
        {'nft_address': g.address, 'price': priceNanos, 'currency': currency},
      ]);
      return _txOf(r);
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<Map<String, dynamic>> cancelSale(GiftItem g) async {
    final addr = _addr;
    if (addr == null) throw ApiException(0, 'اول کیف پول را وصل کن');
    state = state.copyWith(busy: true, clearError: true);
    try {
      final api = ref.read(apiProvider);
      final r = await api.nftCancelSale(addr, [g.address]);
      return _txOf(r);
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Map<String, dynamic> _txOf(dynamic r) {
    if (r is Map && r['transaction'] is Map) {
      return (r['transaction'] as Map).cast<String, dynamic>();
    }
    throw ApiException(0, 'تراکنشی از سرور برنگشت');
  }
}

final inventoryProvider =
    StateNotifierProvider<InventoryNotifier, InventoryState>((ref) => InventoryNotifier(ref));

// ---------- سفارش‌ها ----------
class OrdersNotifier extends StateNotifier<List<OrderRecord>> {
  final Ref ref;
  OrdersNotifier(this.ref) : super(const []);

  Future<void> refresh() async {
    state = await ref.read(ordersServiceProvider).list();
  }

  Future<void> add(OrderRecord rec) async {
    await ref.read(ordersServiceProvider).add(rec);
    await refresh();
  }

  Future<void> updateStatus(String id, OrderStatus st) async {
    await ref.read(ordersServiceProvider).updateStatus(id, st);
    await refresh();
  }
}

final ordersProvider =
    StateNotifierProvider<OrdersNotifier, List<OrderRecord>>((ref) => OrdersNotifier(ref));
