import 'order_item_model.dart';

class OrderModel {
  final String id;
  final String userId;
  final String status;
  final String deliveryType;
  final DateTime orderTime;
  final DateTime? prepareUntil;
  final String customerName;
  final String paymentMethod;
  final List<OrderItemModel> items;
  final double subtotal;
  final double deliveryTip;
  final double totalPrice;
  final String? deliveryAddress;
  final bool isDeleted;
  final DateTime? deletedAt;

  OrderModel({
    required this.id,
    required this.userId,
    required this.status,
    required this.deliveryType,
    required this.orderTime,
    this.prepareUntil,
    required this.customerName,
    required this.paymentMethod,
    required this.items,
    required this.subtotal,
    required this.deliveryTip,
    required this.totalPrice,
    this.deliveryAddress,
    required this.isDeleted,
    this.deletedAt,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    // parse items: accept both normalized `items` and embedded `order_items` (with optional `food` join)
    final rawItems = map['items'] ?? map['order_items'];
    final parsedItems = <OrderItemModel>[];
    if (rawItems is List) {
      for (final it in rawItems) {
        try {
          if (it is Map) {
            final m = Map<String, dynamic>.from(it);
            // If this looks like a joined order_items row, normalize to OrderItemModel.fromMap shape
            if (m.containsKey('food') || m.containsKey('food_id') || m.containsKey('quantity')) {
              final food = (m['food'] is Map) ? Map<String, dynamic>.from(m['food'] as Map) : null;
              final normalized = {
                'menu_id': food != null ? (food['id'] ?? m['food_id']) : (m['food_id'] ?? m['menu_id']),
                'name': food != null ? (food['name'] ?? '') : (m['name'] ?? ''),
                'qty': m['quantity'] ?? m['qty'] ?? 1,
                'price': food != null ? (food['price'] ?? m['price'] ?? 0) : (m['price'] ?? 0),
                'image_url': food != null ? (food['image_url'] ?? '') : (m['image_url'] ?? ''),
              };
              parsedItems.add(OrderItemModel.fromMap(normalized));
            } else {
              parsedItems.add(OrderItemModel.fromMap(m));
            }
          }
        } catch (_) {}
      }
    }

    DateTime parsedTime;
    try {
      parsedTime = DateTime.parse(map['order_time'] ?? map['created_at'] ?? DateTime.now().toIso8601String());
    } catch (_) {
      parsedTime = DateTime.now();
    }

    // Compute subtotal by summing item price * qty when possible
    double computedSubtotal = 0.0;
    try {
      for (final it in parsedItems) {
        computedSubtotal += (it.price * it.qty);
      }
    } catch (_) {
      computedSubtotal = 0.0;
    }

    // Parse delivery tip safely
    double parsedDeliveryTip = 0.0;
    try {
      final dt = map['delivery_tip'] ?? map['deliveryTip'] ?? map['delivery_fee'] ?? map['deliveryFee'];
      if (dt is num) {
        parsedDeliveryTip = dt.toDouble();
      } else {
        parsedDeliveryTip = double.tryParse(dt?.toString() ?? '0') ?? 0.0;
      }
    } catch (_) {
      parsedDeliveryTip = 0.0;
    }

    // Determine total price: prefer explicit server value if present, otherwise compute
    double total;
    try {
      final t = map['total_price'] ?? map['total'];
      if (t != null) {
        if (t is num) {
          total = t.toDouble();
        } else {
          total = double.tryParse(t.toString()) ?? (computedSubtotal + parsedDeliveryTip);
        }
      } else {
        total = computedSubtotal + parsedDeliveryTip;
      }
    } catch (_) {
      total = computedSubtotal + parsedDeliveryTip;
    }

    double totalParsedOrComputed = total;

    final paymentMethod = (map['payment_method'] ?? map['paymentMethod'] ?? map['method'])?.toString() ?? 'unknown';

    DateTime? parsedDeletedAt;
    if (map['deleted_at'] != null) {
      try {
        parsedDeletedAt = DateTime.tryParse(map['deleted_at'].toString());
      } catch (_) {
        parsedDeletedAt = null;
      }
    }

    return OrderModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      deliveryType: map['delivery_type']?.toString() ?? 'pickup',
      orderTime: parsedTime,
      prepareUntil: map['prepare_until'] != null ? DateTime.tryParse(map['prepare_until']) : null,
      // Prefer profile full_name when available (JOINed as `profiles`), fall back to users.* then customer_name
      customerName: map['profiles']?['full_name'] ?? map['users']?['full_name'] ?? map['customer_name'] ?? 'Unknown User',
      paymentMethod: paymentMethod,
      items: parsedItems,
      subtotal: computedSubtotal,
      deliveryTip: parsedDeliveryTip,
      totalPrice: totalParsedOrComputed,
      deliveryAddress: map['delivery_address'] ?? map['deliveryAddress'] ?? map['building_id'] ?? map['buildingId'],
      isDeleted: map['is_deleted'] ?? false,
      deletedAt: parsedDeletedAt,
    );
  }
}
