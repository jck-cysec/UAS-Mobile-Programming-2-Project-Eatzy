import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'pages/admin_dashboard_page.dart';
import 'pages/admin_orders_page.dart';
import 'pages/admin_menu_page.dart';
import 'pages/admin_profile_page.dart';
import '/core/constants/app_colors.dart';

class AdminShellPage extends StatefulWidget {
  const AdminShellPage({super.key});

  @override
  State<AdminShellPage> createState() => _AdminShellPageState();
}

class _AdminShellPageState extends State<AdminShellPage> {
  int _index = 0;
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();

  final _pages = const [
    AdminDashboardPage(),
    AdminOrdersPage(),
    AdminMenuPage(),
    AdminProfilePage(),
  ];

  final _labels = ['Dashboard', 'Orders', 'Menu', 'Profile'];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final isTiny = width < 360;
    final isSmall = width < 420;
    final isMobile = width < 720;

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
                /// ================= LOGO + TITLE =================
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
                        child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      if (!isTiny)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                'Eatzy Admin',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Kelola kantin Anda',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // 🔔 Notifications (tetap ada)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.notifications_none_rounded),
                      tooltip: 'Notifications',
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
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
            items: const [
              Icon(Icons.dashboard_rounded, size: 28),
              Icon(Icons.receipt_long_rounded, size: 28),
              Icon(Icons.restaurant_menu_rounded, size: 28),
              Icon(Icons.person_rounded, size: 28),
            ],
            color: Colors.white,
            buttonBackgroundColor: AppColors.primary,
            backgroundColor: Colors.transparent,
            animationCurve: Curves.easeInOut,
            animationDuration: const Duration(milliseconds: 400),
            onTap: (index) => setState(() => _index = index),
          ),

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
                        fontWeight: _index == i ? FontWeight.w700 : FontWeight.w500,
                        color: _index == i ? AppColors.primary : Colors.grey[600],
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

  // ===================== SEARCH DIALOG =====================
  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cari'),
        content: const TextField(
          decoration: InputDecoration(
            hintText: 'Cari order, menu, pelanggan...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
