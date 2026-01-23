import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:eatzy_app/features/user/page/home_page.dart';
import 'package:eatzy_app/features/user/page/profiles/profile_page.dart';
import 'package:eatzy_app/features/user/page/menu_detail_page.dart';
import 'package:eatzy_app/data/models/menu_model.dart';
import 'package:eatzy_app/data/services/cart_service.dart';
import 'package:eatzy_app/data/services/menu_service.dart';
import 'package:eatzy_app/state/session_provider.dart';

class TestSessionProvider extends ChangeNotifier implements SessionProvider {
  String _name;
  TestSessionProvider([this._name = 'Test User']);

  @override
  String get displayName => _name;

  void updateName(String newName) {
    _name = newName;
    notifyListeners();
  }

  // Minimal no-op implementations for the rest of the interface
  @override
  User? get user => null;

  @override
  AuthStatus get status => AuthStatus.authenticated;

  @override
  String? get errorMessage => null;

  @override
  Map<String, dynamic>? get userProfile => {'full_name': _name, 'role': 'user'};

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

  // stubbed methods
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
  setUp(() {
    CartService.instance.clear();
  });

  testWidgets('ProfilePage updates when SessionProvider changes', (WidgetTester tester) async {
    final fakeSession = TestSessionProvider('Alice');

    await tester.pumpWidget(
      ChangeNotifierProvider<SessionProvider>.value(
        value: fakeSession,
        // ProfilePage expects Material ancestor (InkWell inside), provide Scaffold here
        child: const MaterialApp(home: Scaffold(body: ProfilePage())),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);

    // change name and notify
    fakeSession.updateName('Budi');
    await tester.pumpAndSettle();

    expect(find.text('Budi'), findsOneWidget);
  });

  testWidgets('HomePage updates when SessionProvider changes', (WidgetTester tester) async {
    final fakeSession = TestSessionProvider('Alice');

    // Provide a minimal menu stream so HomePage doesn't try to access Supabase
    MenuService.setTestStreamAvailableAll(() => Stream.value([]));

    await tester.pumpWidget(
      ChangeNotifierProvider<SessionProvider>.value(
        value: fakeSession,
        // HomePage expects to be inside a Scaffold in app; provide one for tests
        child: const MaterialApp(home: Scaffold(body: HomePage())),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Hey, Alice!'), findsOneWidget);

    // change name and notify
    fakeSession.updateName('Budi');
    await tester.pumpAndSettle();

    expect(find.text('Hey, Budi!'), findsOneWidget);

    MenuService.clearTestOverrides();
  });

  testWidgets('Add to cart shows UNDO and restores previous state', (WidgetTester tester) async {
    final menu = MenuModel(
      id: 'm1',
      canteenId: 'c1',
      name: 'Nasi Goreng',
      description: 'Enak',
      price: 10000,
      prepTime: 10,
      isAvailable: true,
      category: 'makanan',
      imageUrl: '',
      isDeleted: false,
    );

    // Ensure MenuService provides the menu to HomePage / detail via stream
    MenuService.setTestStreamAvailableAll(() => Stream.value([menu]));
    // Also override the admin/all menu stream used by MenuDetailPage to avoid supabase access in tests
    MenuService.setTestStreamAllMenu((_) => Stream.value([menu]));

    await tester.pumpWidget(
      MaterialApp(home: MenuDetailPage(menu: menu)),
    );

    MenuService.clearTestOverrides();

    await tester.pumpAndSettle();

    expect(CartService.instance.items.value.length, 0);

    // Tap Add to cart button
    final addText = 'Add to cart • Rp ${menu.price.toStringAsFixed(0)}';
    expect(find.text(addText), findsOneWidget);

    await tester.tap(find.text(addText));
    await tester.pump();
    // Allow the async add delay in MenuDetailPage to complete
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Item should be added
    expect(CartService.instance.items.value.length, 1);

    // SnackBar with UNDO should be present
    expect(find.text('Ditambahkan ke keranjang'), findsOneWidget);
    expect(find.text('UNDO'), findsOneWidget);

    // Tap UNDO
    // Wait for SnackBar to appear and settle, then tap UNDO
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('UNDO'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Cart should be restored (empty)
    expect(CartService.instance.items.value.length, 0);
  });
}
