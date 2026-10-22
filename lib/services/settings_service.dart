import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

/// تنظیمات محلی دستگاه — بدون هیچ ثبت‌نامی
class SettingsService {
  static const _kBackend = 'backend_url';
  static const _kLang = 'lang'; // fa | en — انگلیسی پیش‌فرض
  static const _kMultigiftRef = 'multigift_ref';
  static const _kDeviceToken = 'device_token'; // شناسه دستگاه برای گیت اولین کاربر
  static const _kGateLastShown = 'gate_last_shown'; // آخرین بار که گیت نشان داده شد

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
    return p.getString(_kLang) ?? 'en'; // زبان مارکت انگلیسی است؛ فارسی از تنظیمات
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

  /// توکن یکتای دستگاه — برای اینکه فقط اولین دستگاه «مالک» شناخته شود
  Future<String> getDeviceToken() async {
    final p = await _p;
    var t = p.getString(_kDeviceToken);
    if (t == null || t.isEmpty) {
      final rnd = Random.secure();
      t = List.generate(48, (_) => '0123456789abcdef'[rnd.nextInt(16)]).join();
      await p.setString(_kDeviceToken, t);
    }
    return t;
  }

  /// گیت فقط یک‌بار در هر اجرای اپ باز شود (وقتی رد شد، تا اجرای بعدی نه)
  Future<int> getGateLastShown() async {
    final p = await _p;
    return p.getInt(_kGateLastShown) ?? 0;
  }

  Future<void> setGateLastShown(int ms) async {
    final p = await _p;
    await p.setInt(_kGateLastShown, ms);
  }
}
