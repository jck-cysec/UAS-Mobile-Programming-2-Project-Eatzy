import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/order_model.dart';
import '../models/menu_model.dart';

class OrderService {
  final SupabaseClient? _clientOverride;

  // Cache whether the optional `profiles` table exists (null = unknown)
  static bool? _profilesAvailable;

  OrderService({SupabaseClient? client}) : _clientOverride = client;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  // ======================================================
  // STREAM ORDERS (ADMIN)
  // ======================================================
  Stream<List<OrderModel>> streamOrders() {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('order_time', ascending: false)
        .asyncMap((data) async {
      final list = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final processed = await Future.wait(list.map((row) async {
        // If the realtime row lacks nested items (or user), try a full fetch for accuracy
        final itemsRaw = (row['order_items'] as List?) ?? [];
        final hasUser = (row['users'] is Map);
        if (itemsRaw.isEmpty || !hasUser) {
          try {
            final full = await fetchOrderById(row['id']?.toString() ?? '');
            if (full != null) return full;
          } catch (_) {}
        }

        row['items'] = itemsRaw.map((oi) {
          final food = (oi as Map)['food'] as Map<String, dynamic>?;
          return {
            'menu_id': oi['food_id']?.toString(),
            'name': food != null ? (food['name'] ?? '') : '',
            'qty': oi['quantity'],
            'price': food != null ? (food['price'] ?? 0) : 0,
            'image_url': food != null ? (food['image_url'] ?? '') : '',
          };
        }).toList();

        // compute subtotal and total if missing
        try {
          double computedSubtotal = 0.0;
          for (final it in (row['items'] as List)) {
            final qty = (it['qty'] is int) ? it['qty'] : int.tryParse(it['qty']?.toString() ?? '0') ?? 0;
            final price = (it['price'] is num) ? (it['price'] as num).toDouble() : double.tryParse(it['price']?.toString() ?? '0') ?? 0.0;
            computedSubtotal += price * qty;
          }
          final dt = row['delivery_tip'] ?? row['deliveryTip'] ?? row['delivery_fee'] ?? row['deliveryFee'];
          final parsedDeliveryTip = (dt is num) ? dt.toDouble() : double.tryParse(dt?.toString() ?? '0') ?? 0.0;
          final serverTotal = row['total_price'] ?? row['total'];
          if (serverTotal == null) {
            row['subtotal'] = computedSubtotal;
            row['delivery_tip'] = parsedDeliveryTip;
            row['total_price'] = computedSubtotal + parsedDeliveryTip;
          } else {
            row['subtotal'] = computedSubtotal;
            row['delivery_tip'] = parsedDeliveryTip;
            try { if (serverTotal is num) row['total_price'] = serverTotal.toDouble(); } catch (_) {}
          }
        } catch (e) {
          if (kDebugMode) print('streamOrders compute totals error: $e');
        }

        return OrderModel.fromMap(row);
      }).toList());

      return processed.where((o) => !o.isDeleted).toList();
    });
  }

  /// Stream aggregated dashboard stats computed from orders stream.
  Stream<Map<String, dynamic>> streamDashboardStats() {
    return streamOrders().map((orders) {
      final total = orders.length;
      final pending = orders.where((o) => o.status == 'pending').length;
      final completed = orders.where((o) => o.status == 'completed').length;

      final Map<String, int> daily = {};
      for (final o in orders) {
        final day = '${o.orderTime.year}-${o.orderTime.month.toString().padLeft(2, '0')}-${o.orderTime.day.toString().padLeft(2, '0')}';
        daily[day] = (daily[day] ?? 0) + 1;
      }

      return {
        'total': total,
        'pending': pending,
        'completed': completed,
        'daily': daily,
      };
    });
  }

  // ======================================================
  // STREAM ORDERS (USER)
  // ======================================================
  Stream<List<OrderModel>> streamUserOrders(String userId) {
    return streamOrders()
        .map((orders) => orders.where((o) => o.userId == userId).toList());
  }

