import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/gift_item.dart';
import '../models/models.dart';
import 'core_providers.dart';

enum MarketTab { all, ton, stars }

class MarketState {
  final MarketTab tab;
  final String search;
  final List<GiftItem> items;
  final String? cursor;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final bool paidRequired;
  final bool rentFallback;

  const MarketState({
    this.tab = MarketTab.ton,
    this.search = '',
    this.items = const [],
    this.cursor,
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.paidRequired = false,
    this.rentFallback = false,
  });

  List<GiftItem> get filtered {
    Iterable<GiftItem> it = items;
    if (tab == MarketTab.ton) {
      it = it.where((g) => g.currency.toUpperCase() != 'STARS');
    } else if (tab == MarketTab.stars) {
      it = it.where((g) => g.currency.toUpperCase() == 'STARS');
    }
    final q = search.trim().toLowerCase();
    if (q.isNotEmpty) {
      it = it.where((g) =>
          g.displayName.toLowerCase().contains(q) ||
          (g.model ?? '').toLowerCase().contains(q) ||
          (g.backdrop ?? '').toLowerCase().contains(q) ||
          (g.symbol ?? '').toLowerCase().contains(q));
    }
    return it.toList();
  }

  MarketState copyWith({
    MarketTab? tab,
    String? search,
    List<GiftItem>? items,
    String? cursor,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    bool? paidRequired,
    bool? rentFallback,
  }) =>
      MarketState(
        tab: tab ?? this.tab,
        search: search ?? this.search,
        items: items ?? this.items,
        cursor: cursor ?? this.cursor,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: clearError ? null : (error ?? this.error),
        paidRequired: paidRequired ?? this.paidRequired,
        rentFallback: rentFallback ?? this.rentFallback,
      );
}

class MarketNotifier extends StateNotifier<MarketState> {
  final Ref ref;
  MarketNotifier(this.ref) : super(const MarketState());

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true, items: const [], cursor: null);
    await _loadMore(initial: true);
    state = state.copyWith(loading: false);
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || state.cursor == null) return;
    state = state.copyWith(loadingMore: true);
    await _loadMore(initial: false);
    state = state.copyWith(loadingMore: false);
  }

  Future<void> _loadMore({required bool initial}) async {
    final api = ref.read(apiProvider);
    try {
      // ۱) تلاش برای فید واقعی فروش (TON/استارز)
      try {
        final r = await api.giftsOnsale(limit: 50, cursor: state.cursor);
        final items = ((r is Map ? r['items'] : r) as List? ?? [])
            .map((e) => GiftItem.fromOnsale(e as Map<String, dynamic>))
            .toList();
        final cursor = r is Map ? r['cursor']?.toString() : null;
        final merged = initial ? items : [...state.items, ...items];
        state = state.copyWith(
          items: merged,
          cursor: (cursor != null && cursor.isNotEmpty) ? cursor : null,
          paidRequired: false,
          rentFallback: false,
        );
        return;
      } on ApiException catch (e) {
        if (!e.isPaidRequired) rethrow;
        // ۲) نیاز به پلن — فید واقعی اجاره (رایگان و زنده)
      }
      final rr = await api.rentGifts(limit: 50, cursor: initial ? null : state.cursor);
      final rentItems = ((rr is Map ? rr['items'] : rr) as List? ?? [])
          .map((e) => GiftItem.fromRent(e as Map<String, dynamic>))
          .toList();
      final rc = rr is Map ? rr['cursor']?.toString() : null;
      final merged = initial ? rentItems : [...state.items, ...rentItems];
      state = state.copyWith(
        items: merged,
        cursor: (rc != null && rc.isNotEmpty) ? rc : null,
        paidRequired: true,
        rentFallback: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(error: e.detail, cursor: null);
    } catch (e) {
      state = state.copyWith(error: '$e', cursor: null);
    }
  }

  void setTab(MarketTab t) {
    state = state.copyWith(tab: t);
  }

  void setSearch(String q) {
    state = state.copyWith(search: q);
  }
}

final marketProvider =
    StateNotifierProvider<MarketNotifier, MarketState>((ref) => MarketNotifier(ref));

// ---------- کالکشن‌ها ----------
final collectionsProvider = FutureProvider<List<CollectionModel>>((ref) async {
  final api = ref.watch(apiProvider);
  final r = await api.collectionsGifts();
  return ((r as List? ?? []))
      .map((e) => CollectionModel.fromJson(e as Map<String, dynamic>))
      .toList();
});
