import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:eatzy_app/features/user/user_shell_page.dart';
import 'package:eatzy_app/features/splash/splash_page.dart';
import 'package:eatzy_app/state/session_provider.dart';
import 'package:eatzy_app/data/services/menu_service.dart';

class FakeSessionProvider extends ChangeNotifier implements SessionProvider {
  // Minimal stubbed implementation for tests
  @override
  User? get user => null;

  @override
  AuthStatus get status => AuthStatus.authenticated;

  @override
  String? get errorMessage => null;

  @override
  Map<String, dynamic>? get userProfile => {'full_name': 'Test User', 'role': 'user'};

  @override
  bool get isLoggedIn => true;

  @override
  bool get isLoading => false;

  @override
  bool get hasError => false;

  @override
  bool get isProfileLoaded => true;

  @override
  String get role => 'user';

  @override
  bool get isAdmin => false;

  @override
  bool get isUser => true;

  @override
  String get displayName => 'Test User';

  // No-op implementations for methods used in app flows
  @override
  Future<void> ensureProfileLoaded() async {}

  @override
  Future<bool> validateSession() async => true;

  @override
  Future<bool> refreshSession() async => true;

  @override
  Future<bool> logout(BuildContext context) async => true;

  @override
  // ignore: unnecessary_overrides
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('UserShellPage shows app bar and bottom navigation', (WidgetTester tester) async {
    // Provide a minimal menu stream so widgets that subscribe to menus don't rely on Supabase
    MenuService.setTestStreamAvailableAll(() => Stream.value([]));
    // Also override admin/all menu stream used by some pages to avoid supabase access in tests
    MenuService.setTestStreamAllMenu((_) => Stream.value([]));
    final fakeSession = FakeSessionProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<SessionProvider>.value(
        value: fakeSession,
        child: const MaterialApp(
          home: UserShellPage(),
        ),
      ),
    );

    // Let animations settle
    await tester.pumpAndSettle();

    // App bar should contain the app title (Eatzy)
    expect(find.text('Eatzy'), findsOneWidget);

    // Bottom nav labels
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Cart'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    MenuService.clearTestOverrides();

    // Bottom nav icons: there may be duplicates due to internal icon widgets, so check at least one exists
    expect(find.byIcon(Icons.home_rounded), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.shopping_cart_rounded), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.person_rounded), findsAtLeastNWidgets(1));
  });

  testWidgets('Splash navigates to UserShellPage when logged-in', (WidgetTester tester) async {
    final fakeSession = FakeSessionProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<SessionProvider>.value(
        value: fakeSession,
        child: const MaterialApp(
          home: SplashPage(),
        ),
      ),
    );

    // Allow splash delay and animations
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // After navigation finished, UserShellPage should be present
    expect(find.byType(UserShellPage), findsOneWidget);
    expect(find.text('Eatzy'), findsOneWidget);
  });
}
