import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session_provider.dart';
import '../features/auth/login/login_page.dart';
import '../features/user/user_shell_page.dart';
import '../features/admin/admin_shell_page.dart';
import '../features/auth/register/register_page.dart';

class AppRouter {
  static Route<dynamic> generateRoute(
    RouteSettings settings,
    BuildContext context,
  ) {
    final session = context.read<SessionProvider>();

    switch (settings.name) {
      case '/':
        return _root(session);

      case '/login':
        return _page(const LoginPage());

      case '/register':
        return _page(const RegisterPage());

      case '/home':
        return _guard(
          session: session,
          requiredRole: 'user',
          page: const UserShellPage(),
        );

      case '/admin':
        return _guard(
          session: session,
          requiredRole: 'admin',
          page: const AdminShellPage(),
        );

      default:
        return _page(
          const Scaffold(
            body: Center(child: Text('404 - Page not found')),
          ),
        );
    }
  }

  /* ============================
   * ROOT DECIDER
   * ============================ */
  static Route _root(SessionProvider session) {
    // Masih loading auth / profile
    if (session.status == AuthStatus.loading ||
        !session.isProfileLoaded) {
      return _page(
        const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Belum login
    if (!session.isLoggedIn) {
      return _page(const LoginPage());
    }

    // Login & admin
    if (session.isAdmin) {
      return _page(const AdminShellPage());
    }

    // Login & user
    return _page(const UserShellPage());
  }

  /* ============================
   * ROLE GUARD
   * ============================ */
  static Route _guard({
    required SessionProvider session,
    required String requiredRole,
    required Widget page,
  }) {
    if (session.status == AuthStatus.loading ||
        !session.isProfileLoaded) {
      return _page(
        const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (!session.isLoggedIn) {
      return _page(const LoginPage());
    }

    if (session.role != requiredRole) {
      return _page(
        const Scaffold(
          body: Center(child: Text('Akses ditolak')),
        ),
      );
    }

    return _page(page);
  }

  /* ============================
   * PAGE BUILDER
   * ============================ */
  static PageRoute _page(Widget child) {
    return MaterialPageRoute(builder: (_) => child);
  }
}
