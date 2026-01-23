import 'package:flutter_test/flutter_test.dart';
import 'package:eatzy_app/data/services/order_service.dart';

void main() {
  final svc = OrderService();

  const testUserUuid = '11111111-1111-1111-1111-111111111111';

  test('createOrder rejects empty items', () async {
    final res = await svc.createOrder(userId: testUserUuid, items: [], deliveryType: 'pickup');
    expect(res, isNull);
  });

  test('createOrder rejects delivery without address', () async {
    final items = [ {'menu_id': 'm1', 'qty': 1} ];
    final res = await svc.createOrder(userId: testUserUuid, items: items, deliveryType: 'delivery');
    expect(res, isNull);
  });
}
