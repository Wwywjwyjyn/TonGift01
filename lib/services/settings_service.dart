import 'package:shared_preferences/shared_preferences.dart';

/// تنظیمات محلی دستگاه — بدون هیچ ثبت‌نامی
class SettingsService {
  static const _kBackend = 'backend_url';
  static const _kLang = 'lang'; // fa | en
  static const _kMultigiftRef = 'multigift_ref';

  Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  Future<String?> getBackendUrl() async {
    final p = await _p;
    return p.getString(_kBackend);
  }

  Future<void> setBackendUrl(String url) async {
    final p = await _p;
    var u = url.trim();
    if (u.isNotEmpty && !u.startsWith('http')) u = 'https://$u';
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    await p.setString(_kBackend, u);
  }

  Future<String> getLang() async {
    final p = await _p;
    return p.getString(_kLang) ?? 'fa';
  }

  Future<void> setLang(String v) async {
    final p = await _p;
    await p.setString(_kLang, v);
  }

  Future<String> getMultigiftRef() async {
    final p = await _p;
    return p.getString(_kMultigiftRef) ?? '';
  }

  Future<void> setMultigiftRef(String v) async {
    final p = await _p;
    await p.setString(_kMultigiftRef, v.trim());
  }
}
