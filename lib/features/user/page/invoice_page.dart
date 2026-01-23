import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '/state/session_provider.dart';
import '/data/services/order_service.dart';
import '/data/models/order_model.dart';
import '/core/constants/app_colors.dart';
import '/widgets/countdown_text.dart';
import '/features/user/page/order_status_page.dart';

class InvoicePage extends StatefulWidget {
  final String orderId;
  const InvoicePage({super.key, required this.orderId});

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  OrderModel? _fallbackOrder;
  DateTime? _loadingStarted;
  bool _fallbackRequested = false;

  Future<bool> _isPartialOrder(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('partial_order_$id') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Try a one-time authoritative fetch when realtime stream takes too long
  Future<void> _tryFetchOnce() async {
    if (_fallbackRequested) return;
    _fallbackRequested = true;
    try {
      final fetched = await OrderService().fetchOrderById(widget.orderId);
      if (!mounted) return;
      if (fetched != null) {
        setState(() {
          _fallbackOrder = fetched;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('InvoicePage fetch fallback error: $e');
      // Keep fallbackOrder null so UI can continue to show loading + retry.
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = OrderService();

    return Scaffold(
      backgroundColor: AppColors.background,
      
      /// ===================== APP BAR =====================
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Invoice',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ),
      ),

      /// ===================== BODY =====================
      body: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(math.min(MediaQuery.of(context).textScaleFactor, 1.2)),
        ),
        child: StreamBuilder<OrderModel?>(
          stream: service.streamOrderById(widget.orderId),
          builder: (context, snapshot) {
            // If stream has data, prefer it and clear any fallback
            if (snapshot.hasData && snapshot.data != null) {
              _fallbackOrder = null;
              _loadingStarted = null;
            }

            // If no stream data yet, but we have an authoritative fallback, use it
            final useOrder = snapshot.hasData && snapshot.data != null ? snapshot.data! : _fallbackOrder;

            // If still no order available from stream or fallback, start a timed one-shot fetch
            if (useOrder == null) {
              // mark loading start time
              _loadingStarted ??= DateTime.now();

              // schedule one-time fetch after 2.5s if still no data
              if (!_fallbackRequested) {
                Future.delayed(const Duration(milliseconds: 2500), () {
                  if (!mounted) return;
                  // if still no stream data and we haven't requested fallback yet
                  if (!(snapshot.hasData && snapshot.data != null) && _fallbackOrder == null) {
                    _tryFetchOnce();
                    setState(() {}); // refresh UI to show secondary loading state
                  }
                });
              }

              final waitingSecs = _loadingStarted == null ? 0 : DateTime.now().difference(_loadingStarted!).inSeconds;

              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      waitingSecs < 3 ? 'Memuat invoice...' : 'Sedang mencoba mengambil detail pesanan — jika lama, tekan Muat Ulang',
                      style: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 14,
                      ),
                    ),
                    if (waitingSecs >= 3) ...[
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          _fallbackRequested = false; // allow a fresh attempt
                          await _tryFetchOnce();
                          if (!mounted) return;
                          setState(() {});
                        },
                        child: const Text('Muat Ulang'),
                      ),
                    ],
                  ],
                ),
              );
            }

