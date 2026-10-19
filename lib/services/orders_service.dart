import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// تاریخچه سفارش‌ها — فقط روی همین دستگاه، وضعیت‌های واقعی
class OrdersService {
  static const _k = 'order_records';

  Future<List<OrderRecord>> list() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null) return [];
    try {
      final arr = jsonDecode(raw) as List;
      return arr.map((e) => OrderRecord.fromJson(e as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> add(OrderRecord rec) async {
    final p = await SharedPreferences.getInstance();
    final items = await list();
    items.insert(0, rec);
    final trimmed = items.take(100).map((e) => e.toJson()).toList();
    await p.setString(_k, jsonEncode(trimmed));
  }

  Future<void> updateStatus(String id, OrderStatus status) async {
    final p = await SharedPreferences.getInstance();
    final items = await list();
    final updated = items.map((e) => e.id == id ? e.withStatus(status) : e).toList();
    await p.setString(_k, jsonEncode(updated.map((e) => e.toJson()).toList()));
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_k);
  }
}
