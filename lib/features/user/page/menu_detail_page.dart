import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';
import '/data/models/menu_model.dart';
import '/data/services/cart_service.dart';
import '/data/services/menu_service.dart';
import '/data/models/order_item_model.dart';
import '/core/constants/app_colors.dart';

class MenuDetailPage extends StatefulWidget {
  final MenuModel menu;
  const MenuDetailPage({super.key, required this.menu});

  @override
  State<MenuDetailPage> createState() => _MenuDetailPageState();
}

class _MenuDetailPageState extends State<MenuDetailPage> with SingleTickerProviderStateMixin {
  int _qty = 1;
  bool _isFavorite = false;
  bool _isAddingToCart = false;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  late final StreamSubscription<List<MenuModel>>? _menuSub;
  late MenuModel _menu;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bounceAnimation = CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    );

    // Keep a local copy of the menu so we can update it if server sends changes
    _menu = widget.menu;

    // Subscribe to menu stream for this canteen and update when the menu row changes.
    // Use the canteen-scoped, available menu stream so users remain filtered by canteen and availability.
    try {
      _menuSub = MenuService.instance.streamAvailableMenu(widget.menu.canteenId).listen((menus) {
        try {
          final m = menus.firstWhere((e) => e.id == widget.menu.id, orElse: () => _menu);
          // Update only if changed to avoid unnecessary rebuilds
          if (m.imageUrl != _menu.imageUrl || m.name != _menu.name || m.price != _menu.price || m.isAvailable != _menu.isAvailable) {
            if (mounted) setState(() => _menu = m);
          }
        } catch (_) {}
      });
    } catch (e) {
      // Ignore — stream helper already logs if supabase not ready
      _menuSub = null;
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    try {
      _menuSub?.cancel();
    } catch (_) {}
    super.dispose();
  }

  void _inc() {
    if (_qty < 999) {
      setState(() => _qty++);
      HapticFeedback.lightImpact();
      _bounceController.forward(from: 0);
    } else {
      _showMaxQuantityDialog();
    }
  }

  void _dec() {
    if (_qty > 1) {
      setState(() => _qty--);
      HapticFeedback.lightImpact();
      _bounceController.forward(from: 0);
    }
  }

  void _showMaxQuantityDialog() {
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
        content: const Text('Maximum quantity per order is 999 items.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    HapticFeedback.mediumImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(_isFavorite ? 'Added to favorites' : 'Removed from favorites'),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: _isFavorite ? Colors.red : Colors.grey[800],
      ),
    );
  }

  Future<void> _addToCart() async {
    if (!widget.menu.isAvailable) {
      _showUnavailableDialog();
      return;
    }

    if (_qty < 1 || _qty > 999) {
      _showInvalidQuantityDialog();
      return;
    }

    setState(() => _isAddingToCart = true);
    HapticFeedback.mediumImpact();

    // Simulate network delay for better UX
    await Future.delayed(const Duration(milliseconds: 300));

    // Capture previous qty for undo
    final existing = CartService.instance.items.value
        .where((e) => e.menuId == widget.menu.id)
        .toList();
    final prevQty = existing.isNotEmpty ? existing.first.qty : 0;

    final item = OrderItemModel.fromMenu(widget.menu, qty: _qty);
    CartService.instance.addItem(item);

    setState(() => _isAddingToCart = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ditambahkan ke keranjang',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$_qty × ${widget.menu.name}',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.white,
            onPressed: () {
              if (prevQty == 0) {
                CartService.instance.removeItem(widget.menu.id);
              } else {
                CartService.instance.updateQty(widget.menu.id, prevQty);
              }
              HapticFeedback.lightImpact();
            },
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showUnavailableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange[700]),
            const SizedBox(width: 12),
            const Text('Item Unavailable'),
          ],
        ),
        content: const Text('Sorry, this item is currently unavailable.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showInvalidQuantityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
            const SizedBox(width: 12),
            const Text('Invalid Quantity'),
          ],
        ),
        content: const Text('Please select a valid quantity between 1 and 999.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'makanan':
      case 'food':
        return Icons.restaurant_rounded;
      case 'minuman':
      case 'drink':
      case 'beverage':
        return Icons.local_cafe_rounded;
      case 'snack':
      case 'cemilan':
        return Icons.emoji_food_beverage_rounded;
      case 'dessert':
        return Icons.cake_rounded;
      default:
        return Icons.fastfood_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'makanan':
      case 'food':
        return Colors.orange;
      case 'minuman':
      case 'drink':
      case 'beverage':
        return Colors.blue;
      case 'snack':
      case 'cemilan':
        return Colors.purple;
      case 'dessert':
        return Colors.pink;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = _menu; // use updated local copy
    final total = menu.price * _qty;
    final screenWidth = MediaQuery.of(context).size.width;
    final categoryColor = _getCategoryColor(menu.category);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(math.min(MediaQuery.of(context).textScaleFactor, 1.2)),
        ),
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              /// ================= HERO IMAGE SECTION =================
              Stack(
                children: [
                  // Main Image Container
                  Hero(
                    tag: 'menu-${menu.id}',
                    child: Container(
                      height: math.min(420, MediaQuery.of(context).size.height * 0.40),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            categoryColor.withOpacity(0.1),
                            categoryColor.withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: menu.imageUrl.isNotEmpty
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  menu.imageUrl,
                                  key: ValueKey(menu.imageUrl),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: categoryColor.withOpacity(0.1),
                                    child: Icon(
                                      _getCategoryIcon(menu.category),
                                      size: 80,
                                      color: categoryColor.withOpacity(0.3),
                                    ),
                                  ),
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                        color: categoryColor,
                                      ),
                                    );
                                  },
                                ),
                                // Gradient Overlay
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.0),
                                        Colors.black.withOpacity(0.3),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Center(
                              child: Icon(
                                _getCategoryIcon(menu.category),
                                size: 100,
                                color: categoryColor.withOpacity(0.4),
                              ),
                            ),
                    ),
                  ),

                  // Top Action Buttons
                  Positioned(
                    left: 16,
                    top: 16,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.black, size: 24),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    right: 16,
                    top: 16,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _toggleFavorite,
                        borderRadius: BorderRadius.circular(30),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isFavorite ? Colors.red : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _isFavorite
                                    ? Colors.red.withOpacity(0.4)
                                    : Colors.black.withOpacity(0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(scale: animation, child: child);
                            },
                            child: Icon(
                              _isFavorite ? Icons.favorite : Icons.favorite_border,
                              key: ValueKey(_isFavorite),
                              color: _isFavorite ? Colors.white : Colors.red,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Availability Badge
                  if (!menu.isAvailable)
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Currently Unavailable',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              /// ================= DETAILS CARD SECTION =================
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 20,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag Handle Indicator
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              /// ===== TITLE & CATEGORY =====
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          menu.name,
                                          style: TextStyle(
                                            fontSize: screenWidth < 360 ? 22 : 26,
                                            fontWeight: FontWeight.w900,
                                            height: 1.2,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                categoryColor.withOpacity(0.15),
                                                categoryColor.withOpacity(0.05),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: categoryColor.withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _getCategoryIcon(menu.category),
                                                size: 16,
                                                color: categoryColor,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                menu.category.isNotEmpty
                                                    ? (menu.category[0].toUpperCase() +
                                                        menu.category.substring(1))
                                                    : '-',
                                                style: TextStyle(
                                                  color: categoryColor,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              /// ===== INFO CARDS =====
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInfoCard(
                                      icon: Icons.access_time_rounded,
                                      label: 'Prep Time',
                                      value: '${menu.prepTime} min',
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildInfoCard(
                                      icon: Icons.payments_rounded,
                                      label: 'Price',
                                      value: 'Rp ${menu.price.toStringAsFixed(0)}',
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              /// ===== DESCRIPTION =====
                              Row(
                                children: [
                                  Icon(Icons.description_rounded, size: 20, color: Colors.grey[700]),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Description',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey[900],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Text(
                                  menu.description.isNotEmpty
                                      ? menu.description
                                      : 'No description available.',
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),

                      /// ===== BOTTOM ACTION BAR =====
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, -5),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: Row(
                            children: [
                              /// QUANTITY SELECTOR
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      categoryColor.withOpacity(0.1),
                                      categoryColor.withOpacity(0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: categoryColor.withOpacity(0.2),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _dec,
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          alignment: Alignment.center,
                                          child: Icon(
                                            Icons.remove_rounded,
                                            color: _qty > 1 ? categoryColor : Colors.grey[400],
                                          ),
                                        ),
                                      ),
                                    ),
                                    ScaleTransition(
                                      scale: _bounceAnimation,
                                      child: Container(
                                        constraints: const BoxConstraints(minWidth: 36),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$_qty',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                            color: categoryColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _inc,
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          alignment: Alignment.center,
                                          child: Icon(
                                            Icons.add_rounded,
                                            color: _qty < 999 ? categoryColor : Colors.grey[400],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 12),

                              /// ADD TO CART BUTTON
                              Expanded(
                                child: SizedBox(
                                  height: 56,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: menu.isAvailable
                                          ? categoryColor
                                          : Colors.grey[400],
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shadowColor: categoryColor.withOpacity(0.4),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: menu.isAvailable && !_isAddingToCart
                                        ? _addToCart
                                        : null,
                                    child: _isAddingToCart
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.shopping_cart_rounded, size: 20),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    'Add to cart • Rp ${total.toStringAsFixed(0)}',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}