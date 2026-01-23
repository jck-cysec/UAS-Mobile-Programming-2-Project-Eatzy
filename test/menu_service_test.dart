import 'package:flutter_test/flutter_test.dart';
import 'package:eatzy_app/data/models/menu_model.dart';
import 'package:eatzy_app/data/services/menu_service.dart';

void main() {
  setUp(() {
    // ensure test overrides are cleared before each test
    MenuService.clearTestOverrides();
  });

  test('Admin stream ignores canteenId and excludes soft-deleted menus', () async {
    final menuA = MenuModel(
      id: 'a',
      canteenId: 'canteen-x',
      name: 'Nasi Goreng',
      description: '',
      price: 15000,
      prepTime: 10,
      isAvailable: true,
      category: 'makanan',
      imageUrl: '',
      isDeleted: false,
    );

    final menuB = MenuModel(
      id: 'b',
      canteenId: '', // legacy row without canteen
      name: 'Teh Manis',
      description: '',
      price: 5000,
      prepTime: 2,
      isAvailable: true,
      category: 'minuman',
      imageUrl: '',
      isDeleted: false,
    );

    final menuDeleted = MenuModel(
      id: 'c',
      canteenId: 'canteen-x',
      name: 'Old Menu',
      description: '',
      price: 10000,
      prepTime: 5,
      isAvailable: false,
      category: 'makanan',
      imageUrl: '',
      isDeleted: true,
      deletedAt: DateTime.now(),
    );

    // Provide a fake stream for tests
    MenuService.setTestStreamAllMenu((_) => Stream.value([menuA, menuB, menuDeleted]));

    final result = await MenuService.instance.streamAllMenu('some-canteen').first;

    // Admin should see both menuA and menuB regardless of canteenId, but not the deleted menu
    expect(result.map((m) => m.id).toSet(), equals({'a', 'b'}));
  });
}
