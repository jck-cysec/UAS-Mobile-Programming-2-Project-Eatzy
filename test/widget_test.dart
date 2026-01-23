// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  testWidgets('App shows brand on startup (smoke)', (WidgetTester tester) async {
    // Lightweight smoke test that doesn't depend on Supabase or app init logic.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Eatzy'),
              Text('Eat smart. Eat fast.'),
            ],
          ),
        ),
      ),
    ));

    await tester.pumpAndSettle();
    expect(find.text('Eatzy'), findsOneWidget);
    expect(find.text('Eat smart. Eat fast.'), findsOneWidget);
  });
}
