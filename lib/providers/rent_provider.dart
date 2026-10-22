import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/gift_item.dart';
import '../models/models.dart';
import 'core_providers.dart';
import '../services/api_client.dart';

/// مرتب‌سازی فید اجاره — همان گزینه‌های مارکت‌اپ
enum RentSort {
  recentlyTouch('recently_touch'),
  pricePerDayAsc('price_per_day'),
  minPrice('min_price'),
  durationAsc('duration_asc'),
  durationDesc('duration_desc'),
  itemNumAsc('item_num_asc'),
  itemNumDesc('item_num_desc');

  final String api;
  const RentSort(this.api);
}

/// فیلترهای اجاره — مثل صفحه Rent مارکت‌اپ: کالکشن + مدل + بک‌گراند + سمبل
class RentFilter {
  final String? collectionAddress;
  final String? collectionName;
  final String? model;
  final String? backdrop;
  final String? symbol;

  const RentFilter({
    this.collectionAddress,
    this.collectionName,
    this.model,
    this.backdrop,
    this.symbol,
  });

  bool get isEmpty =>
      collectionAddress == null && model == null && backdrop == null && symbol == null;

  int get count =>
      (collectionAddress != null ? 1 : 0) +
      (model != null ? 1 : 0) +
      (backdrop != null ? 1 : 0) +
      (symbol != null ? 1 : 0);

  RentFilter copyWith({String? collectionAddress, String? collectionName, String? model, String? backdrop, String? symbol, bool clearCollection = false, bool clearModel = false, bool clearBackdrop = false, bool clearSymbol = false}) =>
      RentFilter(
        collectionAddress: clearCollection ? null : (collectionAddress ?? this.collectionAddress),
        collectionName: clearCollection ? null : (collectionName ?? this.collectionName),
        model: clearModel ? null : (model ?? this.model),
        backdrop: clearBackdrop ? null : (backdrop ?? this.backdrop),
        symbol: clearSymbol ? null : (symbol ?? this.symbol),
      );
}

class RentState {
  final List<GiftItem> items;
  final String? cursor;
  final bool loading;
  final bool loadingMore;
  final bool exhausted; // همه صفحات خوانده شد
  final String? error;
  final RentSort sort;
  final RentFilter filter;
  final bool grid; // شبکه‌ای یا لیستی
  final int targetCount; // حداقل آیتمی که در بار اول می‌خواهیم

  const RentState({
    this.items = const [],
    this.cursor,
    this.loading = false,
    this.loadingMore = false,
    this.exhausted = false,
    this.error,
    this.sort = RentSort.recentlyTouch,
    this.filter = const RentFilter(),
    this.grid = true,
    this.targetCount = 300,
  });

  RentState copyWith({
    List<GiftItem>? items,
    String? cursor,
    bool clearCursor = false,
    bool? loading,
    bool? loadingMore,
    bool? exhausted,
    String? error,
    bool clearError = false,
    RentSort? sort,
    RentFilter? filter,
    bool? grid,
    int? targetCount,
  }) =>
      RentState(
        items: items ?? this.items,
        cursor: clearCursor ? null : (cursor ?? this.cursor),
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        exhausted: exhausted ?? this.exhausted,
        error: clearError ? null : (error ?? this.error),
        sort: sort ?? this.sort,
        filter: filter ?? this.filter,
        grid: grid ?? this.grid,
        targetCount: targetCount ?? this.targetCount,
      );
}

class RentNotifier extends StateNotifier<RentState> {
  final Ref ref;
  RentNotifier(this.ref) : super(const RentState());

