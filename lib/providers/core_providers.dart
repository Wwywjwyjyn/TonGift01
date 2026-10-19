import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final String lang; // fa | en
  final String multigiftRef;

  const SettingsState({
    this.loaded = false,
    this.backendUrl,
    this.lang = 'fa',
    this.multigiftRef = '',
  });

  bool get fa => lang == 'fa';
  S get s => S(fa);

  SettingsState copyWith({
    bool? loaded,
    String? backendUrl,
    String? lang,
    String? multigiftRef,
  }) =>
      SettingsState(
        loaded: loaded ?? this.loaded,
        backendUrl: backendUrl ?? this.backendUrl,
        lang: lang ?? this.lang,
        multigiftRef: multigiftRef ?? this.multigiftRef,
      );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsService _svc;
  SettingsNotifier(this._svc) : super(const SettingsState());

  Future<void> load() async {
    final url = await _svc.getBackendUrl();
    final lang = await _svc.getLang();
    final ref = await _svc.getMultigiftRef();
    state = SettingsState(loaded: true, backendUrl: url, lang: lang, multigiftRef: ref);
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
