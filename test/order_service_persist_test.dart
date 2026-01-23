import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:eatzy_app/data/services/order_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persistPendingOrderPayload stores full payload with items', () async {
    SharedPreferences.setMockInitialValues({});
    final svc = OrderService();

    final payload = {
      'user_id': '11111111-1111-1111-1111-111111111111',
      'delivery_type': 'delivery',
      'delivery_address': 'Gedung A blok 3',
    };

    final items = [
      {'menu_id': 'm1', 'qty': 2, 'price': 10000},
    ];

    await svc.persistPendingOrderPayload(payload, items);

    final list = await svc.listPendingOrders();
    expect(list.length, 1);
    final stored = list.first;
    expect(stored['user_id'], payload['user_id']);
    expect(stored['delivery_address'], payload['delivery_address']);
    expect(stored['items'], isA<List>());
    expect((stored['items'] as List).first['menu_id'], 'm1');
  });
}