  /// بار اول — چند صفحه پشت‌سرهم خوانده می‌شود تا فید واقعاً کامل باشد
  /// (رفع مشکل «فقط چند گیفت در بخش اجاره هست»)
  Future<void> refresh() async {
    state = state.copyWith(
      loading: true,
      clearError: true,
      items: const [],
      clearCursor: true,
      exhausted: false,
    );
    try {
      var merged = <GiftItem>[];
      String? cursor;
      for (var page = 0; page < 8; page++) {
        final r = await _fetch(cursor: page == 0 ? null : cursor);
        final items = _parse(r);
        final c = _cursor(r);
        merged = [...merged, ...items];
        cursor = c;
        state = state.copyWith(
          items: merged,
          cursor: (c != null && c.isNotEmpty) ? c : null,
        );
        if (c == null || c.isEmpty || items.isEmpty || merged.length >= state.targetCount) break;
      }
      state = state.copyWith(
        loading: false,
        exhausted: cursor == null || cursor.isEmpty,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.detail, clearCursor: true);
    } catch (e) {
      state = state.copyWith(loading: false, error: '$e', clearCursor: true);
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || state.exhausted || state.cursor == null) return;
    state = state.copyWith(loadingMore: true);
    try {
      final r = await _fetch(cursor: state.cursor);
      final items = _parse(r);
      final c = _cursor(r);
      state = state.copyWith(
        items: [...state.items, ...items],
        cursor: (c != null && c.isNotEmpty) ? c : null,
        loadingMore: false,
        exhausted: c == null || c.isEmpty || items.isEmpty,
      );
    } catch (e) {
      state = state.copyWith(loadingMore: false, exhausted: true);
    }
  }

  Future<dynamic> _fetch({String? cursor}) {
    final api = ref.read(apiProvider);
    final f = state.filter;
    return api.rentGifts(
      limit: 200,
      cursor: cursor,
      collectionAddress: f.collectionAddress,
      model: f.model,
      backdrop: f.backdrop,
      symbol: f.symbol,
      sortBy: state.sort.api,
    );
  }

  List<GiftItem> _parse(dynamic r) {
    final raw = r is Map ? (r['items'] ?? r['data']?['items']) : r;
    return ((raw as List? ?? []))
        .map((e) => GiftItem.fromRent(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  String? _cursor(dynamic r) =>
      r is Map ? r['cursor']?.toString() : null;

  void setSort(RentSort s) {
    if (s == state.sort) return;
    state = state.copyWith(sort: s);
    refresh();
  }

  void setFilter(RentFilter f) {
    state = state.copyWith(filter: f);
    refresh();
  }

  void toggleView() {
    state = state.copyWith(grid: !state.grid);
  }
}

final rentProvider = StateNotifierProvider<RentNotifier, RentState>((ref) => RentNotifier(ref));

// ---------- اتریبیوت‌های یک کالکشن (برای فیلتر مدل/بک‌گراند/سمبل) ----------
final rentAttributesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, addr) async {
  final api = ref.watch(apiProvider);
  final r = await api.collectionsAttributes(addr);
  final list = r is Map ? (r['attributes'] ?? r['data']?['attributes'] ?? r['data']) : r;
  final out = <Map<String, dynamic>>[];
  for (final e in (list as List? ?? [])) {
    if (e is Map) out.add(Map<String, dynamic>.from(e));
  }
  return out;
});

// ---------- کالکشن‌ها ----------
final collectionsProvider = FutureProvider<List<CollectionModel>>((ref) async {
  final api = ref.watch(apiProvider);
  final r = await api.collectionsGifts();
  return ((r as List? ?? []))
      .map((e) => CollectionModel.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

// ---------- تاریخچه کف قیمت (داده واقعی تجمع‌شده روی بک‌اند) ----------
class FloorPoints {
  final List<double> values;
  final List<int> times;
  final int snapshotCount;
  const FloorPoints({this.values = const [], this.times = const [], this.snapshotCount = 0});

  bool get isEmpty => values.length < 2;
}

/// کلید: [addr, range] — range: 1d | 1w | 1m | 3m | 6m | 1y
final floorHistoryFamily =
    FutureProvider.autoDispose.family<FloorPoints, List<String>>((ref, key) async {
  final addr = key[0];
  final range = key[1];
  final r = await ref.watch(apiProvider).floorHistory(addr, range: range) as Map<String, dynamic>;
  final pts = (r['points'] as List? ?? []);
  final values = <double>[];
  final times = <int>[];
  for (final p in pts) {
    if (p is Map) {
      values.add((p['v'] as num?)?.toDouble() ?? 0);
      times.add((p['t'] as num?)?.toInt() ?? 0);
    }
  }
  return FloorPoints(
    values: values,
    times: times,
    snapshotCount: (r['snapshot_count'] as num?)?.toInt() ?? 0,
  );
});
