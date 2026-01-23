import 'package:flutter/foundation.dart';
import '../models/order_item_model.dart';

class CartService {
  static final CartService instance = CartService._();
  CartService._();

  final ValueNotifier<List<OrderItemModel>> items = ValueNotifier<List<OrderItemModel>>([]);

  void addItem(OrderItemModel item) {
    final list = List<OrderItemModel>.from(items.value);
    final idx = list.indexWhere((e) => e.menuId == item.menuId);
    if (idx >= 0) {
      final existing = list[idx];
      list[idx] = existing.copyWith(qty: existing.qty + item.qty);
    } else {
      list.add(item);
    }
    items.value = list;
  }

  void removeItem(String menuId) {
    items.value = items.value.where((e) => e.menuId != menuId).toList();
  }

  void updateQty(String menuId, int qty) {
    final list = items.value.map((e) => e.menuId == menuId ? e.copyWith(qty: qty) : e).toList();
    items.value = list;
  }

  void clear() => items.value = [];

  double getTotal() => items.value.fold(0.0, (p, e) => p + e.subtotal);
}
