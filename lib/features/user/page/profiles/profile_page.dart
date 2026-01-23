import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '/state/session_provider.dart';
import '/core/constants/app_colors.dart';
import '/features/user/page/profiles/order_history_page.dart';
import '/features/user/page/profiles/edit_profile_page.dart';
import '/features/user/page/profiles/transactions_page.dart';
import '/features/auth/login/login_page.dart';

// Help pages
import 'help/help_faq_page.dart';
import 'help/help_privacy_page.dart';
import 'help/help_terms_page.dart';
import 'help/help_about_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const double _shellBottomSpace = 140;

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return SafeArea(
      top: false,
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// ================= GLASSMORPHIC HEADER CARD =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  screenWidth < 360 ? 22 : 28,
                  20,
                  screenWidth < 360 ? 22 : 28,
                ),
                decoration: BoxDecoration(
                  /// Glassmorphic base
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    /// Outer shadow
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                    /// Inner light glow
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(-3, -3),
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    /// Profile Avatar with Gradient Ring
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        /// Gradient ring background
                        Container(
                          width: screenWidth < 360 ? 90 : 100,
                          height: screenWidth < 360 ? 90 : 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary.withOpacity(0.4),
                                AppColors.primary.withOpacity(0.15),
                              ],
                            ),
                          ),
                        ),
                        /// Avatar
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 2.5,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: screenWidth < 360 ? 36 : 42,
                            backgroundColor: AppColors.primary.withOpacity(0.25),
                            child: Icon(
                              Icons.person_rounded,
                              size: screenWidth < 360 ? 34 : 40,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    /// Name
                    Text(
                      session.displayName,
                      style: TextStyle(
                        fontSize: screenWidth < 360 ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),

                    /// Email
                    Text(
                      session.user?.email ?? '-',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            /// Content
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                24,
                16,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  /// ================= ACCOUNT SECTION =================
                  _sectionTitle('Akun'),
                  const SizedBox(height: 12),
                  _buildAnimatedCard(
                    child: _item(
                      icon: Icons.person_outline_rounded,
                      title: 'Detail Profil',
                      subtitle: 'Perbarui informasi akun',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditProfilePage(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// ================= ACTIVITY SECTION =================
                  _sectionTitle('Aktivitas'),
                  const SizedBox(height: 12),
                  _buildAnimatedCard(
                    child: Column(
                      children: [
                        _item(
                          icon: Icons.swap_horiz_rounded,
                          title: 'Transaksi',
                          subtitle: 'Lihat pesanan yang sedang diproses',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TransactionsPage(),
                              ),
                            );
                          },
                        ),
                        Divider(
                          height: 1,
                          indent: 56,
                          endIndent: 16,
                          color: Colors.grey.withOpacity(0.2),
                        ),
                        _item(
                          icon: Icons.history_rounded,
                          title: 'Riwayat Pesanan',
                          subtitle: 'Lihat pesanan sebelumnya',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const OrderHistoryPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// ================= HELP & INFO SECTION =================
                  _sectionTitle('Bantuan & Informasi'),
                  const SizedBox(height: 12),
                  _buildAnimatedCard(
                    child: Column(
                      children: [
                        _item(
                          icon: Icons.help_outline_rounded,
                          title: 'FAQ',
                          subtitle: 'Pertanyaan yang sering diajukan',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HelpFaqPage(),
                              ),
                            );
                          },
                        ),
                        Divider(
                          height: 1,
                          indent: 56,
                          endIndent: 16,
                          color: Colors.grey.withOpacity(0.2),
                        ),
                        _item(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Kebijakan Privasi',
                          subtitle: 'Perlindungan data pengguna',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HelpPrivacyPage(),
                              ),
                            );
                          },
                        ),
                        Divider(
                          height: 1,
                          indent: 56,
                          endIndent: 16,
                          color: Colors.grey.withOpacity(0.2),
                        ),
                        _item(
                          icon: Icons.description_outlined,
                          title: 'Syarat & Ketentuan',
                          subtitle: 'Aturan penggunaan aplikasi',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HelpTermsPage(),
                              ),
                            );
                          },
                        ),
                        Divider(
                          height: 1,
                          indent: 56,
                          endIndent: 16,
                          color: Colors.grey.withOpacity(0.2),
                        ),
                        _item(
                          icon: Icons.info_outline_rounded,
                          title: 'Tentang Aplikasi',
                          subtitle: 'Versi & informasi aplikasi',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HelpAboutPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  /// ================= LOGOUT BUTTON =================
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.error.withOpacity(0.1),
                          AppColors.error.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.error.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          _showLogoutSheet(context, session);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.logout_rounded,
                                color: AppColors.error,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Keluar dari Akun',
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  /// SPACE FOR USER SHELL
                  const SizedBox(height: _shellBottomSpace),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutSheet(BuildContext context, SessionProvider session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  size: 24,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Keluar dari Akun',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Apakah Anda yakin ingin keluar dari akun?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        HapticFeedback.mediumImpact();
                        final ok = await session.logout(context);
                        if (ok && context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                          );
                        }
                      },
                      child: const Text('Logout'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ================= HELPERS =================
  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    ),
  );

  Widget _buildAnimatedCard({required Widget child}) =>
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
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
        child: child,
      );

  Widget _item({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            child: Row(
              children: [
                /// Icon Container
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),

                /// Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.withOpacity(0.7),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                /// Chevron
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary.withOpacity(0.4),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      );
}