  // ======================================================
  // UPDATE STATUS (ADMIN)
  // ======================================================
  Future<bool> updateOrderStatus({
    required String id,
    required String status,
  }) async {
    try {
      await _client
          .from('orders')
          .update({'status': status})
          .eq('id', id);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('updateOrderStatus error: $e');
      }
      return false;
    }
  }

  // ======================================================
  // CREATE ORDER (FIXED VERSION – NO NESTED INSERT)
  // ======================================================
  /// Visible-for-testing helper: build the payload that will be used to insert
  /// into `orders`. This allows unit tests to assert correct fields for pickup vs delivery.
  @visibleForTesting
  Map<String, dynamic> buildOrderInsertPayload({
    required String userId,
    required String deliveryType,
    String? buildingId,
    String? paymentMethod,
    double? shippingFee,
    double? subtotal,
    double? totalPrice,
  }) {
    // Only include address/building_id for delivery orders.
    final normalizedShippingFee = (deliveryType == 'delivery') ? (shippingFee ?? 0.0) : 0.0;
    final normalizedPayment = paymentMethod ?? '';

    final Map<String, dynamic> payload = {
      'user_id': userId,
      'delivery_type': deliveryType,
      'delivery_tip': normalizedShippingFee,
      'payment_method': normalizedPayment,
    };

    // Include computed price fields if available to help server-side reporting
    if (subtotal != null) payload['subtotal'] = subtotal;
    if (totalPrice != null) payload['total_price'] = totalPrice;

    if (deliveryType == 'delivery' && buildingId != null && buildingId.trim().isNotEmpty) {
      final b = buildingId.trim();
      final uuidRe = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      if (uuidRe.hasMatch(b)) {
        payload['building_id'] = b;
      } else {
        // treat as free-text delivery address
        payload['delivery_address'] = b;
      }
    }

    return payload;
  }

  /// Sanitize an order payload to ensure no free-text is sent into UUID columns.
  /// Visible-for-testing so unit tests can assert behavior when payloads are mutated elsewhere.
  @visibleForTesting
  Map<String, dynamic> sanitizeOrderPayload(Map<String, dynamic> payload) {
    final uuidReLocal = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (payload.containsKey('building_id')) {
      final bval = payload['building_id']?.toString() ?? '';
      if (!uuidReLocal.hasMatch(bval)) {
        payload['delivery_address'] = bval;
        payload.remove('building_id');
      }
    }
    return payload;
  }

  /// Persist an intended delivery address locally so it can be attached once the server
  /// schema or operator fixes the missing column. Used when server rejects address fields.
  @visibleForTesting
  Future<void> persistPendingDeliveryAddress(String orderId, String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_delivery_address_$orderId', address);
  }

  /// Persist an intended order payload locally so it can be replayed when
  /// network/server issues are resolved. Stored under `pending_order_<uuid>`.
  @visibleForTesting
  Future<void> persistPendingOrderPayload(Map<String, dynamic> payload, [List<Map<String, dynamic>>? items]) async {
    final prefs = await SharedPreferences.getInstance();
    final id = '${DateTime.now().toUtc().toIso8601String()}-${UniqueKey()}';
    final key = 'pending_order_$id';
    final toStore = Map<String, dynamic>.from(payload);
    if (items != null) toStore['items'] = items;
    await prefs.setString(key, jsonEncode(toStore));
  }

  /// List locally persisted pending orders (for diagnostics or replay).
  @visibleForTesting
  Future<List<Map<String, dynamic>>> listPendingOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('pending_order_')).toList();
    final out = <Map<String, dynamic>>[];
    for (final k in keys) {
      final v = prefs.getString(k);
      if (v == null) continue;
      try {
        final m = jsonDecode(v) as Map<String, dynamic>;
        out.add(m);
      } catch (_) {}
    }
    return out;
  }

  /// Attempt to replay pending local orders. This is best-effort and should
  /// be invoked from an operator device or at app startup once server schema
  /// is fixed. Successful replays remove the pending entry.
  @visibleForTesting
  Future<void> replayPendingOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('pending_order_')).toList();
    for (final k in keys) {
      final v = prefs.getString(k);
      if (v == null) continue;
      try {
        final m = Map<String, dynamic>.from(jsonDecode(v) as Map);
        final List<Map<String, dynamic>>? items = (m['items'] is List) ? (m['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList() : null;

        // Try insert order (this will surface Postgrest errors if server still not ready)
        try {
          final result = await _client.from('orders').insert(m)..select('id');
          // if result succeed, remove pending
          await prefs.remove(k);
        } catch (e) {
          if (kDebugMode) print('replayPendingOrders: failed to replay $k: $e');
        }
      } catch (e) {
        if (kDebugMode) print('replayPendingOrders: corrupt pending entry $k: $e');
        await prefs.remove(k);
      }
    }
  }

  /// Visible-for-testing helper: build payload for `order_items` insert from
  /// already-known order id and items.
  @visibleForTesting
  List<Map<String, dynamic>> buildOrderItemsPayload(String orderId, List<Map<String, dynamic>> items) {
    return items.map((item) {
      return {
        'order_id': orderId,
        'food_id': item['menu_id'],
        'quantity': item['qty'],
      };
    }).toList();
  }

  /// Create an order (two-step flow): 1) insert into `orders`, 2) insert `order_items`.
  ///
  /// Notes:
  /// - `delivery_address` / `building_id` are only included when `deliveryType == 'delivery'`.
  /// - Validates `userId` (UUID), item qty/prices, and ensures totals are computed.
  /// - Retries order insert a few times for transient failures. If server rejects `delivery_address`
  ///   (e.g., older schema), it will retry without address and persist the intended address locally
  ///   for later replay using `replayPendingOrders()`.
  /// - If all attempts fail, the full order payload (+ items) is persisted to SharedPreferences
  ///   under `pending_order_<ts>` to allow manual or automatic replay once connectivity/schema is fixed.
  Future<String?> createOrder({
    required String userId,
    required List<Map<String, dynamic>> items,
    required String deliveryType, // pickup | delivery
    String? buildingId,
    String? paymentMethod,
    double? shippingFee,
  }) async {
    if (items.isEmpty) {
      if (kDebugMode) print('createOrder aborted: items empty');
      return null;
    }

    // Defensive: ensure userId is a valid UUID to avoid PostgREST type errors
    final uuidRe = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (!uuidRe.hasMatch(userId)) {
      if (kDebugMode) print('createOrder aborted: invalid userId: $userId');
      return null;
    }

    try {
      // ------------------------------------------
      // STEP 1: VALIDATION
      // ------------------------------------------
      // Defensive validation: if delivery is requested, ensure delivery address exists
      if (deliveryType == 'delivery' && (buildingId == null || buildingId.trim().isEmpty)) {
        if (kDebugMode) print('createOrder aborted: delivery requested but delivery address missing');
        return null;
      }

      // Validate items: menu_id present, qty > 0, price valid
      for (final it in items) {
        final mid = it['menu_id']?.toString();
        final qty = (it['qty'] is int) ? it['qty'] : int.tryParse(it['qty']?.toString() ?? '') ?? 0;
        final price = (it['price'] is num) ? (it['price'] as num).toDouble() : double.tryParse(it['price']?.toString() ?? '') ?? -1.0;
        if (mid == null || mid.isEmpty || qty <= 0 || price < 0.0) {
          if (kDebugMode) print('createOrder aborted: invalid items payload: $it');
          return null;
        }
      }

      // Normalize shipping/payment payloads: pickup -> no address, shipping fee 0
      final normalizedShippingFee = (deliveryType == 'delivery') ? (shippingFee ?? 0.0) : 0.0;
      final normalizedPayment = paymentMethod ?? '';

      // Compute subtotal and total safely (floating point arithmetic internally)
      double computedSubtotal = 0.0;
      for (final it in items) {
        final qty = (it['qty'] is int) ? it['qty'] : int.tryParse(it['qty']?.toString() ?? '0') ?? 0;
        final price = (it['price'] is num) ? (it['price'] as num).toDouble() : double.tryParse(it['price']?.toString() ?? '0') ?? 0.0;
        computedSubtotal += price * qty;
      }
      if (!computedSubtotal.isFinite) computedSubtotal = 0.0;
      final computedTotal = (computedSubtotal + normalizedShippingFee).isFinite ? (computedSubtotal + normalizedShippingFee) : computedSubtotal;

      // Build insert payload (normalize building/address based on content), include totals (still as doubles for internal usage)
      final orderPayload = buildOrderInsertPayload(
        userId: userId,
        deliveryType: deliveryType,
        buildingId: buildingId,
        paymentMethod: normalizedPayment,
        shippingFee: normalizedShippingFee,
        subtotal: computedSubtotal,
        totalPrice: computedTotal,
      );

      // Final sanitize to ensure no free-text inserted into UUID columns.
      sanitizeOrderPayload(orderPayload);

      // Convert numeric fields expected by DB as integers to int here, right before inserts.
      Map<String, dynamic> payloadForInsert = Map<String, dynamic>.from(orderPayload);

      void _convertNumericFieldToInt(Map<String, dynamic> m, String key) {
        if (!m.containsKey(key)) return;
        final v = m[key];
        if (v is int) return;
        if (v is num) {
          m[key] = v.toInt();
          return;
        }
        // attempt parse string -> double -> int
        final parsed = double.tryParse(v?.toString() ?? '');
        if (parsed != null && parsed.isFinite) {
          m[key] = parsed.toInt();
        }
      }

      _convertNumericFieldToInt(payloadForInsert, 'delivery_tip');
      _convertNumericFieldToInt(payloadForInsert, 'subtotal');
      _convertNumericFieldToInt(payloadForInsert, 'total_price');

      // Attempt order INSERT with retries and backoff
      String orderId = '';
      const int maxAttempts = 3;
      int attempt = 0;
      int delayMs = 200;
      while (attempt < maxAttempts) {
        try {
          final orderInsert = await _client
              .from('orders')
              .insert(payloadForInsert)
              .select('id')
              .single();
          orderId = orderInsert['id'];
          break;
        } on PostgrestException catch (e) {
          if (kDebugMode) print('createOrder insert PostgrestException (attempt ${attempt + 1}): $e');
          final errMsg = (e.message ?? '').toString();

          // If server lacks delivery_address (PGRST204) try stripping and retry immediately
          if (e.code == 'PGRST204' || errMsg.contains("Could not find the 'delivery_address'") || errMsg.contains('Could not find')) {
            final attemptedAddress = payloadForInsert['delivery_address'] ?? payloadForInsert['building_id'];
            final strippedPayload = Map<String, dynamic>.from(payloadForInsert);
            strippedPayload.remove('delivery_address');
            strippedPayload.remove('building_id');

            try {
              final orderInsert2 = await _client
                  .from('orders')
                  .insert(strippedPayload)
                  .select('id')
                  .single();
              orderId = orderInsert2['id'];

              // Persist intended address with orderId for later replay
              if (attemptedAddress != null) {
                try {
                  await persistPendingDeliveryAddress(orderId, attemptedAddress.toString());
                } catch (ePrefs) {
                  if (kDebugMode) print('createOrder: failed to persist pending address: $ePrefs');
                }
              }

              break;
            } catch (e2) {
              if (kDebugMode) print('createOrder retry without address failed: $e2');
              // fallthrough to retry outer loop/backoff
            }
          }

          // If we have more attempts, wait and retry
          attempt += 1;
          if (attempt < maxAttempts) {
            await Future.delayed(Duration(milliseconds: delayMs));
            delayMs *= 2;
            continue;
          }

          // All attempts exhausted: persist full pending order payload locally for repair
          try {
            await persistPendingOrderPayload(payloadForInsert, items);
            if (kDebugMode) print('createOrder: persisted pending order after failed inserts');
          } catch (ePersist) {
            if (kDebugMode) print('createOrder: failed to persist pending order: $ePersist');
          }

          return null;
        } catch (e) {
          if (kDebugMode) print('createOrder insert unexpected error (attempt ${attempt + 1}): $e');
          attempt += 1;
          if (attempt < maxAttempts) {
            await Future.delayed(Duration(milliseconds: delayMs));
            delayMs *= 2;
            continue;
          }

          try {
            await persistPendingOrderPayload(payloadForInsert, items);
            if (kDebugMode) print('createOrder: persisted pending order after unexpected errors');
          } catch (ePersist) {
            if (kDebugMode) print('createOrder: failed to persist pending order: $ePersist');
          }
          return null;
        }
      }

      if (orderId.isEmpty) return null;

      // ------------------------------------------
      // STEP 2: INSERT ORDER ITEMS
      // ------------------------------------------
      final List<Map<String, dynamic>> orderItemsPayload = items.map((item) {
        return {
          'order_id': orderId,
          'food_id': item['menu_id'],
          'quantity': item['qty'],
        };
      }).toList();

      // Try inserting order_items with a small retry loop to handle transient
      // PostgREST/connection issues that could leave orders without items.
      List insertedItems = [];

      while (attempt < maxAttempts) {
        try {
          final res = await _client.from('order_items').insert(orderItemsPayload).select('id');
          insertedItems = (res as List);
          if (insertedItems.isNotEmpty) break;
        } catch (e) {
          if (kDebugMode) print('order_items insert attempt ${attempt + 1} failed: $e');
        }

        attempt += 1;
        await Future.delayed(Duration(milliseconds: delayMs));
        delayMs *= 2;
      }

      if (insertedItems.isEmpty) {
        // Attempt to roll back the created order to avoid dangling partial orders.
        try {
          final now = DateTime.now().toUtc().toIso8601String();
          await _client.from('orders').update({'is_deleted': true, 'deleted_at': now}).eq('id', orderId);
          if (kDebugMode) print('createOrder: soft-deleted order $orderId after order_items insert failure');
          return null;
        } catch (e) {
          // If rollback fails (e.g., RLS), persist partial marker and attempted items
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('partial_order_$orderId', true);
            await prefs.setString('partial_order_items_$orderId', jsonEncode(items));
          } catch (_) {}

          if (kDebugMode) print('createOrder: order_items insert failed and rollback failed for order $orderId: $e');
          return null;
        }
      }

      // Clear any partial flag if present
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('partial_order_$orderId');
        await prefs.remove('partial_order_items_$orderId');
      } catch (_) {}

      return orderId;
    } catch (e) {
      if (kDebugMode) {
        print('createOrder failed: $e');
      }
      return null;
    }
  }

  // Stream a single order by id (with items)
  Stream<OrderModel?> streamOrderById(String orderId) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .asyncMap((data) async {
      final list = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (list.isEmpty) return null;
      final row = list.first;

      final itemsRaw = (row['order_items'] as List?) ?? [];
      final hasUser = (row['users'] is Map);
      final hasPayment = (row['payment_method'] != null) || (row['paymentMethod'] != null) || (row['method'] != null);


      // Fallback: fetch full order with joins if stream row lacks important nested data
      if (itemsRaw.isEmpty || !hasUser || !hasPayment) {
        final full = await fetchOrderById(row['id']?.toString() ?? '');
        return full;
      }

      row['items'] = itemsRaw.map((oi) {
        final food = (oi as Map)['food'] as Map<String, dynamic>?;
        return {
          'menu_id': oi['food_id']?.toString(),
          'name': food != null ? (food['name'] ?? '') : '',
          'qty': oi['quantity'],
          'price': food != null ? (food['price'] ?? 0) : 0,
          'image_url': food != null ? (food['image_url'] ?? '') : '',
        };
      }).toList();

      // compute subtotal and total if missing
      try {
        double computedSubtotal = 0.0;
        for (final it in (row['items'] as List)) {
          final qty = (it['qty'] is int) ? it['qty'] : int.tryParse(it['qty']?.toString() ?? '0') ?? 0;
          final price = (it['price'] is num) ? (it['price'] as num).toDouble() : double.tryParse(it['price']?.toString() ?? '0') ?? 0.0;
          computedSubtotal += price * qty;
        }
        final dt = row['delivery_tip'] ?? row['deliveryTip'] ?? row['delivery_fee'] ?? row['deliveryFee'];
        final parsedDeliveryTip = (dt is num) ? dt.toDouble() : double.tryParse(dt?.toString() ?? '0') ?? 0.0;
        final serverTotal = row['total_price'] ?? row['total'];
        if (serverTotal == null) {
          row['subtotal'] = computedSubtotal;
          row['delivery_tip'] = parsedDeliveryTip;
          row['total_price'] = computedSubtotal + parsedDeliveryTip;
        } else {
          row['subtotal'] = computedSubtotal;
          row['delivery_tip'] = parsedDeliveryTip;
        }
      } catch (e) {
        if (kDebugMode) print('streamOrderById compute totals error: $e');
      }

      return OrderModel.fromMap(row);
    });
  }

  // Attempt to attach missing items to an existing order. Returns true if
  // all requested items are present after operation.
  Future<bool> attachItemsToOrder({required String orderId, required List<Map<String, dynamic>> items}) async {
    try {
      // Fetch existing items for order
      final existing = await _client
          .from('order_items')
          .select('id, food_id, quantity')
          .eq('order_id', orderId);

      final Map<String, Map<String, dynamic>> existingByFood = {};
      for (final e in (existing as List)) {
        final row = Map<String, dynamic>.from(e as Map);
        existingByFood[row['food_id'].toString()] = row;
      }

      final List<Map<String, dynamic>> toInsert = [];
      final List<Future> updates = [];

      for (final item in items) {
        final menuId = item['menu_id']?.toString();
        final qty = (item['qty'] is int) ? item['qty'] : int.tryParse(item['qty']?.toString() ?? '0') ?? 0;
        if (menuId == null || qty <= 0) continue;

        final existingRow = existingByFood[menuId];
        if (existingRow == null) {
          toInsert.add({'order_id': orderId, 'food_id': menuId, 'quantity': qty});
        } else {
          final existingQty = (existingRow['quantity'] is int) ? existingRow['quantity'] : int.tryParse(existingRow['quantity']?.toString() ?? '0') ?? 0;
          if (existingQty != qty) {
            updates.add(_client.from('order_items').update({'quantity': qty}).eq('id', existingRow['id']));
          }
        }
      }

      if (toInsert.isNotEmpty) {
        await _client.from('order_items').insert(toInsert);
      }

      if (updates.isNotEmpty) {
        await Future.wait(updates);
      }

      // Verify result: fetch items again and compare counts
      final after = await _client.from('order_items').select('food_id, quantity').eq('order_id', orderId);
      final afterList = (after as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final presentFood = afterList.map((e) => e['food_id'].toString()).toSet();

      final requiredFood = items.map((i) => i['menu_id']?.toString()).whereType<String>().toSet();

      final ok = requiredFood.difference(presentFood).isEmpty;


      if (ok) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('partial_order_$orderId');
          await prefs.remove('partial_order_items_$orderId');
        } catch (_) {}
      }

      return ok;
    } catch (e) {
      if (kDebugMode) print('attachItemsToOrder error: $e');
      return false;
    }
  }

  /// Read stored partial items for an order (if any).
  Future<List<Map<String, dynamic>>?> getStoredPartialItems(String orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('partial_order_items_$orderId');
      if (s == null) return null;
      final decoded = jsonDecode(s) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      if (kDebugMode) print('getStoredPartialItems error: $e');
      return null;
    }
  }

  /// Load stored partial items and attempt to attach them to the given order.
  Future<bool> attachStoredItems(String orderId) async {
    try {
      final items = await getStoredPartialItems(orderId);
      if (items == null || items.isEmpty) return false;
      return await attachItemsToOrder(orderId: orderId, items: items);
    } catch (e) {
      if (kDebugMode) print('attachStoredItems error: $e');
      return false;
    }
  }

  // Attempt to recover a recently created order for user by matching items.
  /// Attempt to find a recently created order for the user by matching items.
  /// If `approxDeliveryAddress` is provided, prefer orders whose address contains that substring.
  Future<String?> recoverRecentOrder({required String userId, required List<Map<String, dynamic>> approxItems, int withinSeconds = 30, String? approxDeliveryAddress}) async {
    try {
      final cutoff = DateTime.now().toUtc().subtract(Duration(seconds: withinSeconds)).toIso8601String();
      final res = await _client
          .from('orders')
          .select('id, delivery_address, building_id, order_items(food_id, quantity)')
          .eq('user_id', userId)
          .gte('order_time', cutoff)
          .order('order_time', ascending: false)
          .limit(10);

      final List candidates = (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final required = approxItems.map((i) => i['menu_id']?.toString()).whereType<String>().toList();

      String? bestMatchId;

      for (final c in candidates) {
        final items = (c['order_items'] as List?) ?? [];
        if (items.isEmpty) continue; // skip empty

        final foods = items.map((i) => i['food_id']?.toString()).whereType<String>().toList();
        // simple heuristic: at least one matching menu id
        final intersects = required.any((r) => foods.contains(r));
        if (!intersects) continue;

        // If we have an approximate delivery address, prefer candidate with matching address
        if (approxDeliveryAddress != null && approxDeliveryAddress.isNotEmpty) {
          final addr = (c['delivery_address'] ?? c['building_id'])?.toString().toLowerCase() ?? '';
          if (addr.isNotEmpty && addr.contains(approxDeliveryAddress.toLowerCase())) {
            return c['id']?.toString();
          }
        }

        // fallback: any intersecting candidate is acceptable
        bestMatchId ??= c['id']?.toString();
      }

      return bestMatchId;
    } catch (e) {
      if (kDebugMode) print('recoverRecentOrder error: $e');
      return null;
    }
  }

  // ======================================================
  // FETCH ORDER DETAIL (WITH ITEMS)
  // ======================================================
  Future<OrderModel?> fetchOrderById(String orderId) async {
    try {
      // Fetch order and users; do NOT rely on nested users->profiles join (some DBs may not have FK)
      final res = await _client
          .from('orders')
          .select('*, order_items(*, food:food_menu(*)), users(*)')
          .eq('id', orderId)
          .single();

      final Map<String, dynamic> row = Map<String, dynamic>.from(res as Map);

      // If users exists, attempt a safe separate fetch of profile.full_name (avoid relying on DB FK relationship)
      try {
        final usersRaw = row['users'];
        if (usersRaw is Map && usersRaw['id'] != null) {
          final String uid = usersRaw['id'].toString();

          // If we previously discovered profiles table is missing, skip attempts
          if (_profilesAvailable == false) {
            // ensure customer_name is populated from users if available
            if (usersRaw['full_name'] != null) row['customer_name'] = usersRaw['full_name'];
          } else {
            // Try profiles.id == uid
            try {
              final profRes = await _client.from('profiles').select('full_name').eq('id', uid).limit(1);
              if (profRes.isNotEmpty) {
                final profRow = Map<String, dynamic>.from(profRes.first as Map);
                if (profRow['full_name'] != null) {
                  row['profiles'] = {'full_name': profRow['full_name']};
                }
              } else {
                // Fallback: try profiles.user_id == uid
                final profRes2 = await _client.from('profiles').select('full_name').eq('user_id', uid).limit(1);
                if (profRes2.isNotEmpty) {
                  final profRow2 = Map<String, dynamic>.from(profRes2.first as Map);
                  if (profRow2['full_name'] != null) {
                    row['profiles'] = {'full_name': profRow2['full_name']};
                  }
                } else {
                  // If no profile found, ensure we still set a customer name from users if possible
                  if (usersRaw['full_name'] != null) row['customer_name'] = usersRaw['full_name'];
                }
              }
            } catch (e) {
              // If the error indicates profiles table is missing, remember that and avoid future attempts
              try {
                final s = e.toString();
                if (s.contains("Could not find the table 'public.profiles'") || s.contains('PGRST205')) {
                  _profilesAvailable = false;
                  if (kDebugMode) debugPrint('profiles table not found; disabling profile lookups');
                  // populate customer_name from users if available
                  if (usersRaw['full_name'] != null) row['customer_name'] = usersRaw['full_name'];
                } else {
                  if (kDebugMode) print('fetchOrderById profile fetch error: $e');
                }
              } catch (_) {
                if (kDebugMode) print('fetchOrderById profile fetch error (unknown): $e');
              }
            }
          }
        }
      } catch (_) {}


      final List items = row['order_items'] ?? [];

      row['items'] = items.map((oi) {
        final food = oi['food'];
        return {
          'menu_id': food['id'],
          'name': food['name'],
          'qty': oi['quantity'],
          'price': food['price'],
          'image_url': food['image_url'],
        };
      }).toList();

      // Compute subtotal + delivery tip (if server didn't provide total)
      try {
        double computedSubtotal = 0.0;
        for (final it in (row['items'] as List)) {
          final qty = (it['qty'] is int) ? it['qty'] : int.tryParse(it['qty']?.toString() ?? '0') ?? 0;
          final price = (it['price'] is num) ? (it['price'] as num).toDouble() : double.tryParse(it['price']?.toString() ?? '0') ?? 0.0;
          computedSubtotal += price * qty;
        }

        final dt = row['delivery_tip'] ?? row['deliveryTip'] ?? row['delivery_fee'] ?? row['deliveryFee'];
      final parsedDeliveryTip = (dt is num) ? dt.toDouble() : double.tryParse(dt?.toString() ?? '0') ?? 0.0;
        // prefer server total if present
        final serverTotal = row['total_price'] ?? row['total'];
        if (serverTotal == null) {
          row['subtotal'] = computedSubtotal;
          row['delivery_tip'] = parsedDeliveryTip;
          row['total_price'] = computedSubtotal + parsedDeliveryTip;
        } else {
          // ensure subtotal and delivery_tip fields exist for UI convenience
          row['subtotal'] = computedSubtotal;
          row['delivery_tip'] = parsedDeliveryTip;
          try {
            if (serverTotal is num) row['total_price'] = serverTotal.toDouble();
          } catch (_) {}
        }
      } catch (e) {
        // best-effort, leave existing values if computation fails
        if (kDebugMode) print('fetchOrderById compute totals error: $e');
      }

      // Ensure payment_method and users are present in the row when possible
      row['payment_method'] = row['payment_method'] ?? row['paymentMethod'] ?? row['method'];

      return OrderModel.fromMap(row);
    } catch (e) {
      if (kDebugMode) {
        print('fetchOrderById error: $e');
      }
      return null;
    }
  }

  /// Compute the maximum preparation time (in minutes) among provided items.
  /// If `fetchMenuById` is provided, it will be used for fetching menu details
  /// (useful for tests); otherwise the service will fetch from `food_menu`.
  Future<int> computeMaxPrepFromItems(List<Map<String, dynamic>> items, {Future<MenuModel?> Function(String id)? fetchMenuById}) async {
    final fetcher = fetchMenuById ?? ((String id) async {
      try {
        final res = await _client.from('food_menu').select().eq('id', id).single();
        return MenuModel.fromMap(Map<String, dynamic>.from(res as Map));
      } catch (_) {
        return null;
      }
    });

    int maxPrep = 0;
    for (final it in items) {
      final menuId = it['menu_id']?.toString();
      if (menuId == null) continue;
      try {
        final menu = await fetcher(menuId);
        if (menu != null && menu.prepTime > maxPrep) maxPrep = menu.prepTime;
      } catch (_) {}
    }

    if (maxPrep <= 0) return 10; // sensible default
    return maxPrep;
  }

  // ======================================================
  // CANCEL ORDER (USER)
  // ======================================================
  Future<bool> cancelOrder(String orderId) async {
    try {
      await _client
          .from('orders')
          .update({'status': 'cancelled'})
          .eq('id', orderId);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('cancelOrder error: $e');
      }
      return false;
    }
  }

  /// Delete a single order (admin or user with proper policy). Returns true on success.
  Future<bool> deleteOrder(String orderId) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _client.from('orders').update({'is_deleted': true, 'deleted_at': now}).eq('id', orderId);
      return true;
    } catch (e) {
      if (kDebugMode) print('deleteOrder error: $e');
      return false;
    }
  }

  /// Clear a user's history (non-pending orders) in small batches to
  /// avoid large memory/realtime update spikes on the client. Respects RLS.
  Future<bool> clearUserHistory(String userId, {int batchSize = 100}) async {
    try {
      // Iterate deletions by fetching IDs in pages and deleting by id.
      while (true) {
        // Fetch a page of order ids + status, filter client-side to avoid depending on a specific server-side filter implementation
        final idsRespRaw = await _client.from('orders').select('id,status').eq('user_id', userId).limit(batchSize);
        final List<Map<String, dynamic>> rowsPage = (idsRespRaw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final ids = rowsPage.where((r) => (r['status']?.toString() ?? '') != 'pending').map((r) => r['id'] as String).toList();
        if (ids.isEmpty) break;

        // Soft-delete this batch by id — update per-id to ensure compatibility with SDKs
        final now = DateTime.now().toUtc().toIso8601String();
        for (final id in ids) {
          try {
            await _client.from('orders').update({'is_deleted': true, 'deleted_at': now}).eq('id', id);
          } catch (e) {
            if (kDebugMode) print('clearUserHistory per-id delete failed for $id: $e');
          }
        }

        // Yield to the event loop and allow realtime listeners to settle.
        await Future.delayed(const Duration(milliseconds: 200));

        // Continue until no more rows.
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('clearUserHistory error: $e');
      return false;
    }
  }

  /// Admin: clear all completed orders.
  Future<bool> clearCompletedOrders() async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _client.from('orders').update({'is_deleted': true, 'deleted_at': now}).eq('status', 'completed');
      return true;
    } catch (e) {
      if (kDebugMode) print('clearCompletedOrders error: $e');
      return false;
    }
  }
}
