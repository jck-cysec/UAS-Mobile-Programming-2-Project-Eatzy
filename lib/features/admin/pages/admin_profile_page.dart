import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/state/session_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/core/constants/app_colors.dart';
import 'help_faq_page.dart';
import 'help_privacy_page.dart';
import 'help_terms_page.dart';
import 'help_about_page.dart';
import '/features/auth/login/login_page.dart';

class AdminProfilePage extends StatelessWidget {
  const AdminProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final isDesktop = width >= 900;
      final horizontalPadding = isDesktop ? 32.0 : 20.0;
      final bottomNavPadding = MediaQuery.of(context).padding.bottom + 80.0;

      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            horizontalPadding, 20, horizontalPadding, bottomNavPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// =========================
            /// PROFILE HEADER
            /// =========================
            Container(
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
              child: Column(
                children: [
                  /// Avatar
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// Email
                  Text(
                    user?.email ?? 'admin@kantin.com',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 6),

                  /// Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Administrator',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// =========================
            /// BANTUAN SECTION
            /// =========================
            const Text(
              'Bantuan & Informasi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),

            _settingsCard(
              children: [
                _settingsItem(
                  icon: Icons.help_outline_rounded,
                  title: 'Pusat Bantuan',
                  subtitle: 'FAQ & panduan',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpFaqPage())),
                ),
                const Divider(height: 1, indent: 56),
                _settingsItem(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Kebijakan Privasi',
                  subtitle: 'Baca kebijakan privasi kami',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpPrivacyPage())),
                ),
                const Divider(height: 1, indent: 56),
                _settingsItem(
                  icon: Icons.description_outlined,
                  title: 'Syarat & Ketentuan',
                  subtitle: 'Ketentuan penggunaan',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpTermsPage())),
                ),
                const Divider(height: 1, indent: 56),
                _settingsItem(
                  icon: Icons.info_outline_rounded,
                  title: 'Tentang Aplikasi',
                  subtitle: 'Versi 1.0.0',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpAboutPage())),
                ),
              ],
            ),

            const SizedBox(height: 32),

            /// =========================
            /// LOGOUT BUTTON
            /// =========================
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'Keluar dari Akun',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Row(
                        children: [
                          Icon(Icons.logout_rounded, color: AppColors.error),
                          SizedBox(width: 12),
                          Text('Konfirmasi Logout'),
                        ],
                      ),
                      content: const Text(
                        'Apakah Anda yakin ingin keluar dari akun?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Batal'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );

                    if (confirm == true) {
                      // Use SessionProvider.logout so in-memory state and cached role are cleared
                      if (context.mounted) {
                        final session = Provider.of<SessionProvider>(context, listen: false);
                        await session.logout(context);

                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (_) => false,
                        );
                      }
                    }
                },
              ),
            ),
          ],
        ),
      );
    });
  }

  /* ======================
   * SETTINGS CARD
   * ====================== */
  Widget _settingsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  /* ======================
   * SETTINGS ITEM
   * ====================== */
  Widget _settingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textGrey.withOpacity(0.5),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}