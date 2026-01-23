import 'package:flutter/material.dart';
import '/core/constants/app_colors.dart';
import '/data/services/menu_service.dart';
import 'admin_menu_form_page.dart';
import '/data/models/menu_model.dart';

class AdminMenuPage extends StatelessWidget {
  const AdminMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final menuService = MenuService.instance;

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final isDesktop = width >= 900;
      final isTablet = width >= 600 && width < 900;
      final horizontalPadding = isDesktop ? 32.0 : 20.0;
      final bottomNavPadding = MediaQuery.of(context).padding.bottom + 80.0;

      return Column(
        children: [
          /// =========================
          /// HEADER
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.restaurant_menu_rounded,
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
                        'Kelola Menu',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Atur menu makanan & minuman',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                FloatingActionButton.small(
                  elevation: 0,
                  backgroundColor: AppColors.primary,
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminMenuFormPage()));
                  },
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
          ),

          /// =========================
          /// MENU LIST
          /// =========================
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: menuService.loading,
              builder: (context, loading, _) {
                if (loading) return const Center(child: CircularProgressIndicator());

                return ValueListenableBuilder<List<MenuModel>>(
                  valueListenable: menuService.menus,
                  builder: (context, menus, _) {
                    // Show only menus that are not soft-deleted
                    final visible = menus.where((m) => !m.isDeleted).toList();
                    if (visible.isEmpty) return _buildEmptyState();

                    if (isDesktop || isTablet) {
                      final cross = isDesktop ? 3 : 2;
                      return GridView.builder(
                        padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, bottomNavPadding),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cross, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 3),
                        itemCount: visible.length,
                        itemBuilder: (context, index) => _buildMenuCard(context, visible[index], menuService),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, bottomNavPadding),
                      itemCount: visible.length,
                      itemBuilder: (context, index) => _buildMenuCard(context, visible[index], menuService),
                    );
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
   * MENU CARD - COMPACT
   * ====================== */
  Widget _buildMenuCard(
    BuildContext context,
    MenuModel menu,
    MenuService menuService,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: menu.isAvailable
              ? AppColors.success.withOpacity(0.2)
              : AppColors.error.withOpacity(0.2),
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
          child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminMenuFormPage(menu: menu)));
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                /// Icon / Image
                menu.imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          menu.imageUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: menu.isAvailable
                                    ? [AppColors.success, AppColors.success.withOpacity(0.7)]
                                    : [AppColors.error, AppColors.error.withOpacity(0.7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 26),
                          ),
                        ),
                      )
                    : Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: menu.isAvailable
                                ? [AppColors.success, AppColors.success.withOpacity(0.7)]
                                : [AppColors.error, AppColors.error.withOpacity(0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.restaurant_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),

                const SizedBox(width: 14),

                /// Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              menu.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: menu.isAvailable
                                      ? AppColors.success.withOpacity(0.1)
                                      : AppColors.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  menu.isAvailable ? 'TERSEDIA' : 'HABIS',
                                  style: TextStyle(
                                    color: menu.isAvailable
                                        ? AppColors.success
                                        : AppColors.error,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),

                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // category
                      if (menu.category.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              menu.category.toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                      // description
                      if (menu.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            menu.description,
                            style: const TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      Row(
                        children: [
                          Icon(
                            Icons.payments_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Rp ${_formatPrice(menu.price)}',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: AppColors.textGrey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${menu.prepTime} menit',
                            style: const TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                /// Toggle Switch
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: menu.isAvailable,
                    onChanged: (value) {
                      menuService.updateAvailability(menu.id, value);
                    },
                    activeThumbColor: AppColors.success,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
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
              Icons.restaurant_menu_rounded,
              size: 64,
              color: AppColors.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Belum Ada Menu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // const Text(
          //   'Tambahkan menu pertama Anda',
          //   style: TextStyle(
          //     color: AppColors.textGrey,
          //     fontSize: 14,
          //   ),
          // ),
          const SizedBox(height: 24),
          // ElevatedButton.icon(
          //   onPressed: () async {
          //     await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminMenuFormPage()));
          //   },
          //   icon: const Icon(Icons.add_rounded),
          //   label: const Text('Tambah Menu'),
          //   style: ElevatedButton.styleFrom(
          //     backgroundColor: AppColors.primary,
          //     foregroundColor: Colors.white,
          //     padding: const EdgeInsets.symmetric(
          //       horizontal: 24,
          //       vertical: 14,
          //     ),
          //     shape: RoundedRectangleBorder(
          //       borderRadius: BorderRadius.circular(12),
          //     ),
          //     elevation: 0,
          //   ),
          // ),
        ],
      ),
    );
  }

  /* ======================
   * HELPERS
   * ====================== */
  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }
}