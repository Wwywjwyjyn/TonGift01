import 'dart:convert';
import 'package:http/http.dart' as http;

/// خطای استاندارد API
class ApiException implements Exception {
  final int status;
  final String detail;
  ApiException(this.status, this.detail);
  bool get isPaidRequired => status == 402 || status == 403;

  @override
  String toString() => detail;
}

/// کلاینت ارتباط با بک‌اند خودت (پراکسی امن Marketapp API)
/// کلید API هرگز در اپ نیست — همه‌چیز از بک‌اند رد می‌شود.
class ApiClient {
  final String baseUrl;
  final http.Client _http = http.Client();

  ApiClient(this.baseUrl);

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
    Duration timeout = const Duration(seconds: 25),
  }) async {
    try {
      final uri = _u(path, query);
      final req = http.Request(method, uri);
      req.headers['Content-Type'] = 'application/json';
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
      final detail = json is Map ? (json['detail'] ?? json['error'] ?? 'خطا ${res.statusCode}') : 'خطا ${res.statusCode}';
      throw ApiException(res.statusCode, detail.toString());
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'خطای شبکه: بک‌اند در دسترس نیست');
    }
  }

  // ---------- سلامت ----------
  Future<bool> health() async {
    try {
      final r = await _req('GET', '/api/health',
          timeout: const Duration(seconds: 6));
      return r is Map && r['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  // ---------- استارز ----------
  Future<dynamic> starsPrice(int quantity) =>
      _req('POST', '/api/stars/price', body: {'quantity': quantity});

  Future<dynamic> starsRecipient(String username) =>
      _req('POST', '/api/stars/recipient', body: {'username': username});

  Future<dynamic> starsBuy(String username, int quantity,
          {String currency = 'TON'}) =>
      _req('POST', '/api/stars/buy',
          body: {'username': username, 'quantity': quantity, 'currency': currency});

  // ---------- پریمیوم ----------
  Future<dynamic> premiumPrice() => _req('POST', '/api/premium/price', body: {});

  Future<dynamic> premiumRecipient(String username) =>
      _req('POST', '/api/premium/recipient', body: {'username': username});

  Future<dynamic> premiumBuy(String username, int months,
          {String currency = 'TON'}) =>
      _req('POST', '/api/premium/buy',
          body: {'username': username, 'months': months, 'currency': currency});

  // ---------- کالکشن‌ها ----------
  Future<dynamic> collectionsGifts() =>
      _req('GET', '/api/collections/gifts');

  // ---------- مارکت ----------
  Future<dynamic> giftsOnsale({
    int limit = 50,
    String? cursor,
    String? collectionAddress,
    String? sortBy,
  }) =>
      _req('GET', '/api/gifts/onsale', query: {
        'limit': limit,
        'cursor': cursor,
        'collection_address': collectionAddress,
        'sort_by': sortBy,
      });

  Future<dynamic> rentGifts({int limit = 50, String? cursor}) =>
      _req('GET', '/api/rent/gifts', query: {'limit': limit, 'cursor': cursor});

  /// پرداخت اجاره — duration به ثانیه (حداقل از آیتم فید) و قیمت روزانه به نانوتون (همان رشته فید)
  Future<dynamic> rentPay(String nftAddress,
          {required int duration, required String pricePerDayNano}) =>
      _req('POST', '/api/rent/pay', body: {
        'nft_address': nftAddress,
        'duration': duration,
        'price_per_day': pricePerDayNano,
      });

  /// تمدید اجاره
  Future<dynamic> rentExtend(String nftAddress,
          {required int duration, required String pricePerDayNano}) =>
      _req('POST', '/api/rent/extend', body: {
        'nft_address': nftAddress,
        'duration': duration,
        'price_per_day': pricePerDayNano,
      });

  /// گیفت‌های در حال اجاره من
  Future<dynamic> rentMyRented() => _req('GET', '/api/rent/my-rented');

  /// تاریخچه اجاره (category: gifts | usernames | numbers)
  Future<dynamic> rentHistory({String category = 'gifts', int limit = 30}) =>
      _req('GET', '/api/rent/history', query: {'category': category, 'limit': limit});

  /// لغو اجاره‌گذاری (حداکثر ۱۰ آدرس)
  Future<dynamic> rentCancel(List<String> addresses) =>
      _req('POST', '/api/rent/cancel', body: {'nft_addresses': addresses});

  /// اجاره‌گذاری گیفت‌ها (حداکثر ۱۰ آیتم) — duration به ثانیه و مضرب ۸۶۴۰۰
  Future<dynamic> rentOutGifts(List<Map<String, dynamic>> items) =>
      _req('POST', '/api/rent/rent-out', body: {'items': items});

  /// به‌روزرسانی تنظیمات اجاره‌گذاری
  Future<dynamic> rentUpdateSettings(List<Map<String, dynamic>> items) =>
      _req('POST', '/api/rent/update-settings', body: {'items': items});

  // ---------- آیتم‌های یک کالکشن ----------
  Future<dynamic> nftsCollection(String address,
          {int limit = 50, String? cursor, int? offset}) =>
      _req('GET', '/api/nfts/collection/$address', query: {
        'limit': limit,
        'cursor': cursor,
        'offset': offset,
      });

  // ---------- NFT ----------
  Future<dynamic> nftsOwner(String address, {int limit = 250, String? cursor}) =>
      _req('GET', '/api/nfts/owner/$address', query: {'limit': limit, 'cursor': cursor});

  Future<dynamic> nftInfo(String address) =>
      _req('GET', '/api/nfts/info/$address');

  Future<dynamic> nftSale(String ownerAddress, List<Map<String, dynamic>> data) =>
      _req('POST', '/api/nfts/sale',
          body: {'owner_address': ownerAddress, 'data': data});

  Future<dynamic> nftBuy(List<Map<String, dynamic>> data) =>
      _req('POST', '/api/nfts/buy', body: {'data': data});

  Future<dynamic> nftChangePrice(
          String ownerAddress, List<Map<String, dynamic>> data) =>
      _req('POST', '/api/nfts/change_price',
          body: {'owner_address': ownerAddress, 'data': data});

  Future<dynamic> nftCancelSale(String ownerAddress, List<String> addresses) =>
      _req('POST', '/api/nfts/cancel_sale',
          body: {'owner_address': ownerAddress, 'nft_addresses': addresses});

  // ---------- ابزارها ----------
  Future<dynamic> resolveGift(String link) =>
      _req('POST', '/api/resolve-gift', body: {'link': link});

  Future<dynamic> walletBalance(String address) =>
      _req('GET', '/api/wallet/$address/balance');

  Future<dynamic> irtRate() => _req('GET', '/api/rate/irt');
}
