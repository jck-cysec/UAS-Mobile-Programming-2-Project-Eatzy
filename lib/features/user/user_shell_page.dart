import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

import '../user/page/home_page.dart';
import 'page/cart_page.dart';
import '../user/page/profiles/profile_page.dart';

import '/data/services/cart_service.dart';
import '/core/constants/app_colors.dart';

class UserShellPage extends StatefulWidget {
  final int initialIndex;
  const UserShellPage({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<UserShellPage> createState() => _UserShellPageState();
}

class _UserShellPageState extends State<UserShellPage> {
  int _index = 0;
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();

  late final List<Widget> _pages;

  final _labels = ['Home', 'Cart', 'Profile'];

  @override
  void initState() {
    super.initState();

    // Set initial index from constructor (clamped)
    _index = (widget.initialIndex >= 0 && widget.initialIndex < 3) ? widget.initialIndex : 0;

    /// ✅ HANYA 3 PAGE
    _pages = const [
      HomePage(),
      CartPage(),
      ProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final isTiny = width < 360;

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,

      // ===================== APP BAR =====================
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: SafeArea(
          bottom: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                /// LOGO
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.restaurant_menu_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Eatzy',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (!isTiny)
                            Text(
                              'Yuk Makan!',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // ===================== BODY =====================
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),

      // ===================== BOTTOM NAV =====================
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CurvedNavigationBar(
            key: _bottomNavigationKey,
            index: _index,
            height: 60,
            items: [
              const Icon(Icons.home_rounded, size: 28),
              _cartNavItem(),
              const Icon(Icons.person_rounded, size: 28),
            ],
            color: Colors.white,
            buttonBackgroundColor: AppColors.primary,
            backgroundColor: Colors.transparent,
            animationCurve: Curves.easeInOut,
            animationDuration: const Duration(milliseconds: 400),
            onTap: (index) => setState(() => _index = index),
          ),

          /// LABEL
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: SafeArea(
              top: false,
              child: Row(
                children: List.generate(
                  _labels.length,
                  (i) => Expanded(
                    child: Text(
                      _labels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            _index == i ? FontWeight.w700 : FontWeight.w500,
                        color: _index == i
                            ? AppColors.primary
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== CART BADGE =====================
  Widget _cartNavItem() {
    return ValueListenableBuilder<List>(
      valueListenable: CartService.instance.items,
      builder: (_, items, __) {
        return _NavBadgeIcon(
          icon: Icons.shopping_cart_rounded,
          count: items.length,
          color: Colors.red,
        );
      },
    );
  }
}

/// ===================== BADGE ICON =====================
class _NavBadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;

  const _NavBadgeIcon({
    required this.icon,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(icon, size: 28),
        if (count > 0)
          Positioned(
            right: 0,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
