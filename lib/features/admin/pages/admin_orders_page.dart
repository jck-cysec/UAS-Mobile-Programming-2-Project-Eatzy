import 'package:flutter/material.dart';
import '/core/constants/app_colors.dart';
import '/data/models/order_model.dart';
import '/data/services/order_service.dart';
import '/widgets/countdown_text.dart';

class AdminOrdersPage extends StatefulWidget {
  final OrderService? orderService;
  const AdminOrdersPage({super.key, this.orderService});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  String _filterStatus = 'all';
  // Optimistically hide deleted orders until realtime stream confirms.
  final Set<String> _optimisticRemoved = {};

  @override
  Widget build(BuildContext context) {
    final orderService = widget.orderService ?? OrderService();

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final isDesktop = width >= 900;
      final isTablet = width >= 600 && width < 900;
      final horizontalPadding = isDesktop ? 32.0 : 20.0;
      final bottomNavPadding = MediaQuery.of(context).padding.bottom + 80.0;

      return Column(
        children: [
          /// =========================
          /// HEADER & FILTER
          /// =========================
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kelola Pesanan',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Pantau & update status pesanan',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                /// Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('Semua', 'all'),
                      _filterChip('Pending', 'pending'),
                      _filterChip('Diproses', 'preparing'),
                      _filterChip('Selesai', 'completed'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          /// =========================
          /// ORDER LIST
          /// =========================
          Expanded(
            child: StreamBuilder<List<OrderModel>>(
              stream: orderService.streamOrders(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var orders = snapshot.data!
                    .where((o) => !_optimisticRemoved.contains(o.id))
                    .toList();

                // Apply filter
                if (_filterStatus != 'all') {
                  orders = orders.where((o) => o.status == _filterStatus).toList();
                }

                if (orders.isEmpty) {
                  return _buildEmptyState();
                }

                // On wide screens, show grid of cards, otherwise list
                if (isDesktop || isTablet) {
                  final crossCount = isDesktop ? 2 : 1;
                  return GridView.builder(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, 20,
                        horizontalPadding, bottomNavPadding),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 3,
                    ),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _buildOrderCard(order, orderService);
                    },
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(horizontalPadding, 20,
                      horizontalPadding, bottomNavPadding),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _buildOrderCard(order, orderService);
                  },
                );
              },
            ),
          ),
        ],
      );
    });
  }

  /* ======================
   * FILTER CHIP
   * ====================== */
  Widget _filterChip(String label, String value) {
    final isSelected = _filterStatus == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filterStatus = value;
          });
        },
        backgroundColor: Colors.grey.shade100,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textGrey,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        showCheckmark: false,
      ),
    );
  }

  /* ======================
   * ORDER CARD - COMPACT
   * ====================== */
  Widget _buildOrderCard(OrderModel order, OrderService orderService) {
    // Primary realtime stream remains the real-time source; however, if the
    // stream-provided row lacks joined fields, perform a single authoritative
    // fetch and render the entire card from the resulting OrderModel. This
    // ensures the card always uses a final OrderModel (no per-Text fallbacks).
    return StreamBuilder<OrderModel?>(
      stream: orderService.streamOrderById(order.id),
      builder: (ctx, snap) {
        final enriched = snap.data ?? order;

        final needsFetch = enriched.customerName.isEmpty || enriched.customerName == 'Unknown User' ||
            enriched.paymentMethod.isEmpty || enriched.paymentMethod == 'unknown' ||
            enriched.items.isEmpty;

        if (needsFetch) {
          return FutureBuilder<OrderModel?>(
            future: orderService.fetchOrderById(order.id),
            builder: (fctx, fsnap) {
              final finalOrder = fsnap.data ?? enriched;
              return _orderCardFromModel(finalOrder, orderService);
            },
          );
        }

        return _orderCardFromModel(enriched, orderService);
      },
    );
  }

  // Build the visual card strictly from a final OrderModel. No fallback logic
  // is performed inside this function; it simply renders what it's given.
  Widget _orderCardFromModel(OrderModel order, OrderService orderService) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _statusColor(order.status).withOpacity(0.2),
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
          /// Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _statusColor(order.status).withOpacity(0.05),
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
                    color: _statusColor(order.status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _statusIcon(order.status),
                    color: _statusColor(order.status),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.id.length >= 8 ? order.id.substring(0, 8).toUpperCase() : order.id.toUpperCase()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTime(order.orderTime),
                        style: const TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Show delivery type and address when applicable
                      if (order.deliveryType == 'delivery')
                        Text(
                          'Alamat: ${order.deliveryAddress ?? '-'}',
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(order.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusText(order.status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 16,
                      color: AppColors.textGrey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.customerName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      order.deliveryType.toLowerCase() == 'pickup'
                          ? Icons.shopping_bag_outlined
                          : Icons.delivery_dining_rounded,
                      size: 16,
                      color: AppColors.textGrey,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatDeliveryType(order.deliveryType),
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                // If delivery, show address & shipping fee in compact form
                if (order.deliveryType.toLowerCase() == 'delivery') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textGrey),
                      const SizedBox(width: 8),
                      Expanded(child: Text(order.deliveryAddress ?? '—', style: const TextStyle(fontSize: 12))),
                      const SizedBox(width: 8),
                      Text('Rp ${order.deliveryTip.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                if (order.prepareUntil != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.timelapse, size: 14, color: AppColors.textGrey),
                      const SizedBox(width: 8),
                      const Text('Perkiraan siap: ', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                      CountdownText(target: order.prepareUntil!, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                // Payment method + Delivery tip + Total
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.payment_rounded, size: 14, color: AppColors.textGrey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(order.paymentMethod.isNotEmpty && order.paymentMethod != 'unknown' ? order.paymentMethod : '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Rp ${order.totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          if ((order.deliveryTip) > 0) Text(' + Rp ${order.deliveryTip.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Items list (show up to 5 items inline for quick overview)
                if (order.items.isNotEmpty) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final it in order.items.take(5))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  it.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('${it.qty}x • Rp ${it.price.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              const SizedBox(width: 8),
                              Text('Rp ${it.subtotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      if (order.items.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('+ ${order.items.length - 5} item lainnya', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                const Divider(height: 1),
                const SizedBox(height: 10),

                /// Action Buttons
                Row(
                  children: [
                    if (order.status == 'pending')
                      Expanded(
                        child: _actionButton(
                          label: 'Proses',
                          icon: Icons.play_arrow_rounded,
                          color: Colors.orange,
                          onTap: () async {
                            final success = await orderService.updateOrderStatus(
                              id: order.id,
                              status: 'preparing',
                            );
                            if (!success && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengupdate status. Coba lagi.')));
                            }
                          },
                        ),
                      ),
                    if (order.status == 'preparing') ...[
                      Expanded(
                        child: _actionButton(
                          label: 'Selesai',
                          icon: Icons.check_circle_outline_rounded,
                          color: AppColors.success,
                          onTap: () async {
                            final success = await orderService.updateOrderStatus(
                              id: order.id,
                              status: 'completed',
                            );
                            if (!success && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengupdate status. Coba lagi.')));
                            }
                          },
                        ),
                      ),
                    ],
                    if (order.status != 'completed') ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          _showMoreOptions(context, order, orderService);
                        },
                        icon: const Icon(Icons.more_horiz_rounded, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],

                    // Admin quick-delete for completed/cancelled orders
                    if (order.status == 'completed' || order.status == 'cancelled') ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
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
                              content: const Text(
                                'Pesanan ini akan dihapus dari tampilan dan tidak akan muncul lagi. Data tetap tersimpan di server (soft delete). Tindakan ini tidak dapat dibatalkan.',
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
                              ],
                            ),
                          );

                          if (ok != true) return;
                          final success = await orderService.deleteOrder(order.id);
                          if (success && mounted) {
                            setState(() {
                              _optimisticRemoved.add(order.id);
                            });
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesanan berhasil dihapus')));
                          } else if (!success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menghapus pesanan')));
                          }
                        },
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                    if (order.status == 'completed')
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.success,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Order Selesai',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  /* ======================
   * ACTION BUTTON
   * ====================== */
  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 0,
      ),
    );
  }

  /* ======================
   * MORE OPTIONS
   * ====================== */
  void _showMoreOptions(
    BuildContext context,
    OrderModel order,
    OrderService orderService,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.timelapse, color: Colors.grey),
              title: const Text('Set Pending'),
              onTap: () async {
                final success = await orderService.updateOrderStatus(
                  id: order.id,
                  status: 'pending',
                );
                Navigator.pop(context);
                if (!success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengupdate status. Coba lagi.')));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow, color: Colors.orange),
              title: const Text('Set Preparing'),
              onTap: () async {
                final success = await orderService.updateOrderStatus(
                  id: order.id,
                  status: 'preparing',
                );
                Navigator.pop(context);
                if (!success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengupdate status. Coba lagi.')));
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.check_circle, color: AppColors.success),
              title: const Text('Set Completed'),
              onTap: () async {
                final success = await orderService.updateOrderStatus(
                  id: order.id,
                  status: 'completed',
                );
                Navigator.pop(context);
                if (!success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengupdate status. Coba lagi.')));
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Hapus Pesanan'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
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
                    content: const Text(
                      'Pesanan ini akan dihapus dari tampilan dan tidak akan muncul lagi. Data tetap tersimpan di server (soft delete). Tindakan ini tidak dapat dibatalkan.',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
                    ],
                  ),
                );

                if (ok != true) return;
                Navigator.pop(context);
                final success = await orderService.deleteOrder(order.id);
                if (success && mounted) {
                  setState(() {
                    _optimisticRemoved.add(order.id);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesanan berhasil dihapus')));
                } else if (!success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menghapus pesanan')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /* ======================
   * EMPTY STATE
   * ====================== */
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inbox_rounded,
              size: 64,
              color: AppColors.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Tidak Ada Pesanan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filterStatus == 'all'
                ? 'Belum ada pesanan masuk'
                : 'Tidak ada pesanan dengan status ini',
            style: const TextStyle(
              color: AppColors.textGrey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /* ======================
   * HELPERS
   * ====================== */
  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'preparing':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle_rounded;
      case 'preparing':
        return Icons.restaurant_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'completed':
        return 'SELESAI';
      case 'preparing':
        return 'DIPROSES';
      default:
        return 'PENDING';
    }
  }

  String _formatDeliveryType(String type) {
    switch (type.toLowerCase()) {
      case 'pickup':
        return 'Ambil Sendiri';
      case 'delivery':
        return 'Diantar';
      default:
        return type.toUpperCase();
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}