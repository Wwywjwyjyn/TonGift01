import 'package:flutter/foundation.dart';

@immutable
class PriceInfo {
  final double ton;
  final double gram;
  final double? usd;
  const PriceInfo({required this.ton, required this.gram, this.usd});

  factory PriceInfo.fromJson(Map<String, dynamic> j) => PriceInfo(
        ton: (j['ton'] as num?)?.toDouble() ?? 0,
        gram: (j['gram'] as num?)?.toDouble() ?? 0,
        usd: (j['usd'] as num?)?.toDouble(),
      );
}

@immutable
class PremiumPrices {
  final PriceInfo months3;
  final PriceInfo months6;
  final PriceInfo months12;
  const PremiumPrices({
    required this.months3,
    required this.months6,
    required this.months12,
  });

  factory PremiumPrices.fromJson(Map<String, dynamic> j) => PremiumPrices(
        months3: PriceInfo.fromJson((j['months3'] ?? {}) as Map<String, dynamic>),
        months6: PriceInfo.fromJson((j['months6'] ?? {}) as Map<String, dynamic>),
        months12: PriceInfo.fromJson((j['months12'] ?? {}) as Map<String, dynamic>),
      );
}

@immutable
class CollectionModel {
  final String name;
  final String address;
  final int items;
  final double floorTon;
  final double rentFloorTon;
  final double volume7dTon;
  final double volume30dTon;
  final int owners;
  final int onSaleAll;
  final int onSaleOnchain;

  const CollectionModel({
    required this.name,
    required this.address,
    required this.items,
    required this.floorTon,
    required this.rentFloorTon,
    required this.volume7dTon,
    required this.volume30dTon,
    required this.owners,
    required this.onSaleAll,
    required this.onSaleOnchain,
  });

  factory CollectionModel.fromJson(Map<String, dynamic> j) {
    final e = (j['extra_data'] ?? {}) as Map<String, dynamic>;
    double ton(dynamic nano) {
      final v = double.tryParse('${nano ?? 0}') ?? 0;
      return v / 1e9;
    }

    return CollectionModel(
      name: (j['name'] ?? '').toString(),
      address: (j['address'] ?? '').toString(),
      items: int.tryParse('${e['items'] ?? 0}') ?? 0,
      floorTon: ton(e['floor']),
      rentFloorTon: ton(e['rent_floor']),
      volume7dTon: ton(e['volume7d']),
      volume30dTon: ton(e['volume30d']),
      owners: int.tryParse('${e['owners'] ?? 0}') ?? 0,
      onSaleAll: int.tryParse('${e['on_sale_all'] ?? 0}') ?? 0,
      onSaleOnchain: int.tryParse('${e['on_sale_onchain'] ?? 0}') ?? 0,
    );
  }
}

@immutable
class RecipientInfo {
  final String photo;
  final String name;
  const RecipientInfo({required this.photo, required this.name});

  factory RecipientInfo.fromJson(Map<String, dynamic> j) => RecipientInfo(
        photo: (j['photo'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
      );
}

enum OrderType { stars, premium, gift }

enum OrderStatus { created, sentToWallet, confirmed, failed }

@immutable
class OrderRecord {
  final String id;
  final OrderType type;
  final String title;
  final String subtitle;
  final double? amountTon;
  final OrderStatus status;
  final int createdAt;

  const OrderRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.amountTon,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'subtitle': subtitle,
        'amountTon': amountTon,
        'status': status.name,
        'createdAt': createdAt,
      };

  factory OrderRecord.fromJson(Map<String, dynamic> j) => OrderRecord(
        id: (j['id'] ?? '').toString(),
        type: OrderType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => OrderType.gift,
        ),
        title: (j['title'] ?? '').toString(),
        subtitle: (j['subtitle'] ?? '').toString(),
        amountTon: (j['amountTon'] as num?)?.toDouble(),
        status: OrderStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => OrderStatus.created,
        ),
        createdAt: int.tryParse('${j['createdAt'] ?? 0}') ?? 0,
      );

  OrderRecord withStatus(OrderStatus s) => OrderRecord(
        id: id,
        type: type,
        title: title,
        subtitle: subtitle,
        amountTon: amountTon,
        status: s,
        createdAt: createdAt,
      );
}
