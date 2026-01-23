import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_model.dart';

class MenuService {
  static final MenuService instance = MenuService._();

  // Initialization retry control: if Supabase isn't initialized when this
  // singleton is constructed (common in tests / early app startup), we
  // attempt a few delayed retries to initialize the admin cache.
  int _initAttempts = 0;
  static const int _maxInitAttempts = 6;

  // Optional test overrides to avoid relying on an initialized Supabase in unit tests
  static Stream<List<MenuModel>> Function(String canteenId)? _testStreamAllMenu;
  static Stream<List<MenuModel>> Function()? _testStreamAvailableAll;

  static void setTestStreamAllMenu(Stream<List<MenuModel>> Function(String canteenId)? fn) {
    _testStreamAllMenu = fn;
  }

  static void setTestStreamAvailableAll(Stream<List<MenuModel>> Function()? fn) {
    _testStreamAvailableAll = fn;
  }

  static void clearTestOverrides() {
    _testStreamAllMenu = null;
    _testStreamAvailableAll = null;
  }

  SupabaseClient get _client => Supabase.instance.client;

  /// In-memory list (ADMIN)
  final ValueNotifier<List<MenuModel>> menus = ValueNotifier<List<MenuModel>>([]);

  /// Whether initial load is in progress
  final ValueNotifier<bool> loading = ValueNotifier<bool>(true);

  MenuService._() {
    _init();
  }

  void _init() {
    // fetch current menus once so admin sees existing rows
    Future.microtask(() async {
      SupabaseClient? client;
      try {
        client = Supabase.instance.client;
        // reset attempts on success
        _initAttempts = 0;
      } catch (e, st) {
        if (kDebugMode) print('MenuService._init: supabase not initialized yet: $e\n$st');

        // Retry a few times with a short delay to allow Supabase to finish
        // initialization during app startup. This avoids missing menus when
        // the singleton is constructed early.
        _initAttempts += 1;
        if (_initAttempts <= _maxInitAttempts) {
          // Use microtask to avoid creating timers during tests which would
          // leak pending timers in the FakeAsync environment.
          Future.microtask(_init);
          return;
        }

        loading.value = false;
        return;
      }

      try {
        // Fetch admin menus (exclude soft-deleted) so admin sees all active menus across canteens
        final resp = await client.from('food_menu').select().eq('is_deleted', false).order('name');
        final list = _mapRows(resp).where((m) => !m.isDeleted).toList();
        menus.value = list;

        // subscribe to realtime updates to keep admin list in sync (exclude deleted rows)
        client
            .from('food_menu')
            .stream(primaryKey: ['id'])
            .order('name')
            .listen((event) {
          // ensure admin list excludes soft-deleted rows and is not filtered by canteen_id
          final list = _mapRows(event).where((m) => !m.isDeleted).toList();
          menus.value = list;
        });
      } catch (e, st) {
        if (kDebugMode) print('MenuService._init: fetch error: $e\n$st');
      } finally {
        loading.value = false;
      }
    });
  }

  // Safely parse rows returned from Supabase (skip rows that fail parsing)
  List<MenuModel> _mapRows(dynamic rows) {
    final out = <MenuModel>[];
    if (rows is List) {
      for (final e in rows) {
        try {
          out.add(MenuModel.fromMap(Map<String, dynamic>.from(e as Map)));
        } catch (err, st) {
          if (kDebugMode) print('MenuService: failed to parse menu row: $err\n$st');
        }
      }
    }
    return out;
  }

  /* =========================
   * ADMIN - ALL MENU (REALTIME)
   * Returns active menus across ALL canteens (admin view).
   * Note: the `canteenId` parameter is kept for backward compatibility but is ignored here
   *       because admin must not be filtered by canteen_id.
   * ========================= */
  Stream<List<MenuModel>> streamAllMenu(String canteenId) {
    // Test override (returns mocked stream when running unit tests)
    if (_testStreamAllMenu != null) return _testStreamAllMenu!(canteenId).map((l) => l.where((m) => !m.isDeleted).toList());

    try {
      final client = Supabase.instance.client;
      return client
          .from('food_menu')
          .stream(primaryKey: ['id'])
          .order('name')
          .map((event) => _mapRows(event).where((m) => !m.isDeleted).toList());
    } catch (e, st) {
      if (kDebugMode) print('MenuService.streamAllMenu: supabase not ready: $e\n$st');
      return Stream.value([]);
    }
  }

  /* =========================
   * USER - AVAILABLE MENU
   * ========================= */
  Stream<List<MenuModel>> streamAvailableMenu(String canteenId) {
    try {
      final client = Supabase.instance.client;
      return client
          .from('food_menu')
          .stream(primaryKey: ['id'])
          .order('name')
          .map((event) => _mapRows(event).where((m) => m.canteenId == canteenId && m.isAvailable && !m.isDeleted).toList());
    } catch (e, st) {
      if (kDebugMode) print('MenuService.streamAvailableMenu: supabase not ready: $e\n$st');
      return Stream.value([]);
    }
  }

