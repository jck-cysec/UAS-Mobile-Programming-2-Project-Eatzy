import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/data/services/menu_service.dart';
import '/data/models/menu_model.dart';
import '/features/user/page/menu_detail_page.dart';
import '/core/constants/app_colors.dart';
import '/state/session_provider.dart';
import 'profiles/help/help_about_page.dart';
import 'profiles/help/help_faq_page.dart';
import 'profiles/transactions_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedCategory = 'all';
  final GlobalKey _menuSectionKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  // UX ENHANCEMENT (state tambahan, tidak mengubah logic)
  int _pressedQuickAction = -1;
  int _hoveredMenuIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi';
    if (hour < 17) return 'Selamat Siang';
    return 'Selamat Malam';
  }

  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return Icons.wb_sunny_outlined;
    if (hour < 17) return Icons.wb_sunny_rounded;
    return Icons.nightlight_round_outlined;
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

  double _getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 32.0;
    if (width >= 900) return 24.0;
    if (width >= 600) return 20.0;
    return 16.0;
  }

  double _getResponsiveFontSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return baseSize * 0.9;
    if (width >= 600) return baseSize * 1.05;
    return baseSize;
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context);
    final service = MenuService.instance;
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = _getResponsivePadding(context);

    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            /// ================= HEADER =================
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  horizontalPadding,
                  horizontalPadding,
                  0,
                ),
                child: Container(
                  padding: EdgeInsets.all(screenWidth < 360 ? 16 : 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getGreetingIcon(),
                                  color: Colors.white,
                                  size: screenWidth < 360 ? 18 : 20,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _getGreeting(),
                                    style: TextStyle(
                                      fontSize:
                                          _getResponsiveFontSize(context, 13),
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Hey, ${session.displayName.split(' ').first}!',
                              style: TextStyle(
                                fontSize:
                                    _getResponsiveFontSize(context, 24),
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Mau makan apa hari ini?',
                              style: TextStyle(
                                fontSize:
                                    _getResponsiveFontSize(context, 13),
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            /// ================= QUICK ACTION =================
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  horizontalPadding,
                  horizontalPadding,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionCard(
                        icon: Icons.help_outline_rounded,
                        title: 'FAQ',
                        subtitle: 'Bantuan',
                        gradient:
                            const LinearGradient(colors: AppColors.gradientFAQ),
                        index: 0,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HelpFaqPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionCard(
                        icon: Icons.info_outline_rounded,
                        title: 'Tentang',
                        subtitle: 'Aplikasi',
                        gradient: const LinearGradient(
                            colors: AppColors.gradientAbout),
                        index: 1,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HelpAboutPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionCard(
                        icon: Icons.receipt_long_rounded,
                        title: 'Transaksi',
                        subtitle: 'History',
                        gradient: const LinearGradient(
                            colors: AppColors.gradientTransaction),
                        index: 2,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TransactionsPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            /// ================= MENU =================
            SliverToBoxAdapter(
              key: _menuSectionKey,
              child: StreamBuilder<List<MenuModel>>(
                stream: service.streamAvailableAll(),
                builder: (context, snapshot) {
                  // UX ENHANCEMENT: Skeleton Loading Grid
                  if (!snapshot.hasData) {
                    return Padding(
                      padding: EdgeInsets.all(horizontalPadding),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 6,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.72,
                        ),
                        itemBuilder: (_, __) => Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius:
                                        const BorderRadius.vertical(
                                      top: Radius.circular(24),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        height: 14,
                                        width: double.infinity,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        height: 12,
                                        width: 80,
                                        color: Colors.grey.shade200,
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

                  final menus = snapshot.data!;
                  final categories = <String>{
                    'all',
                    ...menus.map((m) => m.category)
                  }.toList();

                  final visible = _selectedCategory == 'all'
                      ? menus
                      : menus
                          .where((m) => m.category == _selectedCategory)
                          .toList();

                  return Padding(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All Menu',
                          style: TextStyle(
                            fontSize:
                                _getResponsiveFontSize(context, 18),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        /// CATEGORY CHIP
                        SizedBox(
                          height: 48,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (_, i) {
                              final c = categories[i];
                              final isSelected = c == _selectedCategory;

                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedCategory = c),
                                child: AnimatedScale(
                                  // UX ENHANCEMENT
                                  scale: isSelected ? 1.0 : 0.97,
                                  duration:
                                      const Duration(milliseconds: 120),
                                  curve: Curves.easeOutBack,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: isSelected
                                          ? LinearGradient(
                                              colors: [
                                                AppColors.primary,
                                                AppColors.primary
                                                    .withOpacity(0.85),
                                              ],
                                            )
                                          : null,
                                      color:
                                          isSelected ? null : Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isSelected
                                              ? AppColors.primary
                                                  .withOpacity(0.35)
                                              : Colors.black
                                                  .withOpacity(0.05),
                                          blurRadius:
                                              isSelected ? 14 : 8,
                                          offset: Offset(
                                              0, isSelected ? 6 : 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          c == 'all'
                                              ? Icons.grid_view_rounded
                                              : _getCategoryIcon(c),
                                          size: 18,
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.textGrey,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          c == 'all'
                                              ? 'All'
                                              : c[0].toUpperCase() +
                                                  c.substring(1),
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : AppColors.textGrey,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// GRID MENU - ENHANCED UI
                        GridView.builder(
                          shrinkWrap: true,
                          physics:
                              const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: visible.length,
                          itemBuilder: (ctx, idx) {
                            final m = visible[idx];
                            final cardGradient = AppColors.cardGradients[
                                idx % AppColors.cardGradients.length];

                            return MouseRegion(
                              onEnter: (_) =>
                                  setState(() => _hoveredMenuIndex = idx),
                              onExit: (_) =>
                                  setState(() => _hoveredMenuIndex = -1),
                              child: GestureDetector(
                                onTapDown: (_) =>
                                    setState(() => _hoveredMenuIndex = idx),
                                onTapCancel: () =>
                                    setState(() => _hoveredMenuIndex = -1),
                                onTapUp: (_) =>
                                    setState(() => _hoveredMenuIndex = -1),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          MenuDetailPage(menu: m),
                                    ),
                                  );
                                },
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                  transform:
                                      Matrix4.translationValues(
                                    0,
                                    _hoveredMenuIndex == idx ? -8 : 0,
                                    0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _hoveredMenuIndex == idx
                                            ? cardGradient[0].withOpacity(0.3)
                                            : Colors.black.withOpacity(0.08),
                                        blurRadius: _hoveredMenuIndex == idx ? 24 : 12,
                                        offset: Offset(0, _hoveredMenuIndex == idx ? 12 : 6),
                                        spreadRadius: _hoveredMenuIndex == idx ? 2 : 0,
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      Column(
                                        children: [
                                          // Image Section dengan Gradient Overlay
                                          Expanded(
                                            flex: 3,
                                            child: Stack(
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                      colors: [
                                                        cardGradient[0].withOpacity(0.25),
                                                        cardGradient[1].withOpacity(0.15),
                                                      ],
                                                    ),
                                                    borderRadius:
                                                        const BorderRadius.vertical(
                                                      top: Radius.circular(24),
                                                    ),
                                                  ),
                                                ),
                                                // Decorative Pattern
                                                Positioned(
                                                  top: -20,
                                                  right: -20,
                                                  child: Container(
                                                    width: 100,
                                                    height: 100,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      gradient: RadialGradient(
                                                        colors: [
                                                          cardGradient[0].withOpacity(0.2),
                                                          cardGradient[0].withOpacity(0.0),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                // Image or Icon Display (show image if available)
                                                Center(
                                                  child: Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.9),
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: cardGradient[0].withOpacity(0.2),
                                                          blurRadius: 16,
                                                          spreadRadius: 2,
                                                        ),
                                                      ],
                                                    ),
                                                    child: m.imageUrl.isNotEmpty
                                                        ? ClipOval(
                                                            child: SizedBox(
                                                              width: 72,
                                                              height: 72,
                                                              child: Image.network(
                                                                m.imageUrl,
                                                                key: ValueKey(m.imageUrl),
                                                                fit: BoxFit.cover,
                                                                errorBuilder: (_, __, ___) => Container(
                                                                  color: Colors.white,
                                                                  child: Icon(
                                                                    _getCategoryIcon(m.category),
                                                                    size: 36,
                                                                    color: cardGradient[0],
                                                                  ),
                                                                ),
                                                                loadingBuilder: (ctx, child, progress) {
                                                                  if (progress == null) return child;
                                                                  return Center(
                                                                    child: CircularProgressIndicator(
                                                                      value: progress.expectedTotalBytes != null
                                                                          ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                                                          : null,
                                                                      color: cardGradient[0],
                                                                    ),
                                                                  );
                                                                },
                                                              ),
                                                            ),
                                                          )
                                                        : Icon(
                                                            _getCategoryIcon(m.category),
                                                            size: 36,
                                                            color: cardGradient[0],
                                                          ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Info Section
                                          Expanded(
                                            flex: 2,
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: const BoxDecoration(
                                                borderRadius: BorderRadius.vertical(
                                                  bottom: Radius.circular(24),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.spaceBetween,
                                                children: [
                                                  // Name
                                                  Text(
                                                    m.name,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 15,
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                  // Price Section
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.spaceBetween,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              'Price',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                color: AppColors.textGrey.withOpacity(0.7),
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                            const SizedBox(height: 2),
                                                            Text(
                                                              'Rp ${m.price.toStringAsFixed(0)}',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight.w900,
                                                                fontSize: 14,
                                                                color:
                                                                    cardGradient[0],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      // Order Button
                                                      Container(
                                                        padding: const EdgeInsets.all(8),
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            colors: cardGradient,
                                                          ),
                                                          borderRadius: BorderRadius.circular(12),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: cardGradient[0].withOpacity(0.4),
                                                              blurRadius: 8,
                                                              offset: const Offset(0, 4),
                                                            ),
                                                          ],
                                                        ),
                                                        child: const Icon(
                                                          Icons.add_shopping_cart_rounded,
                                                          color: Colors.white,
                                                          size: 18,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Category Badge
                                      Positioned(
                                        top: 12,
                                        left: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.1),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _getCategoryIcon(m.category),
                                                size: 12,
                                                color: cardGradient[0],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                m.category[0].toUpperCase() +
                                                    m.category.substring(1),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: cardGradient[0],
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
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
    required int index,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTapDown: (_) =>
            setState(() => _pressedQuickAction = index),
        onTapCancel: () =>
            setState(() => _pressedQuickAction = -1),
        onTap: () {
          setState(() => _pressedQuickAction = -1);
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedScale(
          // UX ENHANCEMENT
          scale: _pressedQuickAction == index ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutBack,
          child: Container(
            padding:
                const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color:
                      gradient.colors.first.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}