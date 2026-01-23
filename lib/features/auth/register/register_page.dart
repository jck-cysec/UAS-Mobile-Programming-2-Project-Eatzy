import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '/core/constants/app_colors.dart';
import '/data/services/auth_service.dart';
import '/state/session_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/features/auth/login/login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  late final AuthService _authService;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _scaleAnim;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  // Password strength indicator
  double _passwordStrength = 0.0;
  String _passwordStrengthText = '';
  Color _passwordStrengthColor = Colors.grey;

  @override
  void initState() {
    super.initState();

    _authService = AuthService();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _animController.forward();

    _passwordCtrl.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    final password = _passwordCtrl.text;
    double strength = 0.0;
    String text = '';
    Color color = Colors.grey;

    if (password.isEmpty) {
      strength = 0.0;
      text = '';
    } else if (password.length < 6) {
      strength = 0.25;
      text = 'Lemah';
      color = AppColors.error;
    } else if (password.length < 8) {
      strength = 0.5;
      text = 'Sedang';
      color = Colors.orange;
    } else if (password.length >= 8 &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[0-9]'))) {
      strength = 1.0;
      text = 'Kuat';
      color = AppColors.success;
    } else {
      strength = 0.75;
      text = 'Cukup';
      color = Colors.amber;
    }

    setState(() {
      _passwordStrength = strength;
      _passwordStrengthText = text;
      _passwordStrengthColor = color;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }

    _nameFocus.unfocus();
    _emailFocus.unfocus();
    _passwordFocus.unfocus();
    _confirmPasswordFocus.unfocus();

    setState(() => _isLoading = true);

    try {
      final AuthResponse res = await _authService.register(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        fullName: _nameCtrl.text.trim(),
      );

      if (res.user == null) {
        throw const AuthException('Registrasi gagal');
      }

      if (!mounted) return;

      final sessionProvider = context.read<SessionProvider>();
      await sessionProvider.refreshSession();

      await _showSuccessAnimation();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOutCubic,
                )),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showErrorSnackBar('Terjadi kesalahan');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showSuccessAnimation() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.celebration_outlined, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Akun berhasil dibuat! Silakan login 🎉',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 2000),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 3000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(Icons.arrow_back_ios_new, color: AppColors.primary, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              /// =========================
              /// LOGO WITH ANIMATION
              /// =========================
              FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Hero(
                    tag: 'app_logo',
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.25),
                            blurRadius: 25,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo/eatzy_logo.jpg',
                          height: 80,
                          width: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              /// =========================
              /// HEADER TEXT
              /// =========================
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    Text(
                      'Daftar Sekarang!',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Buat akun untuk pengalaman kuliner terbaik',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textGrey,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              /// =========================
              /// FORM
              /// =========================
              SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        /// NAME FIELD
                        TextFormField(
                          controller: _nameCtrl,
                          focusNode: _nameFocus,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                          style: const TextStyle(fontSize: 15),
                          decoration: _inputDecoration(
                            'Nama Lengkap',
                            Icons.person_outline,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Nama tidak boleh kosong';
                            }
                            if (value.length < 3) {
                              return 'Nama minimal 3 karakter';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        /// EMAIL FIELD
                        TextFormField(
                          controller: _emailCtrl,
                          focusNode: _emailFocus,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                          style: const TextStyle(fontSize: 15),
                          decoration: _inputDecoration(
                            'Email',
                            Icons.email_outlined,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Email tidak boleh kosong';
                            }
                            if (!value.contains('@')) {
                              return 'Email tidak valid';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(value)) {
                              return 'Format email tidak valid';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        /// PASSWORD FIELD
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _passwordCtrl,
                              focusNode: _passwordFocus,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) =>
                                  _confirmPasswordFocus.requestFocus(),
                              style: const TextStyle(fontSize: 15),
                              decoration: _inputDecoration(
                                'Password',
                                Icons.lock_outline,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: AppColors.textGrey,
                                    size: 22,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.length < 6) {
                                  return 'Password minimal 6 karakter';
                                }
                                return null;
                              },
                            ),
                            if (_passwordCtrl.text.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.border,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Kekuatan Password',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textGrey,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: _passwordStrength,
                                              backgroundColor:
                                                  Colors.grey.shade200,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                _passwordStrengthColor,
                                              ),
                                              minHeight: 6,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _passwordStrengthColor
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _passwordStrengthText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _passwordStrengthColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 20),

                        /// CONFIRM PASSWORD FIELD
                        TextFormField(
                          controller: _confirmPasswordCtrl,
                          focusNode: _confirmPasswordFocus,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          style: const TextStyle(fontSize: 15),
                          decoration: _inputDecoration(
                            'Konfirmasi Password',
                            Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.textGrey,
                                size: 22,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value != _passwordCtrl.text) {
                              return 'Password tidak sama';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 32),

                        /// =========================
                        /// REGISTER BUTTON
                        /// =========================
                        Container(
                          height: 56,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: _isLoading
                                  ? [Colors.grey.shade300, Colors.grey.shade400]
                                  : [AppColors.primary, AppColors.primaryDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: _isLoading
                                ? []
                                : [
                                    BoxShadow(
                                      color:
                                          AppColors.primary.withOpacity(0.4),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Daftar Sekarang',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        /// =========================
                        /// LOGIN LINK
                        /// =========================
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        const LoginPage(),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                              ),
                            );
                          },
                          child: RichText(
                            text: TextSpan(
                              text: 'Sudah punya akun? ',
                              style: TextStyle(
                                color: AppColors.textGrey,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Login',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.textGrey),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }
}