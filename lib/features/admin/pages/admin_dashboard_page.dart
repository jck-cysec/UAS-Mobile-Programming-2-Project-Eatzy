import 'package:flutter/material.dart';
import '/core/constants/app_colors.dart';
import '/data/services/order_service.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orderService = OrderService();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= 900;
        final horizontalPadding = isDesktop ? 32.0 : 20.0;
        final bottomNavPadding = MediaQuery.of(context).padding.bottom + 80.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            bottomNavPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              /// =========================
              /// HEADER WITH GRADIENT
              /// =========================
              _buildHeader(),

              const SizedBox(height: 50),

              /// =========================
              /// REALTIME STATS
              /// =========================
              StreamBuilder<Map<String, dynamic>>(
                stream: orderService.streamDashboardStats(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final data = snapshot.data!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Statistik Real-Time',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(builder: (context, gridConstraints) {
                        int crossAxisCount = 2;
                        double childAspect = 1.5;
                        
                        if (gridConstraints.maxWidth >= 1100) {
                          crossAxisCount = 4;
                          childAspect = 1.2;
                        } else if (gridConstraints.maxWidth >= 800) {
                          crossAxisCount = 3;
                          childAspect = 1.3;
                        } else if (gridConstraints.maxWidth >= 600) {
                          crossAxisCount = 2;
                          childAspect = 1.4;
                        } else if (gridConstraints.maxWidth >= 400) {
                          crossAxisCount = 2;
                          childAspect = 1.5;
                        } else {
                          // Very small screens
                          crossAxisCount = 2;
                          childAspect = 1.3;
                        }

                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: childAspect,
                          children: [
                            _statCard(
                              title: 'Total Order',
                              value: data['total'] ?? 0,
                              icon: Icons.receipt_long_rounded,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primary.withOpacity(0.7)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            _statCard(
                              title: 'Pending',
                              value: data['pending'] ?? 0,
                              icon: Icons.schedule_rounded,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.orange.shade400,
                                  Colors.orange.shade600
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            _statCard(
                              title: 'Selesai',
                              value: data['completed'] ?? 0,
                              icon: Icons.check_circle_rounded,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.success,
                                  AppColors.success.withOpacity(0.7)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            _statCard(
                              title: 'Hari Ini',
                              value: _todayCount(
                                  (data['daily'] ?? {}) as Map<String, int>),
                              icon: Icons.today_rounded,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple.shade400,
                                  Colors.purple.shade600
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  );
                },
              ),

              const SizedBox(height: 5),

              /// =========================
              /// CHART SECTION
              /// =========================
              _buildChartSection(),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /* ======================
   * HEADER WITH GRADIENT
   * ====================== */
  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    String greeting = 'Selamat Pagi';
    IconData greetingIcon = Icons.wb_sunny_rounded;

    if (hour >= 12 && hour < 15) {
      greeting = 'Selamat Siang';
      greetingIcon = Icons.wb_sunny_rounded;
    } else if (hour >= 15 && hour < 18) {
      greeting = 'Selamat Sore';
      greetingIcon = Icons.wb_twilight_rounded;
    } else if (hour >= 18 || hour < 5) {
      greeting = 'Selamat Malam';
      greetingIcon = Icons.nights_stay_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
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
                      greetingIcon,
                      color: Colors.white.withOpacity(0.9),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      greeting,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Dashboard Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pantau aktivitas kantin secara real-time',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  /* ======================
   * STAT CARD - COMPACT & RESPONSIVE
   * ====================== */
  Widget _statCard({
    required String title,
    required int value,
    required IconData icon,
    required Gradient gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background icon
          Positioned(
            right: -8,
            bottom: -8,
            child: Icon(
              icon,
              size: 64,
              color: Colors.white.withOpacity(0.12),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.toString(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
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
   * CHART SECTION
   * ====================== */
  Widget _buildChartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.bar_chart_rounded,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Grafik Order 7 Hari Terakhir',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.analytics_outlined,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Grafik Segera Hadir',
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Fitur visualisasi data dalam pengembangan',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textGrey.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /* ======================
   * HELPER
   * ====================== */
  int _todayCount(Map<String, int> daily) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return daily[today] ?? 0;
  }
}