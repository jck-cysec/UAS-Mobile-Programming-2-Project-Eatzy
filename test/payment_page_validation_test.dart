import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:eatzy_app/features/user/page/payment_page.dart';
import 'package:eatzy_app/data/models/order_item_model.dart';
import 'package:eatzy_app/state/session_provider.dart';

void main() {
  testWidgets('PaymentPage requires delivery address when delivery selected', (tester) async {
    final items = [
      OrderItemModel(menuId: 'm1', name: 'Test Food', qty: 1, price: 10000),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider<SessionProvider>.value(
        value: SessionProvider.test(profile: {'id': '11111111-1111-1111-1111-111111111111', 'full_name': 'Test User'}, loggedIn: true),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 800, height: 1200, child: PaymentPage(items: items, total: 10000.0)),
          ),
        ),
      ),
    );

    // Tap the 'Diantar' delivery option
    expect(find.text('Diantar'), findsOneWidget);
    await tester.tap(find.text('Diantar'));
    await tester.pumpAndSettle();

    // Ensure the location field is visible (but leave it empty)
    expect(find.text('Lokasi Pengiriman'), findsOneWidget);

    // Tap the pay button
    expect(find.text('Bayar Sekarang'), findsOneWidget);
    // Ensure the button is visible then tap
    await tester.ensureVisible(find.text('Bayar Sekarang'));
    await tester.tap(find.text('Bayar Sekarang'));
    await tester.pumpAndSettle();

    // SnackBar with validation message should appear
    expect(find.text('Masukkan alamat pengiriman sebelum melanjutkan pembayaran'), findsOneWidget);
  });
}
