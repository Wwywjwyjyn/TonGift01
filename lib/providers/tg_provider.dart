import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/strings.dart';
import '../core/formatters.dart';
import '../services/tg_api.dart';
import '../services/orders_service.dart';
import '../models/models.dart';
import 'core_providers.dart';
import 'inventory_provider.dart' show ordersProvider;

// ---------- کلاینت تلگرام ----------
final tgApiProvider = Provider<TgApi>((ref) {
  final url = ref.watch(settingsProvider).backendUrl ?? '';
  final st = ref.watch(settingsProvider);
  return TgApi(url, () => st.deviceToken);
});

// ---------- نشست تلگرام ----------
enum TgPhase { unknown, locked, needApi, disconnected, connected }

class TgUser {
  final int id;
  final String name;
  final String username;
  final String phone;
  const TgUser({required this.id, required this.name, this.username = '', this.phone = ''});

  factory TgUser.fromJson(Map<String, dynamic> j) => TgUser(
        id: int.tryParse('${j['id'] ?? 0}') ?? 0,
        name: (j['name'] ?? '').toString(),
        username: (j['username'] ?? '').toString(),
        phone: (j['phone'] ?? '').toString(),
      );
}

class TgSessionState {
  final TgPhase phase;
  final bool checking;
  final TgUser? user;
  final int? stars; // موجودی استارز — از سرور
  final String? error;
  final int? floodAfter; // ثانیه

  const TgSessionState({
    this.phase = TgPhase.unknown,
    this.checking = false,
    this.user,
    this.stars,
    this.error,
    this.floodAfter,
  });

  bool get connected => phase == TgPhase.connected;
  bool get usable => connected || phase == TgPhase.disconnected || phase == TgPhase.needApi || phase == TgPhase.locked;

  TgSessionState copyWith({
    TgPhase? phase,
    bool? checking,
    TgUser? user,
    int? stars,
    String? error,
    int? floodAfter,
    bool clearError = false,
    bool clearStars = true,
  }) =>
      TgSessionState(
        phase: phase ?? this.phase,
        checking: checking ?? this.checking,
        user: user ?? this.user,
        stars: clearStars ? (stars ?? this.stars) : null,
        error: clearError ? null : (error ?? this.error),
        floodAfter: floodAfter,
      );
}

class TgSessionNotifier extends StateNotifier<TgSessionState> {
  final Ref ref;
  TgSessionNotifier(this.ref) : super(const TgSessionState());

  Future<void> check() async {
    final st = ref.read(settingsProvider);
    if (st.backendUrl == null || st.backendUrl!.isEmpty) {
      state = state.copyWith(phase: TgPhase.disconnected, checking: false);
      return;
    }
    state = state.copyWith(checking: true, clearError: true);
    try {
      final r = await ref.read(tgApiProvider).status() as Map<String, dynamic>;
      if (r['locked'] == true) {
        state = state.copyWith(phase: TgPhase.locked, checking: false, user: null);
        return;
      }
      if (r['need_api'] == true || r['ready'] != true) {
        state = state.copyWith(phase: TgPhase.needApi, checking: false, user: null);
        return;
      }
      if (r['connected'] == true) {
        state = TgSessionState(
          phase: TgPhase.connected,
          checking: false,
          user: TgUser.fromJson((r['user'] ?? {}) as Map<String, dynamic>),
          stars: r['stars'] is int ? r['stars'] as int : (r['stars'] is num ? (r['stars'] as num).toInt() : null),
        );
      } else {
        state = state.copyWith(
          phase: TgPhase.disconnected,
          checking: false,
          user: null,
          error: (r['error'] ?? '').toString().isEmpty ? null : (r['error'] ?? '').toString(),
        );
      }
    } on TgApiException catch (e) {
      state = state.copyWith(checking: false, error: e.detail);
    } catch (_) {
      state = state.copyWith(checking: false);
    }
  }

  Future<void> refreshStars() async {
    if (!state.connected) return;
    try {
      final r = await ref.read(tgApiProvider).stars() as Map<String, dynamic>;
      if (mounted) state = state.copyWith(stars: int.tryParse('${r['stars'] ?? 0}'));
    } catch (_) {}
  }

