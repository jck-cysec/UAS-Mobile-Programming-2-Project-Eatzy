import 'package:flutter_test/flutter_test.dart';
import 'package:eatzy_app/data/services/order_service.dart';
import 'package:eatzy_app/data/models/menu_model.dart';

void main() {
  test('computeMaxPrepFromItems uses highest prepTime', () async {
    final service = OrderService();

    Future<MenuModel?> fakeFetch(String id) async {
      if (id == 'm1') return MenuModel(id: 'm1', canteenId: 'c1', name: 'A', description: '', price: 1000, prepTime: 5, isAvailable: true, category: 'x', imageUrl: '', isDeleted: false);
      if (id == 'm2') return MenuModel(id: 'm2', canteenId: 'c1', name: 'B', description: '', price: 1000, prepTime: 20, isAvailable: true, category: 'x', imageUrl: '', isDeleted: false);
      return null;
    }

    final items = [
      {'menu_id': 'm1'},
      {'menu_id': 'm2'},
    ];

    final maxPrep = await service.computeMaxPrepFromItems(items, fetchMenuById: fakeFetch);
    expect(maxPrep, 20);
  });

  test('computeMaxPrepFromItems falls back to 10 when no prep info', () async {
    final service = OrderService();

    Future<MenuModel?> fakeFetch(String id) async => null;

    final items = [
      {'menu_id': 'mX'},
    ];

    final maxPrep = await service.computeMaxPrepFromItems(items, fetchMenuById: fakeFetch);
    expect(maxPrep, 10);
  });
}
