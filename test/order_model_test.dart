import 'package:flutter_test/flutter_test.dart';
import 'package:eatzy_app/data/models/order_model.dart';

void main() {
  test('OrderModel.fromMap parses nested users.full_name and payment_method', () {
    final map = {
      'id': 'o1',
      'user_id': 'u1',
      'status': 'pending',
      'delivery_type': 'pickup',
      'order_time': DateTime.now().toIso8601String(),
      'users': {'full_name': 'Alice Example'},
      'payment_method': 'card',
      'order_items': [
        {
          'food_id': 'm1',
          'quantity': 2,
          'food': {'id': 'm1', 'name': 'Nasi Goreng', 'price': 20000, 'image_url': ''}
        }
      ],
      'total_price': 40000,
    };

    final om = OrderModel.fromMap(map);
    expect(om.customerName, 'Alice Example');
    expect(om.paymentMethod, 'card');
    expect(om.items.length, 1);
    expect(om.totalPrice, 40000);
  });

  test('OrderModel.fromMap falls back when users missing', () {
    final map = {
      'id': 'o2',
      'user_id': 'u2',
      'status': 'completed',
      'delivery_type': 'delivery',
      'order_time': DateTime.now().toIso8601String(),
      'customer_name': 'Fallback Name',
      'payment_method': 'cash',
      'order_items': [],
      'total_price': 0,
    };

    final om = OrderModel.fromMap(map);
    expect(om.customerName, 'Fallback Name');
    expect(om.paymentMethod, 'cash');
  });

  test('OrderModel.fromMap prefers profiles.full_name when present', () {
    final map = {
      'id': 'o3',
      'user_id': 'u3',
      'status': 'pending',
      'delivery_type': 'pickup',
      'order_time': DateTime.now().toIso8601String(),
      'profiles': {'full_name': 'Profile Name'},
      'users': {'full_name': 'User Name'},
      'payment_method': 'cash',
      'order_items': [],
      'total_price': 0,
    };

    final om = OrderModel.fromMap(map);
    expect(om.customerName, 'Profile Name');
  });
}