  void setLocalStars(int v) {
    if (mounted) state = state.copyWith(stars: v);
  }

  Future<void> logout() async {
    try {
      await ref.read(tgApiProvider).logout();
    } catch (_) {}
    state = TgSessionState(phase: TgPhase.disconnected, checking: false);
  }
}

final tgSessionProvider =
    StateNotifierProvider<TgSessionNotifier, TgSessionState>((ref) => TgSessionNotifier(ref));

// ---------- کاتالوگ مارکت رسمی ----------
class TgGiftType {
  final int id;
  final String title;
  final int stars; // قیمت گیفت نو
  final String stickerDocId;
  final bool limited;
  final bool soldOut;
  final bool auction;
  final bool requirePremium;
  final int? availabilityRemains;
  final int? availabilityTotal;
  final int? availabilityResale; // چند تا در دست‌دوم هست
  final int? resellMinStars; // کف قیمت دست‌دوم (وقتی معلوم است)
  final int? upgradeStars;

  const TgGiftType({
    required this.id,
    required this.title,
    required this.stars,
    required this.stickerDocId,
    this.limited = false,
    this.soldOut = false,
    this.auction = false,
    this.requirePremium = false,
    this.availabilityRemains,
    this.availabilityTotal,
    this.availabilityResale,
    this.resellMinStars,
    this.upgradeStars,
  });

  factory TgGiftType.fromJson(Map<String, dynamic> j) => TgGiftType(
        id: int.tryParse('${j['id'] ?? 0}') ?? 0,
        title: (j['title'] ?? '').toString(),
        stars: int.tryParse('${j['stars'] ?? 0}') ?? 0,
        stickerDocId: (j['sticker_doc_id'] ?? '').toString(),
        limited: j['limited'] == true,
        soldOut: j['sold_out'] == true,
        auction: j['auction'] == true,
        requirePremium: j['require_premium'] == true,
        availabilityRemains: (j['availability_remains'] as num?)?.toInt(),
        availabilityTotal: (j['availability_total'] as num?)?.toInt(),
        availabilityResale: (j['availability_resale'] as num?)?.toInt(),
        resellMinStars: (j['resell_min_stars'] as num?)?.toInt(),
        upgradeStars: (j['upgrade_stars'] as num?)?.toInt(),
      );

  /// عنوان نمایشی: از رفرش کاتالوگ تلگرام «Fresh Socks» می‌آید؛ اگر خالی بود از آیدی
  String get displayTitle => title.isNotEmpty ? title : 'Gift #$id';
}

class TgCatalogMeta {
  final int minResale;
  final int maxResale;
  final int? commissionPermille;
  const TgCatalogMeta({this.minResale = 125, this.maxResale = 1000000, this.commissionPermille});

  factory TgCatalogMeta.fromJson(Map<String, dynamic> j) => TgCatalogMeta(
        minResale: int.tryParse('${j['min_resale'] ?? 125}') ?? 125,
        maxResale: int.tryParse('${j['max_resale'] ?? 1000000}') ?? 1000000,
        commissionPermille: (j['commission_permille'] as num?)?.toInt(),
      );
}

class TgCatalogState {
  final bool loading;
  final String? error;
  final int? floodAfter;
  final List<TgGiftType> items;
  final TgCatalogMeta meta;
  final Map<int, TgFloorInfo> floors;

  const TgCatalogState({
    this.loading = false,
    this.error,
    this.floodAfter,
    this.items = const [],
    this.meta = const TgCatalogMeta(),
    this.floors = const {},
  });

  List<TgGiftType> filtered(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return items;
    return items.where((g) => g.displayTitle.toLowerCase().contains(s)).toList();
  }

  TgCatalogState copyWith({
    bool? loading,
    String? error,
    int? floodAfter,
    List<TgGiftType>? items,
    TgCatalogMeta? meta,
    Map<int, TgFloorInfo>? floors,
    bool clearError = false,
  }) =>
      TgCatalogState(
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        floodAfter: floodAfter,
        items: items ?? this.items,
        meta: meta ?? this.meta,
        floors: floors ?? this.floors,
      );
}

