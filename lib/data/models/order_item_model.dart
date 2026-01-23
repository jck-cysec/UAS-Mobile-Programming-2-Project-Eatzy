import 'menu_model.dart';

class OrderItemModel {
  final String? id;
  final String menuId;
  final String name;
  final int qty;
  final double price;
  final String imageUrl;

  OrderItemModel({
    this.id,
    required this.menuId,
    required this.name,
    required this.qty,
    required this.price,
    this.imageUrl = '',
  });

  double get subtotal => price * qty;

  OrderItemModel copyWith({int? qty}) {
    return OrderItemModel(
      id: id,
      menuId: menuId,
      name: name,
      qty: qty ?? this.qty,
      price: price,
      imageUrl: imageUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'menu_id': menuId,
      'name': name,
      'qty': qty,
      'price': price,
      'image_url': imageUrl,
      'subtotal': subtotal,
    };
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      id: map['id']?.toString(),
      menuId: map['menu_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      qty: (map['qty'] is int) ? map['qty'] : int.tryParse(map['qty']?.toString() ?? '1') ?? 1,
      price: (map['price'] is num) ? (map['price'] as num).toDouble() : double.tryParse(map['price']?.toString() ?? '0') ?? 0.0,
      imageUrl: map['image_url']?.toString() ?? '',
    );
  }

  factory OrderItemModel.fromMenu(MenuModel m, {int qty = 1}) {
    return OrderItemModel(
      menuId: m.id,
      name: m.name,
      qty: qty,
      price: m.price.toDouble(),
      imageUrl: m.imageUrl,
    );
  }
} 