            final order = useOrder;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// ===== PARTIAL ORDER WARNING =====
                  FutureBuilder<bool>(
                    future: _isPartialOrder(order.id),
                    builder: (ctx, psnap) {
                      final isPartial = psnap.data ?? false;
                      if (!isPartial) return const SizedBox.shrink();
                      
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.withOpacity(0.15),
                              Colors.orange.withOpacity(0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Peringatan Pesanan Parsial',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Pesanan dibuat, tetapi beberapa item gagal dilampirkan. Silakan pulihkan atau laporkan jika total/item tidak sesuai.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textGrey,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () async {
                                      HapticFeedback.mediumImpact();
                                      final ok = await OrderService().attachStoredItems(order.id);
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                Icon(
                                                  ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    ok ? 'Item berhasil dipulihkan' : 'Gagal memulihkan item — coba lagi',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor: ok ? Colors.green : Colors.redAccent,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.refresh_rounded, size: 18),
                                    label: const Text(
                                      'Pulihkan',
                                      style: TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.orange,
                                      side: BorderSide(color: Colors.orange.withOpacity(0.5)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      Clipboard.setData(
                                        ClipboardData(text: 'Order:${order.id} - partial'),
                                      );
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: const Row(
                                            children: [
                                              Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                                              SizedBox(width: 12),
                                              Text('Informasi disalin'),
                                            ],
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.content_copy_rounded, size: 18),
                                    label: const Text(
                                      'Laporkan',
                                      style: TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  /// ===== INVOICE CARD =====
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// ORDER NUMBER
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withOpacity(0.15),
                                    AppColors.primary.withOpacity(0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.receipt_long_rounded,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'No. Pesanan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textGrey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '#${order.id.length >= 8 ? order.id.substring(0, 8).toUpperCase() : order.id.toUpperCase()}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 16),

                        /// STATUS & TIME
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoItem(
                                icon: Icons.schedule_rounded,
                                label: 'Waktu',
                                value: _formatDateTime(order.orderTime),
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoItem(
                                icon: Icons.info_outline_rounded,
                                label: 'Status',
                                value: _statusLabel(order.status),
                                color: _statusColor(order.status),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Use a single authoritative fetch when any important nested data is missing
                        FutureBuilder<OrderModel?>(
                          future: (order.customerName == 'Unknown User' || order.paymentMethod == 'unknown' || order.paymentMethod.isEmpty || order.items.isEmpty)
                              ? OrderService().fetchOrderById(order.id)
                              : Future.value(order),
                          builder: (ctx, snap) {
                            final enriched = snap.data ?? order;

                            final displayName = (enriched.customerName.isNotEmpty && enriched.customerName != 'Unknown User')
                                ? enriched.customerName
                                : Provider.of<SessionProvider>(context, listen: false).displayName;

                            final pm = (enriched.paymentMethod.isNotEmpty && enriched.paymentMethod != 'unknown') ? enriched.paymentMethod : '—';

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _buildInfoItem(icon: Icons.person_outline_rounded, label: 'Pelanggan', value: displayName, color: Colors.purple)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildInfoItem(icon: Icons.payment_rounded, label: 'Pembayaran', value: pm, color: Colors.green)),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                /// DELIVERY TYPE
                                _buildInfoItem(
                                  icon: enriched.deliveryType.toLowerCase() == 'delivery' ? Icons.delivery_dining_rounded : Icons.store_rounded,
                                  label: 'Tipe Pengiriman',
                                  value: enriched.deliveryType,
                                  color: Colors.orange,
                                ),

                                // If delivery, show address & shipping fee (delivery tip)
                                if (enriched.deliveryType.toLowerCase() == 'delivery') ...[
                                  const SizedBox(height: 12),
                                  _buildInfoItem(
                                    icon: Icons.location_on_outlined,
                                    label: 'Alamat Pengiriman',
                                    value: (enriched.deliveryAddress != null && enriched.deliveryAddress!.isNotEmpty) ? enriched.deliveryAddress! : '—',
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoItem(
                                    icon: Icons.local_shipping_outlined,
                                    label: 'Ongkir',
                                    value: 'Rp ${enriched.deliveryTip.toStringAsFixed(0)}',
                                    color: Colors.green,
                                  ),
                                ],
                              ],
                            );
                          },
                        ),

                        /// PREPARE UNTIL
                        if (order.prepareUntil != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.withOpacity(0.1),
                                  Colors.blue.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.timelapse_rounded,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Perkiraan siap: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                CountdownText(
                                  target: order.prepareUntil!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 16),

                        /// ITEMS HEADER
                        Row(
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              color: AppColors.textGrey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Items (${order.items.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        /// ITEMS LIST
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: order.items.length,
                          separatorBuilder: (_, __) => const Divider(height: 24),
                          itemBuilder: (_, i) {
                            final it = order.items[i];
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${it.qty}x',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        it.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Rp ${it.price.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'Rp ${it.subtotal.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 20),
                        const Divider(thickness: 1.5),
                        const SizedBox(height: 16),

                        /// TOTAL (Subtotal + Delivery Tip + Total)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Subtotal', style: TextStyle(color: Colors.grey[700])),
                                  Text('Rp ${order.subtotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                              if ((order.deliveryTip) > 0) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Biaya Pengiriman', style: TextStyle(color: Colors.grey[700])),
                                    Text('Rp ${order.deliveryTip.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                                  Text('Rp ${order.totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.green, letterSpacing: -0.5)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// ===== ACTION BUTTONS =====
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OrderStatusPage(orderId: order.id),
                                ),
                              );
                            },
                            icon: const Icon(Icons.info_outline_rounded, size: 20),
                            label: const Text(
                              'Lihat Status',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 56,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textGrey,
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.close_rounded, size: 20),
                          label: const Text(
                            'Tutup',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return AppColors.textGrey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'preparing':
        return 'Diproses';
      case 'completed':
        return 'Selesai';
      default:
        return status;
    }
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}