class TgFloorInfo {
  final int count;
  final int? min;
  const TgFloorInfo({required this.count, this.min});
}

class TgCatalogNotifier extends StateNotifier<TgCatalogState> {
  final Ref ref;
  TgCatalogNotifier(this.ref) : super(const TgCatalogState());

  Future<void> refresh() async {
    final sess = ref.read(tgSessionProvider);
    if (!sess.connected) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final r = await ref.read(tgApiProvider).catalog() as Map<String, dynamic>;
      final items = ((r['gifts'] ?? []) as List)
          .map((e) => TgGiftType.fromJson(e as Map<String, dynamic>))
          .toList();
      // مرتب‌سازی: اول مخصوص تولد/فعال‌ها بعد بر اساس کف دست‌دوم، بعد قیمت نو
      items.sort((a, b) {
        final ar = a.resellMinStars ?? a.stars;
        final br = b.resellMinStars ?? b.stars;
        return ar.compareTo(br);
      });
      state = state.copyWith(
        loading: false,
        items: items,
        meta: r['meta'] is Map
            ? TgCatalogMeta.fromJson((r['meta'] ?? {}) as Map<String, dynamic>)
            : state.meta,
      );
    } on TgApiException catch (e) {
      state = state.copyWith(loading: false, error: e.detail, floodAfter: e.retryAfter);
    } catch (e) {
      state = state.copyWith(loading: false, error: '$e');
    }
  }

  /// کف قیمت‌ها به‌صورت تنبل برای بخشی از گرید
  Future<void> loadFloors(List<int> ids) async {
    final todo = ids.where((i) => i > 0 && !state.floors.containsKey(i)).toSet().toList();
    if (todo.isEmpty) return;
    try {
      final r = await ref.read(tgApiProvider).floors(todo.take(24).toList()) as Map<String, dynamic>;
      final floors = Map<int, TgFloorInfo>.from(state.floors);
      ((r['floors'] ?? {}) as Map).forEach((k, v) {
        final id = int.tryParse('$k');
        if (id != null && v is Map) {
          floors[id] = TgFloorInfo(
            count: int.tryParse('${v['count'] ?? 0}') ?? 0,
            min: (v['min'] as num?)?.toInt(),
          );
        }
      });
      state = state.copyWith(floors: floors);
    } catch (_) {}
  }

  void putFloor(int giftId, TgFloorInfo info) {
    final floors = Map<int, TgFloorInfo>.from(state.floors);
    floors[giftId] = info;
    state = state.copyWith(floors: floors);
  }
}

final tgCatalogProvider =
    StateNotifierProvider<TgCatalogNotifier, TgCatalogState>((ref) => TgCatalogNotifier(ref));

// ---------- انبار من (گیفت‌های تلگرام) ----------
class TgAttr {
  final String type; // model | symbol | backdrop
  final String name;
  final String? rarity;
  final List<String> colors;
  const TgAttr({required this.type, required this.name, this.rarity, this.colors = const []});

