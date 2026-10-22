import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/strings.dart';
import '../services/settings_service.dart';
import '../services/api_client.dart';
import '../services/tonconnect_service.dart';
import '../services/orders_service.dart';

// ---------- سرویس‌های سینگلتون ----------
final settingsServiceProvider = Provider<SettingsService>((ref) => SettingsService());
final ordersServiceProvider = Provider<OrdersService>((ref) => OrdersService());
final tonConnectServiceProvider = Provider<TonConnectService>((ref) => TonConnectService());

// ---------- تنظیمات ----------
class SettingsState {
  final bool loaded;
  final String? backendUrl;
  final String lang; // fa | en — پیش‌فرض انگلیسی
  final String multigiftRef;
  final String deviceToken;

  const SettingsState({
    this.loaded = false,
    this.backendUrl,
    this.lang = 'en',
    this.multigiftRef = '',
    this.deviceToken = '',
  });

  bool get fa => lang == 'fa';
  S get s => S(fa);

  SettingsState copyWith({
    bool? loaded,
    String? backendUrl,
    String? lang,
    String? multigiftRef,
    String? deviceToken,
  }) =>
      SettingsState(
        loaded: loaded ?? this.loaded,
        backendUrl: backendUrl ?? this.backendUrl,
        lang: lang ?? this.lang,
        multigiftRef: multigiftRef ?? this.multigiftRef,
        deviceToken: deviceToken ?? this.deviceToken,
      );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsService _svc;
  SettingsNotifier(this._svc) : super(const SettingsState());

  Future<void> load() async {
    final url = await _svc.getBackendUrl();
    final lang = await _svc.getLang();
    final ref = await _svc.getMultigiftRef();
    final dev = await _svc.getDeviceToken();
    state = SettingsState(
      loaded: true,
      backendUrl: url,
      lang: lang,
      multigiftRef: ref,
      deviceToken: dev,
    );
  }

  Future<void> setBackendUrl(String url) async {
    await _svc.setBackendUrl(url);
    state = state.copyWith(backendUrl: await _svc.getBackendUrl());
  }

  Future<void> setLang(String v) async {
    await _svc.setLang(v);
    state = state.copyWith(lang: v);
  }

  Future<void> setMultigiftRef(String v) async {
    await _svc.setMultigiftRef(v);
    state = state.copyWith(multigiftRef: v);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final n = SettingsNotifier(ref.watch(settingsServiceProvider));
  n.load();
  return n;
});

// ---------- کلاینت API (بازسازی خودکار با تغییر آدرس بک‌اند) ----------
final apiProvider = Provider<ApiClient>((ref) {
  final url = ref.watch(settingsProvider).backendUrl ?? '';
  return ApiClient(url);
});

// ---------- گیت «اولین کاربر» برای API ID / API Hash ----------
/// وضعیت گیت از بک‌اند می‌آید؛ فقط اولین دستگاهی که وضعیت می‌پرسد مالک است.
class OwnerGateState {
  final bool checked;
  final bool isOwner; // فقط نفر اول true می‌شود
  final bool pending; // هنوز API را وارد نکرده
  final bool claimed; // وارد کرده — دیگر هیچ‌وقت نشان داده نمی‌شود
  final bool apiIdSet;
  final bool gateShownThisSession;

  const OwnerGateState({
    this.checked = false,
    this.isOwner = false,
    this.pending = false,
    this.claimed = false,
    this.apiIdSet = false,
    this.gateShownThisSession = false,
  });

  /// آیا الان باید گیت باز شود؟ فقط مالکِ در انتظار و فقط یک‌بار در هر اجرا
  bool get shouldShow => checked && isOwner && pending && !gateShownThisSession;

  OwnerGateState copyWith({
    bool? checked,
    bool? isOwner,
    bool? pending,
    bool? claimed,
    bool? apiIdSet,
    bool? gateShownThisSession,
  }) =>
      OwnerGateState(
        checked: checked ?? this.checked,
        isOwner: isOwner ?? this.isOwner,
        pending: pending ?? this.pending,
        claimed: claimed ?? this.claimed,
        apiIdSet: apiIdSet ?? this.apiIdSet,
        gateShownThisSession: gateShownThisSession ?? this.gateShownThisSession,
      );
}

class OwnerGateNotifier extends StateNotifier<OwnerGateState> {
  final Ref ref;
  OwnerGateNotifier(this.ref) : super(const OwnerGateState());

  Future<void> check() async {
    final st = ref.read(settingsProvider);
    final api = ref.read(apiProvider);
    if (st.backendUrl == null || st.backendUrl!.isEmpty) {
      state = state.copyWith(checked: true);
      return;
    }
    try {
      final r = await api.ownerStatus(st.deviceToken) as Map<String, dynamic>;
      state = OwnerGateState(
        checked: true,
        isOwner: r['is_owner'] == true,
        pending: r['state'] == 'pending',
        claimed: r['state'] == 'claimed',
        apiIdSet: r['api_id_set'] == true,
        gateShownThisSession: false,
      );
    } catch (_) {
      state = state.copyWith(checked: true);
    }
  }

  /// رد کردن در این اجرا — دفعه بعد که اپ باز شود دوباره نشان داده می‌شود
  void dismissedThisSession() {
    state = state.copyWith(gateShownThisSession: true);
  }

  Future<bool> claim(String apiId, String apiHash) async {
    final st = ref.read(settingsProvider);
    final api = ref.read(apiProvider);
    try {
      await api.ownerClaim(st.deviceToken, apiId, apiHash);
      state = state.copyWith(pending: false, claimed: true, apiIdSet: true, gateShownThisSession: true);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final ownerGateProvider =
    StateNotifierProvider<OwnerGateNotifier, OwnerGateState>((ref) => OwnerGateNotifier(ref));
