import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import '/core/constants/app_colors.dart';
import '/data/services/auth_service.dart';
import '/state/session_provider.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  final _auth = AuthService();
  final _picker = ImagePicker();

  bool _loading = false;
  File? _avatarFile;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _auth.getUserProfile();
    final user = _auth.currentUser;

    if (!mounted) return;

    if (profile != null) {
      _nameController.text = profile['full_name'] ??
          _auth.currentUser?.userMetadata?['full_name'] ??
          _auth.currentUser?.userMetadata?['name'] ??
          '';
      _avatarUrl = profile['avatar_url'] ?? _auth.currentUser?.userMetadata?['avatar_url'];
    } else {
      // If users table row is missing or missing full_name, fall back to auth metadata
      _nameController.text = _auth.currentUser?.userMetadata?['full_name'] ?? _auth.currentUser?.userMetadata?['name'] ?? '';
      _avatarUrl = _auth.currentUser?.userMetadata?['avatar_url'];
    }

    if (user?.email != null) {
      _emailController.text = user!.email!;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _appBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          children: [
            _header(),
            const SizedBox(height: 24),
            _form(),
            const SizedBox(height: 32),
            _saveButton(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(72),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primary.withOpacity(0.85),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white.withOpacity(0.9),
                      size: 20,
                    ),
                  ),
                ),
              ),
              const Expanded(
                child: Text(
                  'Edit Profil',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        /// Glassmorphic effect
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
      child: Row(
        children: [
          _avatar(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Perbarui Data Profil',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ubah informasi akun Anda',
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    return GestureDetector(
      onTap: _pickAvatar,
      onLongPress: _avatarUrl != null ? _confirmDeleteAvatar : null,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          /// Avatar with gradient ring
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.3),
                  AppColors.primary.withOpacity(0.1),
                ],
              ),
            ),
            child: CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary.withOpacity(0.15),
              backgroundImage: _avatarFile != null
                  ? FileImage(_avatarFile!)
                  : (_avatarUrl != null ? NetworkImage(_avatarUrl!) : null)
                      as ImageProvider?,
              child: (_avatarFile == null && _avatarUrl == null)
                  ? Icon(
                      Icons.person,
                      size: 32,
                      color: AppColors.primary,
                    )
                  : null,
            ),
          ),
          /// Camera badge
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              _avatarUrl != null ? Icons.edit : Icons.camera_alt,
              size: 14,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('Nama Lengkap'),
            const SizedBox(height: 8),
            _field(
              controller: _nameController,
              label: 'Masukkan nama lengkap',
              icon: Icons.person_outline,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Nama tidak boleh kosong';
                if (v.trim().length < 3) return 'Nama minimal 3 karakter';
                return null;
              },
            ),
            const SizedBox(height: 24),
            _fieldLabel('Email'),
            const SizedBox(height: 8),
            _field(
              controller: _emailController,
              label: 'Masukkan email',
              icon: Icons.email_outlined,
              keyboard: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email tidak boleh kosong';
                final s = v.trim();
                if (!s.contains('@') || !s.contains('.') || s.length < 6) return 'Email tidak valid';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _emailHint(),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) => Text(
    label,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
      letterSpacing: 0.2,
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      validator: validator,
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(
          color: Colors.grey.withOpacity(0.6),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          color: AppColors.primary.withOpacity(0.6),
          size: 20,
        ),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.primary.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.primary.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
    );
  }

  Widget _emailHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.primary.withOpacity(0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mengubah email memerlukan login ulang & verifikasi.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loading ? null : _saveProfile,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _loading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.9),
                        ),
                      ),
                    )
                  : const Text(
                      'Simpan Perubahan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ================= LOGIC =================

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  Future<String?> _uploadAvatar(File file) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final path =
        'avatars/${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    await Supabase.instance.client.storage
        .from('avatars')
        .upload(path, file);

    return Supabase.instance.client.storage
        .from('avatars')
        .getPublicUrl(path);
  }

  Future<void> _confirmDeleteAvatar() async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline,
                color: AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Hapus Foto Profil',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus avatar? Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(
            color: Colors.black.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteAvatar();
    }
  }

  Future<void> _deleteAvatar() async {
    try {
      if (_avatarUrl == null) return;

      final uri = Uri.parse(_avatarUrl!);
      final filePath = uri.pathSegments.skip(2).join('/');

      await Supabase.instance.client.storage
          .from('avatars')
          .remove([filePath]);

      await _auth.updateUserProfile(avatarUrl: null);

      setState(() {
        _avatarUrl = null;
        _avatarFile = null;
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _saveProfile() async {
    // Validate inputs before sending to server
    if (!_formKey.currentState!.validate()) {
      _showError('Periksa kembali input Anda');
      return;
    }

    setState(() => _loading = true);

    try {
      String? avatarUrl = _avatarUrl;

      if (_avatarFile != null) {
        avatarUrl = await _uploadAvatar(_avatarFile!);
      }

      await _auth.updateUserProfile(
        fullName: _nameController.text.trim(),
        avatarUrl: avatarUrl,
      );

      // Refresh locally cached profile so UI updates (Home/Profile) immediately
      try {
        await Provider.of<SessionProvider>(context, listen: false).reloadProfile();
      } catch (_) {}

      final currentEmail = _auth.currentUser?.email;
      final newEmail = _emailController.text.trim();

      if (currentEmail != null && newEmail != currentEmail) {
        await _handleEmailChange(newEmail);
        return;
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleEmailChange(String newEmail) async {
    await _auth.updateEmail(newEmail: newEmail);

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Email Diubah',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Email berhasil diperbarui.\n\n'
          'Silakan login ulang dan verifikasi email baru Anda.',
          style: TextStyle(
            color: Colors.black.withOpacity(0.7),
            fontSize: 14,
            height: 1.6,
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(120, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              HapticFeedback.mediumImpact();
              await _auth.logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (_) => false,
                );
              }
            },
            child: const Text(
              'Login Ulang',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        elevation: 4,
      ),
    );
  }
}
