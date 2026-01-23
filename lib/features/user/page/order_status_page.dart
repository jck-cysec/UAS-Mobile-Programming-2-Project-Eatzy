import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '/state/session_provider.dart';
import '/data/services/order_service.dart';
import '/data/models/order_model.dart';
import '/core/constants/app_colors.dart';
import '/widgets/countdown_text.dart';

class OrderStatusPage extends StatelessWidget {
  final String orderId;
  const OrderStatusPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final service = OrderService();


    return Scaffold(
      backgroundColor: AppColors.background,
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
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: Colors.white,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Status Pesanan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
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
      body: StreamBuilder<OrderModel?>(
        stream: service.streamOrderById(orderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final o = snapshot.data;
          if (o == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('Pesanan tidak ditemukan', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                  ],
                ),
              ),
            );
          }

          final statusColor = _statusColor(o.status);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// ===== ORDER HEADER CARD =====
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor.withOpacity(0.1),
                        statusColor.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.2), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order #${o.id.substring(0, 8).toUpperCase()}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatDateTime(o.orderTime),
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  statusColor,
                                  statusColor.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: statusColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              o.status.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (o.prepareUntil != null) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.timelapse_rounded, size: 18, color: statusColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Perkiraan Siap',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  CountdownText(
                                    target: o.prepareUntil!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ===== CUSTOMER & PAYMENT (enrich if realtime row lacks info)
                      Row(
                        children: [
                          Expanded(
                            child: FutureBuilder<OrderModel?>(
                              future: (o.customerName == 'Unknown User') ? OrderService().fetchOrderById(o.id) : Future.value(o),
                              builder: (ctx, snap) {
                                final enriched = snap.data ?? o;
                                final displayName = (enriched.customerName.isNotEmpty && enriched.customerName != 'Unknown User')
                                    ? enriched.customerName
                                    : Provider.of<SessionProvider>(context, listen: false).displayName;

                                return Row(
                                  children: [
                                    Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey[700]),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FutureBuilder<OrderModel?>(
                              future: (o.paymentMethod == 'unknown' || o.paymentMethod.isEmpty) ? OrderService().fetchOrderById(o.id) : Future.value(o),
                              builder: (ctx, snap) {
                                final enriched = snap.data ?? o;
                                final pm = (enriched.paymentMethod.isNotEmpty && enriched.paymentMethod != 'unknown') ? enriched.paymentMethod : '—';

                                return Row(
                                  children: [
                                    Icon(Icons.payment_rounded, size: 14, color: Colors.grey[700]),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        pm,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                    ],
                  ),
                ),

                const SizedBox(height: 24),

                /// ===== ORDER DETAILS =====
                Row(
                  children: [
                    Icon(Icons.shopping_cart_checkout_rounded, size: 20, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Detail Pesanan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                /// ===== ITEMS LIST =====
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: List.generate(
                      o.items.length,
                      (i) {
                        final it = o.items[i];
                        final isLast = i == o.items.length - 1;
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  if (it.imageUrl.isNotEmpty)
                                    Hero(
                                      tag: 'item-${it.id}',
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          it.imageUrl,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(Icons.fastfood_rounded, color: Colors.grey[400]),
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(Icons.fastfood_rounded, color: Colors.grey[400]),
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          it.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${it.qty}x • Rp ${it.price.toStringAsFixed(0)}',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primary.withOpacity(0.1),
                                          AppColors.primary.withOpacity(0.05),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Rp ${it.subtotal.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isLast) Divider(height: 1, color: Colors.grey[200]),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// ===== ORDER SUMMARY =====
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.08),
                        AppColors.primary.withOpacity(0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subtotal', style: TextStyle(color: Colors.grey[700])),
                          Text('Rp ${o.subtotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if ((o.deliveryTip) > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Biaya Pengiriman', style: TextStyle(color: Colors.grey[700])),
                            Text('Rp ${o.deliveryTip.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Pesanan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.grey[900])),
                          Text('Rp ${o.totalPrice.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primary)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                /// ===== PAYMENT & DELIVERY INFO =====
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Metode Bayar',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              o.paymentMethod.isNotEmpty ? o.paymentMethod : '—',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pengiriman',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              o.deliveryType.replaceFirst(o.deliveryType[0], o.deliveryType[0].toUpperCase()),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                /// ===== CANCEL BUTTON =====
                if (o.status == 'pending')
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade500,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        shadowColor: Colors.red.withOpacity(0.3),
                      ),
                      onPressed: () => _showCancelDialog(context),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text(
                        'Batalkan Pesanan',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 12),
            const Text('Batalkan Pesanan'),
          ],
        ),
        content: const Text('Pesanan akan dibatalkan dan tidak dapat dikembalikan. Lanjutkan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await OrderService().cancelOrder(orderId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(success ? Icons.check_circle : Icons.error, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(success ? 'Pesanan dibatalkan' : 'Gagal membatalkan pesanan'),
                      ],
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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
        return Colors.grey;
    }
  }
}
