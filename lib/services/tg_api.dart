import 'dart:convert';
import 'package:http/http.dart' as http;

/// خطای استاندارد دروازه تلگرام
class TgApiException implements Exception {
  final int status;
  final String detail;
  final String? code; // need_api | not_connected | no_pending | bad_code
  final int? retryAfter; // FLOOD_WAIT
  final bool needPassword;
  TgApiException(this.status, this.detail,
      {this.code, this.retryAfter, this.needPassword = false});

  bool get isFlood => status == 429;
  bool get needApi => code == 'need_api';
  bool get notConnected => code == 'not_connected' || status == 401;

  @override
  String toString() => detail;
}

/// کلاینت دروازه MTProto — مارکت رسمی گیفت تلگرام
/// نشست تلگرام فقط روی بک‌اند خودت ذخیره می‌شود؛ api_id/api_hash هرگز جابه‌جا نمی‌شود.
class TgApi {
  final String baseUrl;
  final String Function() deviceToken;
  final http.Client _http = http.Client();

  TgApi(this.baseUrl, this.deviceToken);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Device-Token': deviceToken(),
      };

  /// هدر عکس‌ها (استیکرها با توکن دستگاه می‌آیند)
  Map<String, String> imgHeaders() => {'X-Device-Token': deviceToken()};

  String stickerUrl(String docId) => '$baseUrl/api/tg/sticker/$docId';

  Uri _u(String path, [Map<String, dynamic>? q]) {
    final qq = q?.entries.where((e) => e.value != null).toList() ?? [];
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: qq.isEmpty
          ? null
          : {for (final e in qq) e.key: e.value.toString()},
    );
  }

  Future<dynamic> _req(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final req = http.Request(method, _u(path, query));
      req.headers.addAll(_headers);
      if (body != null) req.body = jsonEncode(body);
      final res = await _http.send(req).timeout(timeout);
      final text = await res.stream.bytesToString();
      dynamic json;
      try {
        json = text.isEmpty ? null : jsonDecode(text);
      } catch (_) {
        json = {'raw': text};
      }
      if (res.statusCode >= 200 && res.statusCode < 300) return json;
      final m = json is Map ? json : const {};
      throw TgApiException(
        res.statusCode,
        (m['detail'] ?? m['error'] ?? 'Error ${res.statusCode}').toString(),
        code: m['code']?.toString(),
        retryAfter: m['retry_after'] is int ? m['retry_after'] as int : null,
        needPassword: m['need_password'] == true,
      );
    } on TgApiException {
      rethrow;
    } catch (e) {
      throw TgApiException(0, 'Network error: backend unreachable');
    }
  }

  // ---------- وضعیت و ورود ----------
  Future<dynamic> status() =>
      _req('GET', '/api/tg/status', timeout: const Duration(seconds: 20));

  Future<dynamic> sendCode(String phone) =>
      _req('POST', '/api/tg/send-code', body: {'phone': phone});

  Future<dynamic> signIn(String phone, String phoneCodeHash, String code) =>
      _req('POST', '/api/tg/sign-in', body: {
        'phone': phone,
        'phone_code_hash': phoneCodeHash,
        'code': code,
      });

  Future<dynamic> twoFa(String password) =>
      _req('POST', '/api/tg/2fa', body: {'password': password});

  Future<dynamic> logout() => _req('POST', '/api/tg/logout', body: {});

  // ---------- مارکت ----------
  Future<dynamic> catalog() => _req('GET', '/api/tg/catalog');

  /// کف قیمت چند نوع گیفت (ids با کاما — حداکثر ۲۴ تا)
  Future<dynamic> floors(List<int> ids) => _req('GET', '/api/tg/floors',
      query: {'ids': ids.join(',')},
      timeout: const Duration(seconds: 45));

  /// لیست فروشندگان یک نوع گیفت — sort: price | num | recent
  Future<dynamic> listings(int giftId,
          {String sort = 'price', String offset = '', int limit = 24}) =>
      _req('GET', '/api/tg/listings',
          query: {'gift_id': giftId, 'sort': sort, 'offset': offset, 'limit': limit});

  // ---------- انبار من ----------
  Future<dynamic> myGifts() =>
      _req('GET', '/api/tg/my-gifts', timeout: const Duration(seconds: 60));

  Future<dynamic> stars() => _req('GET', '/api/tg/stars');

  // ---------- تراکنش‌ها ----------
  /// خرید گیفت دست‌دوم — با موجودی استارز اکانت
  Future<dynamic> buy(String slug, {String? toUsername}) =>
      _req('POST', '/api/tg/buy', body: {
        'slug': slug,
        if (toUsername != null && toUsername.isNotEmpty)
          'to_username': toUsername,
      });

  /// خرید گیفت جدید از کاتالوگ — هدیه به خودم یا یوزرنیم
  Future<dynamic> buyNew(int giftId,
          {String? toUsername, String? message, bool includeUpgrade = false}) =>
      _req('POST', '/api/tg/buy-new', body: {
        'gift_id': giftId,
        if (toUsername != null && toUsername.isNotEmpty)
          'to_username': toUsername,
        if (message != null && message.isNotEmpty) 'message': message,
        if (includeUpgrade) 'include_upgrade': true,
      });

  /// فروش‌گذاری / تغییر قیمت (قیمت به استارز)
  Future<dynamic> listForSale(int msgId, int price) =>
      _req('POST', '/api/tg/list', body: {'msg_id': msgId, 'price': price});

  /// حذف از فروش
  Future<dynamic> unlist(int msgId) =>
      _req('POST', '/api/tg/unlist', body: {'msg_id': msgId});

  /// انتقال گیفت به یوزرنیم
  Future<dynamic> transfer(int msgId, String toUsername) =>
      _req('POST', '/api/tg/transfer',
          body: {'msg_id': msgId, 'to_username': toUsername});

  /// آپگرید به گیفت یکتا
  Future<dynamic> upgrade(int msgId) =>
      _req('POST', '/api/tg/upgrade', body: {'msg_id': msgId});

  /// بررسی یوزرنیم گیرنده (پیش‌نمایش قبل از انتقال/هدیه)
  Future<dynamic> resolve(String username) =>
      _req('POST', '/api/tg/resolve', body: {'username': username});
}