  /// Stream all available menu across canteens (useful for user MVP)
  Stream<List<MenuModel>> streamAvailableAll() {
    // Test override (returns mocked stream when running unit tests)
    if (_testStreamAvailableAll != null) return _testStreamAvailableAll!();

    try {
      final client = Supabase.instance.client;
      return client
          .from('food_menu')
          .stream(primaryKey: ['id'])
          .order('name')
          .map((event) => _mapRows(event).where((m) => m.isAvailable && !m.isDeleted).toList());
    } catch (e, st) {
      if (kDebugMode) print('MenuService.streamAvailableAll: supabase not ready: $e\n$st');
      return Stream.value([]);
    }
  }

  /* =========================
   * CREATE MENU
   * ========================= */
  Future<void> createMenu(Map<String, dynamic> payload) async {
    // Ensure soft-delete flag is explicitly set when creating new rows
    final toInsert = Map<String, dynamic>.from(payload);
    toInsert['is_deleted'] = toInsert['is_deleted'] ?? false;

    final res = await _client.from('food_menu').insert(toInsert).select().maybeSingle();
    if (res == null) return;

    try {
      Map<String, dynamic>? row;
      // prefer direct Map.from(res) (PostgrestMap is Map-like)
      try {
        row = Map<String, dynamic>.from(res as Map);
      } catch (_) {
        // fallback: data may be wrapped in a list or under a 'data' key
        if (res is List && res.isNotEmpty) {
          row = Map<String, dynamic>.from((res as List).first as Map);
        } else if (res['data'] is List && (res['data'] as List).isNotEmpty) {
          row = Map<String, dynamic>.from((res['data'] as List).first as Map);
        }
      }

      if (row == null) return;

      final m = MenuModel.fromMap(row);
      menus.value = [...menus.value, m];
    } catch (err, st) {
      if (kDebugMode) print('MenuService.createMenu parse error: $err\n$st');
    }
  }

  /// Fetch single menu by id (latest from server)
  Future<MenuModel?> fetchMenuById(String id) async {
    try {
      final res = await _client.from('food_menu').select().eq('id', id).maybeSingle();
      if (res == null) return null;

      // Try casting to Map (common PostgrestMap)
      try {
        return MenuModel.fromMap(Map<String, dynamic>.from(res as Map));
      } catch (_) {
        // fallback: response might be a list or wrapped under 'data'
        try {
          if (res is List && res.isNotEmpty) {
            final first = (res as List).first;
            if (first is Map) return MenuModel.fromMap(Map<String, dynamic>.from(first));
          }
        } catch (_) {}

        try {
          final data = (res as Map)['data'];
          if (data is List && data.isNotEmpty) {
            final first = data.first;
            if (first is Map) return MenuModel.fromMap(Map<String, dynamic>.from(first));
          }
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) print('fetchMenuById error: $e');
    }
    return null;
  }

  /* =========================
   * UPDATE MENU
   * ========================= */
  Future<void> updateMenu(String id, Map<String, dynamic> payload) async {
    final res = await _client.from('food_menu').update(payload).eq('id', id).select().maybeSingle();
    if (res == null) return;

    try {
      Map<String, dynamic>? row;
      try {
        row = Map<String, dynamic>.from(res as Map);
      } catch (_) {
        if (res is List && res.isNotEmpty) {
          row = Map<String, dynamic>.from((res as List).first as Map);
        } else if (res['data'] is List && (res['data'] as List).isNotEmpty) {
          row = Map<String, dynamic>.from((res['data'] as List).first as Map);
        }
      }

      if (row == null) return;

      final updated = MenuModel.fromMap(row);
      menus.value = menus.value.map((m) => m.id == id ? updated : m).toList();
    } catch (err, st) {
      if (kDebugMode) print('MenuService.updateMenu parse error: $err\n$st');
    }
  }

  /* =========================
   * DELETE MENU
   * ========================= */
  Future<void> deleteMenu(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    // Soft delete: mark row as deleted and make unavailable so foreign keys and order history remain valid
    final res = await _client.from('food_menu').update({'is_deleted': true, 'deleted_at': now, 'is_available': false}).eq('id', id).select().maybeSingle();

    // Update local cache: keep the menu visible for admin and reflect its updated state
    try {
      if (res == null) return;
      final row = Map<String, dynamic>.from(res as Map);
      final updated = MenuModel.fromMap(row);
      menus.value = menus.value.map((m) => m.id == id ? updated : m).toList();
    } catch (err, st) {
      if (kDebugMode) print('MenuService.deleteMenu parse error: $err\n$st');
      // Fallback: leave existing list as-is
    }
  }

  /* =========================
   * TOGGLE AVAILABILITY
   * ========================= */
  Future<void> updateAvailability(String id, bool value) async {
    final res = await _client.from('food_menu').update({'is_available': value}).eq('id', id).select().maybeSingle();
    if (res == null) return;

    try {
      Map<String, dynamic>? row;
      try {
        row = Map<String, dynamic>.from(res as Map);
      } catch (_) {
        if (res is List && res.isNotEmpty) {
          row = Map<String, dynamic>.from((res as List).first as Map);
        } else if (res['data'] is List && (res['data'] as List).isNotEmpty) {
          row = Map<String, dynamic>.from((res['data'] as List).first as Map);
        }
      }

      if (row == null) return;

      final updated = MenuModel.fromMap(row);
      menus.value = menus.value.map((m) => m.id == id ? updated : m).toList();
    } catch (err, st) {
      if (kDebugMode) print('MenuService.updateAvailability parse error: $err\n$st');
    }
  }
}

