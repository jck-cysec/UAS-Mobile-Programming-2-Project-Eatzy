import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/core/config/api.dart';
import '/core/constants/app_colors.dart';
import '/data/models/order_model.dart';

class PendingOrdersPage extends StatefulWidget {
  const PendingOrdersPage({super.key});

  @override
  State<PendingOrdersPage> createState() => _PendingOrdersPageState();
}

class _PendingOrdersPageState extends State<PendingOrdersPage> {
  final List<_PendingEntry> _entries = [];
  bool _loading = false;
  bool _replayAllInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadPendingEntries();
  }

  Future<void> _loadPendingEntries() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    final temp = <_PendingEntry>[];

    for (final k in keys) {
      if (k.startsWith('pending_order_')) {
        final v = prefs.getString(k);
        if (v == null) continue;
        try {
          final Map<String, dynamic> payload = Map<String, dynamic>.from(jsonDecode(v) as Map);
          temp.add(_PendingEntry.order(key: k, payload: payload));
        } catch (e) {
          if (kDebugMode) debugPrint('PendingOrdersPage: corrupt pending_order $k: $e');
          // treat as raw string fallback
          temp.add(_PendingEntry.raw(key: k, raw: v));
        }
      } else if (k.startsWith('pending_delivery_address_')) {
        final v = prefs.getString(k);
        if (v == null) continue;
        // key format: pending_delivery_address_<orderId>
        final orderId = k.substring('pending_delivery_address_'.length);
        temp.add(_PendingEntry.pendingAddress(key: k, orderId: orderId, address: v));
      }
    }

    // Sort by key (newest last) for stable UI
    temp.sort((a, b) => a.key.compareTo(b.key));

    if (mounted) setState(() {
      _entries.clear();
      _entries.addAll(temp);
      _loading = false;
    });
  }

  Future<void> _replayEntry(_PendingEntry entry) async {
    if (entry.loading) return;
    setState(() => entry.loading = true);

    try {
      if (entry.type == _PendingEntryType.order) {
        // Use Api.createOrder to re-submit payload
        final created = await Api.instance.createOrder(entry.payload!);
        if (created != null) {
          await _removeKey(entry.key);
          if (mounted) {
            setState(() => entry.replayed = true);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Replay berhasil — order id: $created')));
          }
        } else {
          if (mounted) {
            entry.error = 'Replay gagal';
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Replay gagal — periksa log')));
          }
        }
      } else if (entry.type == _PendingEntryType.pendingAddress) {
        // Try to patch existing order with the saved address
        final client = Supabase.instance.client;
        try {
          await client.from('orders').update({'delivery_address': entry.address}).eq('id', entry.orderId as Object);
          // if succeeds, remove key
          await _removeKey(entry.key);
          if (mounted) {
            setState(() => entry.replayed = true);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alamat berhasil diterapkan')));
          }
        } catch (e) {
          if (kDebugMode) debugPrint('PendingOrdersPage: failed to update order address: $e');
          if (mounted) {
            entry.error = 'Gagal mengupdate alamat';
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Replay alamat gagal — periksa log')));
          }
        }
      } else {
        // raw or unknown - nothing smart we can do, offer delete
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item tidak bisa di-replay otomatis')));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('PendingOrdersPage._replayEntry error: $e');
      if (mounted) {
        entry.error = 'Unexpected error';
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Replay gagal — unexpected error')));
      }
    } finally {
      if (mounted) setState(() => entry.loading = false);
    }
  }

  Future<void> _replayAll() async {
    if (_replayAllInProgress) return;
    setState(() => _replayAllInProgress = true);

    // We'll attempt per-entry replays so we can give per-item feedback
    for (final e in List<_PendingEntry>.from(_entries)) {
      if (e.replayed) continue;
      await _replayEntry(e);
    }

    // After attempting, reload list to remove items that were removed
    await _loadPendingEntries();

    setState(() => _replayAllInProgress = false);
  }

  Future<void> _removeKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await _loadPendingEntries();
  }

  Future<void> _confirmDelete(_PendingEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus pending entry'),
        content: const Text('Yakin ingin menghapus entry ini secara permanen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );

    if (ok == true) await _removeKey(entry.key);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    final horizontalPadding = isDesktop ? 32.0 : 20.0;
    final bottomNavPadding = MediaQuery.of(context).padding.bottom + 80.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          /// =========================
          /// HEADER WITH GRADIENT BACKGROUND
          /// =========================
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.85),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.pending_actions_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pesanan Tertunda',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Kelola & replay pesanan yang gagal',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Replay All button in header
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _replayAllInProgress ? null : _replayAll,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_replayAllInProgress)
                                    const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  else
                                    const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    _replayAllInProgress ? 'Memproses...' : 'Replay Semua',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _loading ? null : _loadPendingEntries,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          /// =========================
          /// CONTENT LIST
          /// =========================
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_rounded,
                              size: 64,
                              color: Colors.grey.withOpacity(0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada pesanan tertunda',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.withOpacity(0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPendingEntries,
                        child: ListView.builder(
                          padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, bottomNavPadding),
                          itemCount: _entries.length,
                          itemBuilder: (ctx, i) {
                            final e = _entries[i];
                            return _buildPendingCard(e);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryBody(_PendingEntry e) {
    if (e.type == _PendingEntryType.order) {
      final payload = e.payload!;
      final userId = payload['user_id']?.toString() ?? '-';
      final deliveryType = payload['delivery_type']?.toString() ?? '-';
      final address = payload['delivery_address']?.toString() ?? '-';
      final items = (payload['items'] as List?) ?? (payload['order_items'] as List?) ?? [];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('User ID', userId),
          const SizedBox(height: 8),
          _buildInfoRow('Tipe', deliveryType.toUpperCase()),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Alamat', address, maxLines: 2),
          ],
          if (items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Item (${items.length})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final it in items.take(5))
                  Builder(
                    builder: (_) {
                      try {
                        final m = Map<String, dynamic>.from(it as Map);
                        final name = (m['name'] ?? m['menu_id'])?.toString() ?? '-';
                        final qty = m['qty']?.toString() ?? (m['quantity']?.toString() ?? '-');
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text('• $name × $qty', style: const TextStyle(fontSize: 12)),
                        );
                      } catch (_) {
                        return const Text('• (item tidak valid)', style: TextStyle(fontSize: 11));
                      }
                    },
                  ),
                if (items.length > 5)
                  Text('+ ${items.length - 5} item lainnya', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
              ],
            ),
          ],
        ],
      );
    }

    if (e.type == _PendingEntryType.pendingAddress) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Order ID', e.orderId ?? '-'),
          const SizedBox(height: 8),
          _buildInfoRow('Alamat', e.address ?? '-', maxLines: 2),
        ],
      );
    }

    return Text(
      e.raw ?? '-',
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12),
    );
  }

  Widget _buildInfoRow(String label, String value, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              color: Colors.black.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingCard(_PendingEntry e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: e.error != null ? Colors.red.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: e.error != null
                  ? Colors.red.withOpacity(0.05)
                  : (e.replayed ? Colors.green.withOpacity(0.05) : AppColors.primary.withOpacity(0.05)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: e.error != null
                        ? Colors.red.withOpacity(0.15)
                        : (e.replayed ? Colors.green.withOpacity(0.15) : AppColors.primary.withOpacity(0.15)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    e.error != null
                        ? Icons.error_outline
                        : (e.replayed ? Icons.check_circle : Icons.pending_actions),
                    color: e.error != null ? Colors.red : (e.replayed ? Colors.green : AppColors.primary),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Key: ${e.key.substring(0, e.key.length > 30 ? 30 : e.key.length)}...',
                        style: const TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (e.loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    e.replayed ? Icons.check_circle_outline : Icons.pending_actions_outlined,
                    color: e.replayed ? Colors.green : AppColors.textGrey,
                    size: 18,
                  ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: _buildEntryBody(e),
          ),

          // Error message (if any)
          if (e.error != null) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.withOpacity(0.7), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.error!,
                      style: TextStyle(color: Colors.red.withOpacity(0.8), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action buttons
          Container(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: e.loading ? null : () => _replayEntry(e),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.replay_rounded, color: AppColors.primary, size: 16),
                            const SizedBox(width: 6),
                            const Text(
                              'Replay',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _confirmDelete(e),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.delete_outline, color: Colors.red, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _PendingEntryType { order, pendingAddress, raw }

class _PendingEntry {
  final String key;
  final _PendingEntryType type;
  Map<String, dynamic>? payload;
  String? raw;
  String? orderId;
  String? address;

  bool loading = false;
  bool replayed = false;
  String? error;

  _PendingEntry.order({required this.key, required Map<String, dynamic> payload})
      : type = _PendingEntryType.order,
        payload = payload;

  _PendingEntry.pendingAddress({required this.key, required this.orderId, required this.address})
      : type = _PendingEntryType.pendingAddress;

  _PendingEntry.raw({required this.key, required this.raw}) : type = _PendingEntryType.raw;

  String get title {
    switch (type) {
      case _PendingEntryType.order:
        return 'Pending Order (${key.substring(0, key.length > 28 ? 28 : key.length)})';
      case _PendingEntryType.pendingAddress:
        return 'Pending Address (Order ${orderId ?? '-'})';
      case _PendingEntryType.raw:
        return 'Pending (raw)';
    }
  }
}
