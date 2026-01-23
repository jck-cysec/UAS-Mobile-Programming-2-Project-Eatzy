import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '/core/constants/app_colors.dart';
import '/features/user/user_shell_page.dart';
import '/state/session_provider.dart';
import '/data/services/order_service.dart';
import '/data/models/order_model.dart';
import '../order_status_page.dart';
import '/features/user/page/invoice_page.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  // Track orders removed optimistically so UI hides them immediately while
  // waiting for realtime stream confirmation from the server.
  final Set<String> _optimisticRemoved = {};

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.background,

      /// ===================== APP BAR (ENHANCED STYLE) =====================
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
                      'Riwayat Pesanan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  // 'Hapus Riwayat' action (only when logged in)
                  Builder(builder: (ctx) {
                    final sess = Provider.of<SessionProvider>(ctx, listen: false);
                    if (!sess.isLoggedIn) return const SizedBox(width: 48);
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          await _confirmClearHistory(ctx, sess);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    );
                  }),
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
        child: !session.isLoggedIn
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 64,
                      color: AppColors.textGrey.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Harap login terlebih dahulu',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            : StreamBuilder<List<OrderModel>>(
                stream: OrderService().streamUserOrders(session.user!.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Memuat riwayat...',
                            style: TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _EmptyOrderState();
                  }

                  final orders = snapshot.data!.where((o) => !_optimisticRemoved.contains(o.id)).toList();

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final o = orders[index];

                      return _OrderHistoryCard(
                        order: o,
                        onDeleted: (id) {
                          if (!mounted) return;
                          setState(() {
                            _optimisticRemoved.add(id);
                          });
                        },
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  /// Show confirmation and run batched clear. Provides progress UI and
  /// user-visible feedback. Non-pending orders only (respects server RLS).
  static Future<void> _confirmClearHistory(BuildContext context, SessionProvider session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        elevation: 8,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: Colors.red[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Hapus Riwayat',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Pesanan yang selesai dan dibatalkan akan dihapus. Data tetap aman di server namun tidak ditampilkan lagi. Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(
            color: Colors.black.withOpacity(0.65),
            fontSize: 14,
            height: 1.6,
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(c, false);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              'Batal',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(c, true);
            },
            child: const Text(
              'Hapus',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (ok != true) return;

    // Show a blocking progress dialog while the batched delete runs
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        elevation: 8,
        content: const SizedBox(
          height: 100,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                SizedBox(height: 16),
                Text(
                  'Memproses penghapusan...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final success = await OrderService().clearUserHistory(session.user!.id);

    // dismiss progress
    if (Navigator.canPop(context)) Navigator.pop(context);

    // Show result snackbar with better styling
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                success
                    ? 'Riwayat berhasil dihapus'
                    : 'Gagal menghapus riwayat — silakan coba lagi',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: success ? Colors.green[600] : Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        elevation: 6,
      ),
    );
  }

}

// Top-level helpers used by both the page and the card widgets.
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

String _formatDate(DateTime dt) {
  final d = dt.toLocal();
  return '${d.day}/${d.month}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

/// =====================
/// ORDER HISTORY CARD
/// =====================
class _OrderHistoryCard extends StatelessWidget {
  final OrderModel order;
  final ValueChanged<String>? onDeleted;

  const _OrderHistoryCard({required this.order, this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderStatusPage(orderId: order.id),
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: FutureBuilder<OrderModel?>(
            future: (order.customerName == 'Unknown User' || order.paymentMethod == 'unknown' || order.paymentMethod.isEmpty || order.items.isEmpty)
                ? OrderService().fetchOrderById(order.id)
                : Future.value(order),
            builder: (ctx, snap) {
              final enriched = snap.data ?? order;
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                /// ROW 1: Icon, ID + Status, Price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// ICON
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            statusColor.withOpacity(0.15),
                            statusColor.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: statusColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),

                    /// ORDER ID + STATUS (center)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Order #${enriched.id.length >= 8 ? enriched.id.substring(0, 8).toUpperCase() : enriched.id.toUpperCase()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: statusColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _statusLabel(enriched.status),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    /// PRICE (right)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.withOpacity(0.15),
                            Colors.green.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Rp ${order.totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                /// ROW 2: Item count + Order time
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 14,
                            color: AppColors.textGrey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${enriched.items.length} item',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: AppColors.textGrey,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _formatDate(enriched.orderTime),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textGrey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                /// ROW 3: Customer name
                Builder(builder: (ctx) {
                  final displayName = (enriched.customerName.isNotEmpty && enriched.customerName != 'Unknown User')
                      ? enriched.customerName
                      : Provider.of<SessionProvider>(context, listen: false).displayName;

                  return Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: AppColors.textGrey,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  );
                }),

                const SizedBox(height: 10),

                /// ROW 4: Payment + Delivery
                Builder(builder: (ctx) {
                  final pm = (enriched.paymentMethod.isNotEmpty && enriched.paymentMethod != 'unknown')
                      ? enriched.paymentMethod
                      : '—';

                  return Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.payment_rounded,
                              size: 14,
                              color: AppColors.textGrey,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                pm,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              enriched.deliveryType.toLowerCase() == 'delivery'
                                  ? Icons.delivery_dining_rounded
                                  : Icons.store_rounded,
                              size: 14,
                              color: AppColors.textGrey,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    enriched.deliveryType,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textGrey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if ((enriched.deliveryTip) > 0)
                                    Text('Biaya kirim: Rp ${enriched.deliveryTip.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                /// ROW 5: Action buttons (Status, Invoice, Hapus)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    /// Status Button
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    OrderStatusPage(orderId: order.id),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withOpacity(0.15),
                                  AppColors.primary.withOpacity(0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Status',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    /// Invoice Button
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    InvoicePage(orderId: order.id),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.withOpacity(0.15),
                                  Colors.blue.withOpacity(0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.receipt_rounded,
                                  size: 14,
                                  color: Colors.blue,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Invoice',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    /// Delete button (conditional for owner + completed/cancelled)
                    Builder(builder: (ctx) {
                      final session = Provider.of<SessionProvider>(ctx, listen: false);
                      final isOwner = session.user != null && session.user!.id == order.userId;
                      final canDelete = (order.status == 'completed' || order.status == 'cancelled') && isOwner;
                      if (!canDelete) return Expanded(child: SizedBox.shrink());

                      return Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              HapticFeedback.mediumImpact();
                              final ok = await showDialog<bool>(
                                context: ctx,
                                builder: (dCtx) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(Icons.delete_outline_rounded, color: Colors.red[700], size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(child: Text('Hapus Pesanan')),
                                    ],
                                  ),
                                  content: const Text('Pesanan ini akan dihapus dari riwayat Anda dan tidak akan muncul lagi. Data tetap tersimpan di server (soft delete). Tindakan ini tidak dapat dibatalkan.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Batal')),
                                    TextButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Hapus')),
                                  ],
                                ),
                              );

                              if (ok != true) return;

                              // show progress
                              showDialog<void>(
                                context: ctx,
                                barrierDismissible: false,
                                builder: (pCtx) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  content: SizedBox(
                                    height: 80,
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)),
                                          SizedBox(height: 12),
                                          Text('Memproses penghapusan...'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );

                              final success = await OrderService().deleteOrder(order.id);

                              // dismiss progress
                              if (Navigator.canPop(ctx)) Navigator.pop(ctx);

                              // If deletion succeeded, optimistically remove the item
                              String userVisibleMessage;
                              if (success) {
                                try {
                                  onDeleted?.call(order.id);
                                } catch (_) {}
                                userVisibleMessage = 'Pesanan berhasil dihapus';
                              } else {
                                // Try to diagnose common causes
                                String diag = 'Gagal menghapus pesanan — coba lagi';
                                try {
                                  final fetched = await OrderService().fetchOrderById(order.id);
                                  final session = Provider.of<SessionProvider>(ctx, listen: false);
                                  if (fetched == null) {
                                    diag = 'Gagal: pesanan tidak ditemukan atau Anda tidak memiliki izin (RLS).';
                                  } else if (fetched.isDeleted) {
                                    diag = 'Pesanan sudah dihapus.';
                                  } else if (session.user != null && fetched.userId != session.user!.id) {
                                    diag = 'Anda tidak berhak menghapus pesanan ini.';
                                  }
                                } catch (e) {
                                  // leave diag as generic
                                }
                                userVisibleMessage = diag;
                              }

                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                content: Row(
                                  children: [
                                    Icon(success ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: Colors.white),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(userVisibleMessage)),
                                  ],
                                ),
                                backgroundColor: success ? Colors.green[600] : Colors.red[600],
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                margin: const EdgeInsets.all(16),
                              ));
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red.withOpacity(0.15), width: 1),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.delete_outline_rounded, size: 14, color: Colors.red[700]),
                                  const SizedBox(width: 6),
                                  Text('Hapus', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red[700])),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    ),
  ),
);
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
}

/// =====================
/// EMPTY STATE
/// =====================
class _EmptyOrderState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.primary.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 64,
                color: AppColors.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Belum ada pesanan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pesanan kamu akan muncul di sini setelah melakukan pemesanan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textGrey,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),

            /// CTA
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: AppColors.primary.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UserShellPage(initialIndex: 0),
                    ),
                    (route) => false,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.restaurant_menu_rounded, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Mulai Pesanan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}