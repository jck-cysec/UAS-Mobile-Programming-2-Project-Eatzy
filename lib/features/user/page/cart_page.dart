import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '/data/services/cart_service.dart';
import '/data/models/order_item_model.dart';
import '/data/services/menu_service.dart';
import 'payment_page.dart';
import '/state/session_provider.dart';
import '/core/constants/app_colors.dart';

class CartPage extends StatefulWidget {
  final VoidCallback? onNavigateToHome;
  
  const CartPage({super.key, this.onNavigateToHome});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> with TickerProviderStateMixin {
  static const double _shellBottomSpace = 30;
  bool _isCheckingOut = false;
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _showSnack(BuildContext context, String msg, {bool isError = false}) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(msg)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red : AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleCheckout(BuildContext context, CartService cart) async {
    if (_isCheckingOut) return;

    final session = Provider.of<SessionProvider>(context, listen: false);

    if (!session.isLoggedIn) {
      _showSnack(context, 'Harap login terlebih dahulu', isError: true);
      return;
    }

    if (cart.items.value.isEmpty) {
      _showSnack(context, 'Keranjang masih kosong', isError: true);
      return;
    }

    final hasInvalidQty = cart.items.value.any((i) => i.qty <= 0 || i.qty > 999);
    if (hasInvalidQty) {
      _showSnack(context, 'Jumlah item tidak valid', isError: true);
      return;
    }

    setState(() => _isCheckingOut = true);
    HapticFeedback.mediumImpact();

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    final toRemove = <String>[];
    for (final it in cart.items.value) {
      final latest = await MenuService.instance.fetchMenuById(it.menuId);
      if (latest == null || !latest.isAvailable) {
        toRemove.add(it.menuId);
      }
    }

    if (toRemove.isNotEmpty) {
      for (final id in toRemove) {
        cart.removeItem(id);
      }
      setState(() => _isCheckingOut = false);
      _showSnack(
        context,
        '${toRemove.length} item tidak tersedia dan telah dihapus',
        isError: true,
      );
      return;
    }

    final total = cart.getTotal();
    if (total <= 0) {
      setState(() => _isCheckingOut = false);
      _showSnack(context, 'Total tidak valid', isError: true);
      return;
    }

    setState(() => _isCheckingOut = false);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPage(items: cart.items.value, total: total),
        ),
      );
    }
  }

  void _updateQuantity(CartService cart, String menuId, int newQty) {
    if (newQty < 1) {
      cart.removeItem(menuId);
    } else if (newQty <= 999) {
      cart.updateQty(menuId, newQty);
      HapticFeedback.lightImpact();
      _bounceController.forward(from: 0);
    } else {
      _showMaxQuantityDialog();
    }
  }

  void _showMaxQuantityDialog() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text('Maximum Quantity'),
          ],
        ),
        content: const Text('Maximum quantity per item is 999.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToHome() {
    HapticFeedback.lightImpact();
    if (widget.onNavigateToHome != null) {
      widget.onNavigateToHome!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartService.instance;
    final screenWidth = MediaQuery.of(context).size.width;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaleFactor: math.min(MediaQuery.of(context).textScaleFactor, 1.2),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: ValueListenableBuilder<List<OrderItemModel>>(
          valueListenable: cart.items,
          builder: (context, items, _) {
            /// ================= EMPTY STATE =================
            if (items.isEmpty) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(40),
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
                          Icons.shopping_cart_outlined,
                          size: 80,
                          color: AppColors.primary.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Keranjang Kosong',
                        style: TextStyle(
                          fontSize: screenWidth < 360 ? 20 : 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tambahkan menu favoritmu sekarang',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _navigateToHome,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.restaurant_menu_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Lihat menu di bawah',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            /// ================= CONTENT =================
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// HEADER
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.15),
                                AppColors.primary.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.shopping_cart_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Keranjang Saya',
                          style: TextStyle(
                            fontSize: screenWidth < 360 ? 18 : 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey[900],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// LIST ITEM
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final it = items[index];

                        return Dismissible(
                          key: ValueKey(it.menuId),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) async {
                            HapticFeedback.mediumImpact();
                            return await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    title: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.red,
                                        ),
                                        const SizedBox(width: 12),
                                        const Text('Hapus Item?'),
                                      ],
                                    ),
                                    content: Text(
                                      'Apakah Anda yakin ingin menghapus "${it.name}" dari keranjang?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: Text(
                                          'Batal',
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          HapticFeedback.mediumImpact();
                                          Navigator.pop(ctx, true);
                                        },
                                        child: const Text(
                                          'Hapus',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.red[400]!,
                                  Colors.red[600]!,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.delete_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Hapus',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          onDismissed: (_) {
                            final removed = it;
                            cart.removeItem(it.menuId);
                            HapticFeedback.mediumImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text('${removed.name} telah dihapus'),
                                    ),
                                  ],
                                ),
                                action: SnackBarAction(
                                  label: 'UNDO',
                                  textColor: Colors.white,
                                  onPressed: () {
                                    cart.addItem(removed);
                                    HapticFeedback.lightImpact();
                                  },
                                ),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  /// IMAGE
                                  Hero(
                                    tag: 'cart-${it.menuId}',
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: it.imageUrl.isNotEmpty
                                          ? Image.network(
                                              it.imageUrl,
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                width: 80,
                                                height: 80,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      AppColors.primary.withOpacity(0.2),
                                                      AppColors.primary.withOpacity(0.1),
                                                    ],
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.fastfood_rounded,
                                                  color: AppColors.primary,
                                                  size: 32,
                                                ),
                                              ),
                                            )
                                          : Container(
                                              width: 80,
                                              height: 80,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    AppColors.primary.withOpacity(0.2),
                                                    AppColors.primary.withOpacity(0.1),
                                                  ],
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.fastfood_rounded,
                                                color: AppColors.primary,
                                                size: 32,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  /// DETAILS
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          it.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            height: 1.3,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Rp ${it.price.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        /// QUANTITY CONTROLS
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppColors.primary.withOpacity(0.1),
                                                AppColors.primary.withOpacity(0.05),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: AppColors.primary.withOpacity(0.2),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () => _updateQuantity(
                                                    cart,
                                                    it.menuId,
                                                    it.qty - 1,
                                                  ),
                                                  borderRadius: BorderRadius.circular(10),
                                                  child: Container(
                                                    width: 36,
                                                    height: 36,
                                                    alignment: Alignment.center,
                                                    child: Icon(
                                                      it.qty <= 1
                                                          ? Icons.delete_outline_rounded
                                                          : Icons.remove_rounded,
                                                      color: it.qty <= 1
                                                          ? Colors.red
                                                          : AppColors.primary,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                constraints: const BoxConstraints(minWidth: 32),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  '${it.qty}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 15,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                              Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: it.qty < 999
                                                      ? () => _updateQuantity(
                                                            cart,
                                                            it.menuId,
                                                            it.qty + 1,
                                                          )
                                                      : () => _showMaxQuantityDialog(),
                                                  borderRadius: BorderRadius.circular(10),
                                                  child: Container(
                                                    width: 36,
                                                    height: 36,
                                                    alignment: Alignment.center,
                                                    child: Icon(
                                                      Icons.add_rounded,
                                                      color: it.qty < 999
                                                          ? AppColors.primary
                                                          : Colors.grey[400],
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  /// SUBTOTAL
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Subtotal',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Rp ${(it.price * it.qty).toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  /// ================= CHECKOUT BAR =================
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Colors.grey[50]!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.receipt_long_rounded,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Total Pembayaran',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Rp ${cart.getTotal().toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: screenWidth < 360 ? 20 : 24,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed:
                                  _isCheckingOut ? null : () => _handleCheckout(context, cart),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey[300],
                                elevation: 0,
                                shadowColor: AppColors.primary.withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                              ),
                              child: _isCheckingOut
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.shopping_bag_rounded, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Checkout',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const SizedBox(height: _shellBottomSpace),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}