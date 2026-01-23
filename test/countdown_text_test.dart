import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatzy_app/widgets/countdown_text.dart';

void main() {
  testWidgets('CountdownText counts down and becomes "Siap"', (WidgetTester tester) async {
    DateTime fakeNow = DateTime.now();
    DateTime nowProvider() => fakeNow;

    final target = fakeNow.add(const Duration(seconds: 3));

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CountdownText(target: target, nowProvider: nowProvider))));

    // initial state should show some seconds
    expect(find.textContaining('detik'), findsOneWidget);

    // advance 2 seconds by moving fakeNow then pumping timers
    fakeNow = fakeNow.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // still should show seconds or small time
    expect(find.textContaining('detik').evaluate().isNotEmpty, true);

    // advance to past target
    fakeNow = fakeNow.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Siap'), findsOneWidget);
  });
}
