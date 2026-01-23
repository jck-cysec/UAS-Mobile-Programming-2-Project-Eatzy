import 'package:flutter_test/flutter_test.dart';
import 'package:eatzy_app/data/services/order_service.dart';

void main() {
  final svc = OrderService();

  test('buildOrderInsertPayload uses building_id when given UUID', () {
    final p = svc.buildOrderInsertPayload(
      userId: '11111111-1111-1111-1111-111111111111',
      deliveryType: 'delivery',
      buildingId: '22222222-2222-2222-2222-222222222222',
      paymentMethod: 'card',
      shippingFee: 3000.0,
    );

    expect(p['building_id'], '22222222-2222-2222-2222-222222222222');
    expect(p.containsKey('delivery_address'), isFalse);
  });

  test('buildOrderInsertPayload uses delivery_address when given free text', () {
    final p = svc.buildOrderInsertPayload(
      userId: '11111111-1111-1111-1111-111111111111',
      deliveryType: 'delivery',
      buildingId: 'gedung a',
      paymentMethod: 'cash',
      shippingFee: 0.0,
    );

    expect(p['delivery_address'], 'gedung a');
    expect(p.containsKey('building_id'), isFalse);
  });

  test('buildOrderInsertPayload does not include address when pickup', () {
    final p = svc.buildOrderInsertPayload(
      userId: '11111111-1111-1111-1111-111111111111',
      deliveryType: 'pickup',
      buildingId: 'gedung a',
      paymentMethod: 'cash',
      shippingFee: 0.0,
    );

    expect(p.containsKey('delivery_address'), isFalse);
    expect(p.containsKey('building_id'), isFalse);
  });

  test('sanitizeOrderPayload moves non-UUID building_id into delivery_address', () {
    final raw = {
      'user_id': '11111111-1111-1111-1111-111111111111',
      // Simulate a mistaken payload that contains free-text in building_id
      'building_id': 'gedung a',
      'delivery_type': 'delivery',
    };

    final out = svc.sanitizeOrderPayload(Map<String, dynamic>.from(raw));
    expect(out.containsKey('building_id'), isFalse);
    expect(out['delivery_address'], 'gedung a');
  });
}