  factory TgAttr.fromJson(Map<String, dynamic> j) => TgAttr(
        type: (j['type'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        rarity: j['rarity']?.toString(),
        colors: ((j['colors'] ?? []) as List).map((e) => e.toString()).toList(),
      );
}

class TgGift {
  final int? msgId; // شناسه برای اکشن‌ها (فقط گیفت‌های خودم)
  final int uniqueId;
  final int giftTypeId; // برای عکس از کاتالوگ
  final String title;
  final String slug;
  final int num;
  final bool isUnique;
  final bool canUpgrade;
  final int? upgradeStars;
  final int? transferStars;
  final int? canTransferAt;
  final int? canResellAt;
  final int? convertStars;
  final int? date;
  final String fromName;
  final bool listed;
  final int? listPrice;
  final String model;
  final String backdrop;
  final String symbol;
  final String modelDocId;
  final String? rarity;
  final int issued;
  final int total;
  final bool resaleTonOnly;
  final String ownerAddress;

  const TgGift({
    this.msgId,
    required this.uniqueId,
    required this.giftTypeId,
    required this.title,
    required this.slug,
    required this.num,
    required this.isUnique,
    this.canUpgrade = false,
    this.upgradeStars,
    this.transferStars,
    this.canTransferAt,
    this.canResellAt,
    this.convertStars,
    this.date,
    this.fromName = '',
    this.listed = false,
    this.listPrice,
    this.model = '',
    this.backdrop = '',
    this.symbol = '',
    this.modelDocId = '',
    this.rarity,
    this.issued = 0,
    this.total = 0,
    this.resaleTonOnly = false,
    this.ownerAddress = '',
  });

  factory TgGift.fromSaved(Map<String, dynamic> j) {
    final g = (j['gift'] ?? {}) as Map<String, dynamic>;
    final isUnique = g['kind'] == 'unique';
    return TgGift(
      msgId: (j['msg_id'] as num?)?.toInt(),
      uniqueId: int.tryParse('${g['id'] ?? 0}') ?? 0,
      giftTypeId: int.tryParse('${isUnique ? g['gift_id'] : g['id'] ?? 0}') ?? 0,
      title: (g['title'] ?? '').toString(),
      slug: (g['slug'] ?? '').toString(),
      num: int.tryParse('${g['num'] ?? 0}') ?? 0,
      isUnique: isUnique,
      canUpgrade: j['can_upgrade'] == true,
      upgradeStars: (j['upgrade_stars'] as num?)?.toInt(),
      transferStars: (j['transfer_stars'] as num?)?.toInt(),
      canTransferAt: (j['can_transfer_at'] as num?)?.toInt(),
      canResellAt: (j['can_resell_at'] as num?)?.toInt(),
      convertStars: (j['convert_stars'] as num?)?.toInt(),
      date: (j['date'] as num?)?.toInt(),
      fromName: (j['from_name'] ?? '').toString(),
      listed: j['listed'] == true,
      listPrice: (j['list_price'] as num?)?.toInt(),
      model: (g['model'] ?? '').toString(),
      backdrop: (g['backdrop'] ?? '').toString(),
      symbol: (g['symbol'] ?? '').toString(),
      modelDocId: (g['model_doc_id'] ?? '').toString(),
      rarity: g['rarity']?.toString(),
      issued: int.tryParse('${g['issued'] ?? 0}') ?? 0,
      total: int.tryParse('${g['total'] ?? 0}') ?? 0,
      resaleTonOnly: g['resale_ton_only'] == true,
      ownerAddress: (g['owner_address'] ?? '').toString(),
    );
  }

  /// گیفت دست‌دوم دیگران (از فید resale)
  factory TgGift.fromListing(Map<String, dynamic> j) {
    final attrs = ((j['attributes'] ?? []) as List)
        .map((e) => TgAttr.fromJson(e as Map<String, dynamic>))
        .toList();
    String attr(String t) {
      final i = attrs.indexWhere((a) => a.type == t);
      return i >= 0 ? attrs[i].name : '';
    }

    return TgGift(
      uniqueId: int.tryParse('${j['id'] ?? 0}') ?? 0,
      giftTypeId: int.tryParse('${j['gift_id'] ?? 0}') ?? 0,
      title: (j['title'] ?? '').toString(),
      slug: (j['slug'] ?? '').toString(),
      num: int.tryParse('${j['num'] ?? 0}') ?? 0,
      isUnique: true,
      listed: j['resell_stars'] != null,
      listPrice: (j['resell_stars'] as num?)?.toInt(),
      model: attr('model'),
      backdrop: attr('backdrop'),
      symbol: attr('symbol'),
      modelDocId: (j['model_doc_id'] ?? '').toString(),
      rarity: j['rarity']?.toString(),
      issued: int.tryParse('${j['issued'] ?? 0}') ?? 0,
      total: int.tryParse('${j['total'] ?? 0}') ?? 0,
      resaleTonOnly: j['resale_ton_only'] == true,
      ownerAddress: (j['owner_address'] ?? '').toString(),
    );
  }

  String get displayName => num > 0 ? '$title #$num' : title;

  /// آیا الان می‌شود منتقل کرد؟
  bool get canTransferOk =>
      canTransferAt == null ||
      canTransferAt! <= 0 ||
      canTransferAt! <= DateTime.now().millisecondsSinceEpoch ~/ 1000;

  /// عکس: برای یکتاها رندر fragment بهترین است؛ برای نوعی‌ها استیکر سرور
  String? fragmentImage() =>
      slug.isNotEmpty ? 'https://nft.fragment.com/gift/${slug.toLowerCase()}.webp' : null;

  String tgLink() => slug.isNotEmpty ? 'https://t.me/nft/$slug' : '';
}

class TgInventoryState {
  final bool loading;
  final String? error;
  final int? floodAfter;
  final List<TgGift> items;
  final int count;

  const TgInventoryState({
    this.loading = false,
    this.error,
    this.floodAfter,
    this.items = const [],
    this.count = 0,
  });

  TgInventoryState copyWith({
    bool? loading,
    String? error,
    int? floodAfter,
    List<TgGift>? items,
    int? count,
    bool clearError = false,
  }) =>
      TgInventoryState(
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        floodAfter: floodAfter,
        items: items ?? this.items,
        count: count ?? this.count,
      );
}

class TgInventoryNotifier extends StateNotifier<TgInventoryState> {
  final Ref ref;
  TgInventoryNotifier(this.ref) : super(const TgInventoryState());

  Future<void> refresh() async {
    final sess = ref.read(tgSessionProvider);
    if (!sess.connected) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final r = await ref.read(tgApiProvider).myGifts() as Map<String, dynamic>;
      final items = ((r['items'] ?? []) as List)
          .map((e) => TgGift.fromSaved(e as Map<String, dynamic>))
          .toList();
      // یکتاها اول، بعد بر اساس تاریخ
      items.sort((a, b) {
        if (a.isUnique != b.isUnique) return a.isUnique ? -1 : 1;
        return (b.date ?? 0).compareTo(a.date ?? 0);
      });
      state = state.copyWith(
        loading: false,
        items: items,
        count: int.tryParse('${r['count'] ?? items.length}') ?? items.length,
      );
    } on TgApiException catch (e) {
      state = state.copyWith(loading: false, error: e.detail, floodAfter: e.retryAfter);
    } catch (e) {
      state = state.copyWith(loading: false, error: '$e');
    }
  }

  OrdersService get _orders => ref.read(ordersServiceProvider);
  S get _s => ref.read(settingsProvider).s;

  void _logOrder(String title, String subtitle, {bool ok = true}) {
    _orders.add(OrderRecord(
      id: 'tg${DateTime.now().millisecondsSinceEpoch}',
      type: OrderType.gift,
      title: title,
      subtitle: subtitle,
      status: ok ? OrderStatus.confirmed : OrderStatus.failed,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    ref.read(ordersProvider.notifier).refresh();
  }

  Future<bool> listForSale(TgGift g, int price) async {
    try {
      await ref.read(tgApiProvider).listForSale(g.msgId!, price);
      _logOrder(g.displayName, _s.tgListedForSale(price), ok: true);
      await refresh();
      return true;
    } on TgApiException catch (e) {
      _logOrder(g.displayName, e.detail, ok: false);
      rethrow;
    }
  }

  Future<bool> unlist(TgGift g) async {
    try {
      await ref.read(tgApiProvider).unlist(g.msgId!);
      _logOrder(g.displayName, _s.tgUnlistedDone, ok: true);
      await refresh();
      return true;
    } on TgApiException {
      rethrow;
    }
  }

  Future<bool> transfer(TgGift g, String username) async {
    try {
      await ref.read(tgApiProvider).transfer(g.msgId!, username);
      _logOrder(g.displayName, '${_s.tgTransferredTo} @$username', ok: true);
      await refresh();
      return true;
    } on TgApiException {
      rethrow;
    }
  }

  Future<bool> upgrade(TgGift g) async {
    try {
      await ref.read(tgApiProvider).upgrade(g.msgId!);
      _logOrder(g.displayName, _s.tgUpgradedDone, ok: true);
      await refresh();
      return true;
    } on TgApiException {
      rethrow;
    }
  }
}

final tgInventoryProvider =
    StateNotifierProvider<TgInventoryNotifier, TgInventoryState>((ref) => TgInventoryNotifier(ref));

// ---------- ابزار نمایش ----------
String tgStarsText(int? v) => v == null ? '—' : fmtStars(v);
