import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/data/models/order_model.dart';


/// Centralized lightweight API layer for order & user related REST calls
/// Uses Supabase REST client underneath. This file intentionally keeps logic
/// limited to HTTP/retry/persistence concerns and does not re-implement
/// business logic from `OrderService` or `MenuService`.
class Api {
  final SupabaseClient _client;

  Api({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  static final Api instance = Api();

  /// Create an order using the provided payload.
  ///
  /// Returns the created `orderId` string on success, or `null` on failure.
  /// Retries on transient failures and attempts a stripped retry if the server
  /// does not recognize `delivery_address` (PGRST204). If all retries fail,
  /// the payload is persisted locally (SharedPreferences) under
  /// `pending_order_<iso-ts>-<random>` for later replay.
  Future<String?> createOrder(Map<String, dynamic> payload) async {
    const int maxAttempts = 3;
    int attempt = 0;
    int delayMs = 200;

    // Defensive copy - we'll mutate locally for retries
    Map<String, dynamic> attemptPayload = Map<String, dynamic>.from(payload);

    while (attempt < maxAttempts) {
      try {
        final res = await _client
            .from('orders')
            .insert(attemptPayload)
            .select('id')
            .single();

        final String id = res['id']?.toString() ?? '';
        if (id.isNotEmpty) return id;
      } on PostgrestException catch (e) {
        if (kDebugMode) debugPrint('Api.createOrder PostgrestException (attempt ${attempt + 1}): $e');

        final msg = (e.message ?? '').toString();
        // If server complains about unknown delivery_address column, retry without address
        if (e.code == 'PGRST204' || msg.contains("Could not find the 'delivery_address'") || msg.contains('Could not find')) {
          final attemptedAddress = attemptPayload['delivery_address'] ?? attemptPayload['building_id'];
          final stripped = Map<String, dynamic>.from(attemptPayload);
          stripped.remove('delivery_address');
          stripped.remove('building_id');

          try {
            final res2 = await _client.from('orders').insert(stripped).select('id').single();
            final String id2 = res2['id']?.toString() ?? '';
            if (id2.isNotEmpty) {
              // persist intended address for later repair (non-blocking)
              if (attemptedAddress != null) {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('pending_delivery_address_$id2', attemptedAddress.toString());
                  if (kDebugMode) debugPrint('Api.createOrder: persisted pending_delivery_address for $id2');
                } catch (ePrefs) {
                  if (kDebugMode) debugPrint('Api.createOrder: failed to persist pending address: $ePrefs');
                }
              }

              return id2;
            }
          } catch (e2) {
            if (kDebugMode) debugPrint('Api.createOrder retry stripped failed: $e2');
            // fallthrough to retry/backoff
          }
        }

        // Non-handled Postgrest error -> proceed to retry/backoff or persist
        attempt += 1;
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: delayMs));
          delayMs *= 2;
          continue;
        }

        // persist pending order for operator replay
        try {
          await _persistPendingOrder(attemptPayload);
          if (kDebugMode) debugPrint('Api.createOrder: persisted pending order after failures');
        } catch (ePersist) {
          if (kDebugMode) debugPrint('Api.createOrder: failed to persist pending order: $ePersist');
        }

        return null;
      } catch (e) {
        if (kDebugMode) debugPrint('Api.createOrder unexpected error (attempt ${attempt + 1}): $e');
        attempt += 1;
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: delayMs));
          delayMs *= 2;
          continue;
        }

        try {
          await _persistPendingOrder(attemptPayload);
          if (kDebugMode) debugPrint('Api.createOrder: persisted pending order after unexpected errors');
        } catch (ePersist) {
          if (kDebugMode) debugPrint('Api.createOrder: failed to persist pending order: $ePersist');
        }

        return null;
      }
    }

    return null;
  }

  /// Get orders for a specific user.
  ///
  /// Returns a list of `OrderModel`. On errors, returns an empty list.
  Future<List<OrderModel>> getUserOrders(String userId) async {
    try {
      final res = await _client
          .from('orders')
          .select('*, order_items(*, food:food_menu(*)), users(*)')
          .eq('user_id', userId)
          .order('order_time', ascending: false);

      return _parseOrderList(res);
          return [];
    } catch (e) {
      if (kDebugMode) debugPrint('Api.getUserOrders error: $e');
      return [];
    }
  }

  /// Cancel an order by setting status to `cancelled`.
  ///
  /// Returns true if update succeeded, otherwise false.
  Future<bool> cancelOrder(String orderId) async {
    try {
      await _client.from('orders').update({'status': 'cancelled'}).eq('id', orderId);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Api.cancelOrder error: $e');
      return false;
    }
  }

  /// Try to recover a recently created order for a user by matching approx items.
  ///
  /// `approxItems` should be a list of maps containing `menu_id` keys.
  /// Returns `orderId` if found, otherwise `null`.
  Future<String?> recoverRecentOrder(String userId, List<Map<String, dynamic>> approxItems, {int withinSeconds = 30, String? approxDeliveryAddress}) async {
    try {
      final cutoff = DateTime.now().toUtc().subtract(Duration(seconds: withinSeconds)).toIso8601String();
      final res = await _client
          .from('orders')
          .select('id, delivery_address, building_id, order_items(food_id, quantity)')
          .eq('user_id', userId)
          .gte('order_time', cutoff)
          .order('order_time', ascending: false)
          .limit(10);
      final candidates = (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final required = approxItems.map((i) => i['menu_id']?.toString()).whereType<String>().toList();

      String? fallbackId;
      for (final c in candidates) {
        final items = (c['order_items'] as List?) ?? [];
        if (items.isEmpty) continue;

        final foods = items.map((i) => i['food_id']?.toString()).whereType<String>().toList();
        final intersects = required.any((r) => foods.contains(r));
        if (!intersects) continue;

        if (approxDeliveryAddress != null && approxDeliveryAddress.isNotEmpty) {
          final addr = (c['delivery_address'] ?? c['building_id'])?.toString().toLowerCase() ?? '';
          if (addr.isNotEmpty && addr.contains(approxDeliveryAddress.toLowerCase())) {
            return c['id']?.toString();
          }
        }

        fallbackId ??= c['id']?.toString();
      }

      return fallbackId;
    } catch (e) {
      if (kDebugMode) debugPrint('Api.recoverRecentOrder error: $e');
      return null;
    }
  }

  /// Get all orders (admin view). Returns a list of `OrderModel`.
  Future<List<OrderModel>> getAdminOrders() async {
    try {
      final res = await _client.from('orders').select('*, order_items(*, food:food_menu(*)), users(*)').order('order_time', ascending: false);
      return _parseOrderList(res);
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('Api.getAdminOrders error: $e');
      return [];
    }
  }

  /// Update order status. Returns true on success, false otherwise.
  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      await _client.from('orders').update({'status': status}).eq('id', orderId);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Api.updateOrderStatus error: $e');
      return false;
    }
  }

  // ---------------------- Helpers ----------------------

  List<OrderModel> _parseOrderList(List<dynamic> raw) {
    final out = <OrderModel>[];
    for (final r in raw) {
      try {
        final row = Map<String, dynamic>.from(r as Map);
        out.add(OrderModel.fromMap(row));
      } catch (e) {
        if (kDebugMode) debugPrint('Api._parseOrderList: failed parsing row: $e');
      }
    }
    return out;
  }

  Future<void> _persistPendingOrder(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final id = '${DateTime.now().toUtc().toIso8601String()}-${UniqueKey()}';
    final key = 'pending_order_$id';
    try {
      await prefs.setString(key, jsonEncode(payload));
    } catch (e) {
      if (kDebugMode) debugPrint('Api._persistPendingOrder error: $e');
      rethrow;
    }
  }

  /// For diagnostics: list locally persisted pending orders (non-destructive).
  Future<List<Map<String, dynamic>>> listPendingOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('pending_order_')).toList();
    final out = <Map<String, dynamic>>[];
    for (final k in keys) {
      final v = prefs.getString(k);
      if (v == null) continue;
      try {
        out.add(Map<String, dynamic>.from(jsonDecode(v) as Map));
      } catch (_) {}
    }
    return out;
  }

  /// Replay persisted pending orders. Best-effort: successful replays remove the pending key.
  ///
  /// NOTE: This will attempt to insert whatever was stored; operator should ensure schema
  /// is ready (e.g., `delivery_address` column available) before running.
  Future<void> replayPendingOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('pending_order_')).toList();
    for (final k in keys) {
      final v = prefs.getString(k);
      if (v == null) continue;
      try {
        final payload = Map<String, dynamic>.from(jsonDecode(v) as Map);
        try {
          final res = await _client.from('orders').insert(payload).select('id').single();
          if (res['id'] != null) {
            await prefs.remove(k);
            if (kDebugMode) debugPrint('Api.replayPendingOrders: replayed and removed $k');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('Api.replayPendingOrders: failed to replay $k: $e');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Api.replayPendingOrders: corrupt pending entry $k: $e');
        await prefs.remove(k);
      }
    }
  }

  // TODO: If you need to include MenuModel-based helpers (eg fetching menu details
  //       to validate items), add a light wrapper here. Keep order business
  //       logic inside OrderService to avoid duplication.
}
