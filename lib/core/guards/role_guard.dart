import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/session_provider.dart';
import '../../features/auth/login/login_page.dart';

class RoleGuard extends StatelessWidget {
  final Widget child;
  final String requiredRole;

  const RoleGuard({
    super.key,
    required this.child,
    required this.requiredRole,
  });

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    // 1️⃣ MASIH LOADING AUTH / PROFILE
    if (session.status == AuthStatus.loading ||
        !session.isProfileLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2️⃣ BELUM LOGIN
    if (!session.isLoggedIn) {
      return const LoginPage();
    }

    // 3️⃣ ROLE TIDAK SESUAI
    if (session.role != requiredRole) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Akses ditolak',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    // 4️⃣ OK
    return child;
  }
}
