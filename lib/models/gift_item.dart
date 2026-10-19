/// مدل یکپارچه گیفت/NFT — از هر منبعی (فروش، اجاره، انبار، لینک)
class GiftItem {
  final String address; // آدرس NFT روی TON (برای لینک‌های resolve خالی)
  final String name; // مثل: Fresh Socks
  final int? number; // مثل: 36377
  final String collectionAddress;
  final String? collectionName;
  final String? owner; // مالک فعلی
  final String? model;
  final String? backdrop;
  final String? symbol;
  final double? priceTon; // قیمت فروش (TON)
  final double? pricePerDayTon; // اجاره روزانه
  final String currency; // TON | STARS | GRAM
  final String kind; // sale | rent | owner | resolved
  final String status; // for_sale | not_for_sale | for_rent
  final String? imageUrl;
  final String? lottieUrl;
  final int? listedAt;
  final Map<String, dynamic> raw;

  const GiftItem({
    required this.address,
    required this.name,
    this.number,
    this.collectionAddress = '',
    this.collectionName,
    this.owner,
    this.model,
    this.backdrop,
    this.symbol,
    this.priceTon,
    this.pricePerDayTon,
    this.currency = 'TON',
    this.kind = 'sale',
    this.status = 'not_for_sale',
    this.imageUrl,
    this.lottieUrl,
    this.listedAt,
    this.raw = const {},
  });

  String get displayName => number != null ? '$name #$number' : name;

  /// اسلاگ تلگرام: Fresh Socks #36377 -> FreshSocks-36377
  String get slug {
    final base = name.replaceAll(RegExp(r'\s+'), '');
    return number != null ? '$base-$number' : base;
  }

  /// عکس واقعی همان گیفت (رندر تلگرام: مدل + بک‌گراند)
  String get effectiveImage =>
      (imageUrl != null && imageUrl!.isNotEmpty)
          ? imageUrl!
          : 'https://nft.fragment.com/gift/${slug.toLowerCase()}.webp';

  String get imageFallback =>
      'https://nft.fragment.com/gift/${slug.toLowerCase()}.webp';

  /// لینک باز کردن در تلگرام
  String get telegramUrl => 'https://t.me/nft/$slug';

  // ---------- ساخت از NFTItem مارکت (gifts/onsale) ----------
  factory GiftItem.fromOnsale(Map<String, dynamic> j) {
    final name = (j['name'] ?? '').toString();
    final numMatch = RegExp(r'#\s*(\d+)\s*$').firstMatch(name);
    final cleanName = name.replaceAll(RegExp(r'#\s*\d+\s*$'), '').trim();
    final cur = (j['currency'] ?? 'TON').toString().toUpperCase();
    final price = double.tryParse((j['min_bid'] ?? '0').toString()) ?? 0;
    final attrs = (j['attributes'] as List?) ?? const [];
    return GiftItem(
      address: (j['address'] ?? '').toString(),
      name: cleanName.isEmpty ? name : cleanName,
      number: numMatch != null ? int.tryParse(numMatch.group(1)!) : (j['item_num'] is int ? j['item_num'] as int : null),
      collectionAddress: (j['collection_address'] ?? '').toString(),
      owner: (j['owner'] ?? j['real_owner'] ?? '').toString(),
      model: _attr(attrs, 'model'),
      backdrop: _attr(attrs, 'backdrop'),
      symbol: _attr(attrs, 'symbol'),
      priceTon: cur == 'STARS' ? null : price / 1e9,
      currency: cur,
      kind: 'sale',
      status: 'for_sale',
      listedAt: j['listed_at'] is int ? j['listed_at'] as int : null,
      raw: j,
    );
  }

  // ---------- ساخت از آیتم اجاره (rent/gifts) ----------
  factory GiftItem.fromRent(Map<String, dynamic> j) {
    final name = (j['nft_name'] ?? '').toString();
    final numMatch = RegExp(r'#\s*(\d+)\s*$').firstMatch(name);
    final cleanName = name.replaceAll(RegExp(r'#\s*\d+\s*$'), '').trim();
    final attrs = (j['attributes'] as List?) ?? const [];
    return GiftItem(
      address: (j['nft_address'] ?? '').toString(),
      name: cleanName.isEmpty ? name : cleanName,
      number: numMatch != null ? int.tryParse(numMatch.group(1)!) : null,
      owner: (j['owner'] ?? '').toString(),
      model: _attr(attrs, 'model'),
      backdrop: _attr(attrs, 'backdrop'),
      symbol: _attr(attrs, 'symbol'),
      pricePerDayTon: (double.tryParse((j['price_per_day'] ?? '0').toString()) ?? 0) / 1e9,
      currency: 'TON',
      kind: 'rent',
      status: 'for_rent',
      listedAt: j['listed_at'] is int ? j['listed_at'] as int : null,
      raw: j,
    );
  }

  // ---------- ساخت از NFTsResponse مارکت‌اپ (nfts/owner) ----------
  factory GiftItem.fromOwnerNft(Map<String, dynamic> j) {
    final name = (j['name'] ?? '').toString();
    final numMatch = RegExp(r'#\s*(\d+)\s*$').firstMatch(name);
    final cleanName = name.replaceAll(RegExp(r'#\s*\d+\s*$'), '').trim();
    final attrs = (j['attributes'] as List?) ?? const [];
    final status = (j['status'] ?? 'not_for_sale').toString();
    double? price;
    String cur = 'TON';
    final det = j['status_details'];
    if (det is Map && det['price'] != null) {
      price = (double.tryParse(det['price'].toString()) ?? 0) / 1e9;
      cur = (det['currency'] ?? 'TON').toString().toUpperCase();
    }
    return GiftItem(
      address: (j['address'] ?? '').toString(),
      name: cleanName.isEmpty ? name : cleanName,
      number: numMatch != null ? int.tryParse(numMatch.group(1)!) : null,
      collectionAddress: (j['collection_address'] ?? '').toString(),
      owner: (j['real_owner'] ?? j['owner'] ?? '').toString(),
      model: _attr(attrs, 'model'),
      backdrop: _attr(attrs, 'backdrop'),
      symbol: _attr(attrs, 'symbol'),
      priceTon: price,
      currency: cur,
      kind: 'owner',
      status: status.contains('sale') ? 'for_sale' : 'not_for_sale',
      raw: j,
    );
  }

  // ---------- ساخت از resolve لینک t.me ----------
  factory GiftItem.fromResolved(Map<String, dynamic> j) {
    return GiftItem(
      address: '',
      name: (j['name'] ?? '').toString(),
      number: j['number'] is int ? j['number'] as int : int.tryParse('${j['number']}'),
      imageUrl: (j['image'] ?? '').toString(),
      lottieUrl: (j['lottie'] ?? '').toString(),
      kind: 'resolved',
      status: 'not_for_sale',
      raw: j,
    );
  }

  static String? _attr(List attrs, String type) {
    for (final a in attrs) {
      if (a is Map) {
        final t = (a['trait_type'] ?? '').toString().toLowerCase();
        if (t == type) return a['value']?.toString();
      }
    }
    return null;
  }
}
