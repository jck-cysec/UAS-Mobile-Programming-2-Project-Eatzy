import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatzy_app/data/models/order_model.dart';
import 'package:eatzy_app/data/services/order_service.dart';
import 'package:eatzy_app/features/admin/pages/admin_orders_page.dart';

// Minimal fake OrderService for widget testing
class FakeOrderService extends OrderService {
  final StreamController<List<OrderModel>> _ordersCtrl = StreamController.broadcast();
  final Map<String, StreamController<OrderModel?>> _single = {};
  Future<OrderModel?> Function(String id) fetchFn;

  FakeOrderService({required this.fetchFn});

  void addList(List<OrderModel> list) => _ordersCtrl.add(list);

  void addSingle(String id, OrderModel? o) {
    _single.putIfAbsent(id, () => StreamController<OrderModel?>.broadcast());
    _single[id]!.add(o);
  }

  @override
  Stream<List<OrderModel>> streamOrders() => _ordersCtrl.stream;

  @override
  Stream<OrderModel?> streamOrderById(String orderId) {
    _single.putIfAbsent(orderId, () => StreamController<OrderModel?>.broadcast());
    return _single[orderId]!.stream;
  }

  @override
  Future<OrderModel?> fetchOrderById(String id) => fetchFn(id);

  void dispose() {
    _ordersCtrl.close();
    for (final c in _single.values) {
      c.close();
    }
  }
}

void main() {
  testWidgets('admin orders page falls back to fetchOrderById when stream lacks user/payment', (tester) async {
    // Incomplete stream row (no users, no payment_method)
    final incompleteMap = {
      'id': 'o1abcdefgh',
      'user_id': 'u1',
      'status': 'pending',
      'delivery_type': 'delivery',
      'order_time': DateTime.now().toIso8601String(),
      'order_items': [],
      // no users and no payment_method
      'total_price': 20000,
      'delivery_tip': 3000,
    };

    // Enriched full row returned by fetchOrderById
    final enrichedMap = {
      'id': 'o1abcdefgh',
      'user_id': 'u1',
      'status': 'pending',
      'delivery_type': 'delivery',
      'order_time': DateTime.now().toIso8601String(),
      'order_items': [
        {
          'food': {'id': 'm1', 'name': 'Nasi Goreng', 'price': 17000, 'image_url': ''},
          'quantity': 1,
        }
      ],
      'users': {'full_name': 'Alice Admin'},
      'payment_method': 'Cash',
      'total_price': 20000,
      'delivery_tip': 3000,
    };

    final fake = FakeOrderService(fetchFn: (id) async {
      // Accept either the short prefix or the full test id to be robust
      if (id == 'o1abcdefgh' || id.startsWith('o1')) return OrderModel.fromMap(enrichedMap);
      return null;
    });

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 400, height: 1200, child: AdminOrdersPage(orderService: fake)))));

    // Now emit stream events after subscription so broadcast stream delivers to listeners
    fake.addList([OrderModel.fromMap(incompleteMap)]);
    // Use the full id that the UI will request
    fake.addSingle('o1abcdefgh', OrderModel.fromMap(incompleteMap));

    // Allow stream and initial builds and let FutureBuilder complete (use polling to avoid pumpAndSettle timeouts)
    await tester.pump();

    bool found = false;
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Alice Admin').evaluate().isNotEmpty && find.text('Cash').evaluate().isNotEmpty) {
        found = true;
        break;
      }
    }

    if (!found) {
      // Debug: list all Text widgets present
      final texts = find.byType(Text);
      final buf = StringBuffer();
      for (final e in texts.evaluate()) {
        final widget = e.widget as Text;
        buf.writeln(widget.data);
      }
      print('DEBUG: Text widgets in tree:\n${buf.toString()}');
    }

    expect(found, isTrue, reason: 'Expected enriched name and payment to appear after fallback fetch');

    fake.dispose();
  });
}
