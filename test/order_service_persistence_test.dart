import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eatzy_app/data/services/order_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persistPendingDeliveryAddress stores address in SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final svc = OrderService();
    await svc.persistPendingDeliveryAddress('order-123', 'Gedung A blok 3');
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('pending_delivery_address_order-123');
    expect(stored, 'Gedung A blok 3');
  });
}
