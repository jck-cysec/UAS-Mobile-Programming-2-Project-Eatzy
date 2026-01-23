
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/session_provider.dart';
import '../auth/login/login_page.dart';
import '../user/user_shell_page.dart';
import '../admin/admin_shell_page.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeInController;
  late AnimationController _fadeOutController;
  late AnimationController _slideController;

  late Animation<double> _fadeInAnimation;
  late Animation<double> _fadeOutAnimation;
  late Animation<Offset> _slideAnimation;

  bool _navigating = false;

  @override
  void initState() {
    super.initState();

    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeInAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeInController, curve: Curves.easeOut),
    );

    _fadeOutAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _fadeOutController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );

    _fadeInController.forward();
    _slideController.forward();
    _handleFlow();
  }

  Future<void> _handleFlow() async {
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    final sessionProvider = context.read<SessionProvider>();

    int attempts = 0;
    while (sessionProvider.isLoading && attempts < 15) {
      await Future.delayed(const Duration(milliseconds: 200));
      attempts++;
      if (!mounted) return;
    }

    if (_navigating) return;
    _navigating = true;

    await _fadeOutController.forward();

    if (!mounted) return;

    final destination = sessionProvider.isLoggedIn
        ? (sessionProvider.isAdmin ? const AdminShellPage() : const UserShellPage())
        : const LoginPage();

    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    _fadeOutController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange.shade400,
              Colors.orange.shade600,
              Colors.deepOrange.shade500,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeOutAnimation,
            child: FadeTransition(
              opacity: _fadeInAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo with white container
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(22),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/images/logo/eatzy_logo.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // App Name
                      const Text(
                        'Eatzy',
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Tagline
                      Text(
                        'Eat smart. Eat fast.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.95),
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Loading Animation
                      LoadingAnimationWidget.inkDrop(
                        color: Colors.white,
                        size: 26,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}