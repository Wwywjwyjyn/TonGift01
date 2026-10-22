import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gift_item.dart';

/// سبد خرید — اقلام واقعی مارکت، ذخیره محلی روی گوشی
class CartState {
  final List<GiftItem> items;
  const CartState({this.items = const []});

  bool contains(String address) => items.any((g) => g.address == address);

  double get totalTon => items.fold(0, (a, g) => a + (g.priceTon ?? 0));

  CartState copyWith({List<GiftItem>? items}) => CartState(items: items ?? this.items);
}

class CartNotifier extends StateNotifier<CartState> {
  static const _k = 'cart_items_v1';
  CartNotifier() : super(const CartState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_k);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List? ?? [])
          .map((e) => GiftItem.fromOnsale(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (list.isNotEmpty) state = CartState(items: list);
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_k, jsonEncode(state.items.map((g) => g.raw).toList()));
    } catch (_) {}
  }

  bool add(GiftItem g) {
    if (g.address.isEmpty || contains(g.address)) return false;
    state = CartState(items: [...state.items, g]);
    _persist();
    return true;
  }

  void remove(String address) {
    state = CartState(items: state.items.where((g) => g.address != address).toList());
    _persist();
  }

  void clear() {
    state = const CartState(items: []);
    _persist();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());
