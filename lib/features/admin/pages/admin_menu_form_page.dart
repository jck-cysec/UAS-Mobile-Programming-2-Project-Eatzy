import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/core/constants/app_colors.dart';
import '/data/models/menu_model.dart';
import '/data/services/menu_service.dart';

class AdminMenuFormPage extends StatefulWidget {
  final MenuModel? menu;
  const AdminMenuFormPage({super.key, this.menu});

  @override
  State<AdminMenuFormPage> createState() => _AdminMenuFormPageState();
}

class _AdminMenuFormPageState extends State<AdminMenuFormPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _prepCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  String _category = 'makanan';
  bool _isAvailable = true;
  final MenuService _service = MenuService.instance;
  bool _saving = false;

  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    final m = widget.menu;
    if (m != null) {
      _nameCtrl.text = m.name;
      _descCtrl.text = m.description;
      _priceCtrl.text = m.price.toString();
      _prepCtrl.text = m.prepTime.toString();
      _isAvailable = m.isAvailable;
      _imageCtrl.text = m.imageUrl;
      _category = m.category;
    }

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeIn,
    );

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _prepCtrl.dispose();
    _imageCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    setState(() => _saving = true);

    final name = _nameCtrl.text.trim();
    final price = int.tryParse(_priceCtrl.text.trim()) ?? 0;
    final prep = int.tryParse(_prepCtrl.text.trim()) ?? 0;
    final desc = _descCtrl.text.trim();

    if (price <= 0) {
      _showErrorSnackBar('Harga harus berupa angka lebih dari 0');
      setState(() => _saving = false);
      return;
    }
    if (prep < 0) {
      _showErrorSnackBar('Waktu persiapan harus >= 0');
      setState(() => _saving = false);
      return;
    }

    try {
      final image = _imageCtrl.text.trim();

      final payload = {
        'name': name,
        'description': desc,
        'price': price,
        'prep_time': prep,
        'is_available': _isAvailable,
        'category': _category,
        'image_url': image.isEmpty ? null : image,
      }..removeWhere((k, v) => v == null);

      if (widget.menu == null) {
        await _service.createMenu(payload);
        if (context.mounted) {
          HapticFeedback.mediumImpact();
          _showSuccessSnackBar('Menu berhasil ditambahkan');
        }
      } else {
        await _service.updateMenu(widget.menu!.id, payload);
        if (context.mounted) {
          HapticFeedback.mediumImpact();
          _showSuccessSnackBar('Menu berhasil diperbarui');
        }
      }

      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      _showErrorSnackBar('Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle,
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
        backgroundColor: Colors.green.withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        elevation: 4,
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
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

  Future<void> _delete() async {
    HapticFeedback.mediumImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: Colors.white,
        elevation: 8,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Hapus Menu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Menu akan disembunyikan dari pelanggan, namun riwayat pesanan tetap aman. Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(
            color: Colors.black.withOpacity(0.65),
            fontSize: 14,
            height: 1.6,
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(ctx, false);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              'Batal',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx, true);
            },
            child: const Text(
              'Hapus',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (ok == true && widget.menu != null) {
      HapticFeedback.mediumImpact();
      try {
        await _service.deleteMenu(widget.menu!.id);
        if (context.mounted) {
          _showSuccessSnackBar('Menu berhasil dihapus dari pelanggan');
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          _showErrorSnackBar('Gagal menghapus menu: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.menu != null;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context, editing),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(screenWidth < 360 ? 14 : 16),
            child: Column(
              children: [
                /// ================= HEADER CARD =================
                _buildHeaderCard(editing),
                const SizedBox(height: 24),

                /// ================= FORM CARD =================
                _buildFormCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool editing) {
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
              Expanded(
                child: Text(
                  editing ? 'Edit Menu' : 'Tambah Menu',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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

  Widget _buildHeaderCard(bool editing) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(-3, -3),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  editing ? Icons.edit_rounded : Icons.add_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      editing ? 'Edit Menu' : 'Menu Baru',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      editing
                          ? 'Perbarui informasi menu'
                          : 'Tambahkan menu ke katalog',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Nama Menu
              _buildFieldLabel('Nama Menu *'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _nameCtrl,
                hint: 'Masukkan nama menu',
                icon: Icons.restaurant_menu,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 20),

              /// Deskripsi
              _buildFieldLabel('Deskripsi (opsional)'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _descCtrl,
                hint: 'Masukkan deskripsi menu',
                icon: Icons.description_outlined,
                keyboardType: TextInputType.multiline,
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              /// Kategori
              _buildFieldLabel('Kategori *'),
              const SizedBox(height: 8),
              _buildCategoryDropdown(),
              const SizedBox(height: 20),

              /// Image URL
              _buildFieldLabel('Image URL (opsional)'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _imageCtrl,
                hint: 'https://example.com/image.jpg',
                icon: Icons.image_outlined,
                keyboardType: TextInputType.url,
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return null;
                  final ok = RegExp(r'^https?://').hasMatch(s);
                  return ok ? null : 'URL harus dimulai dengan http/https';
                },
              ),
              const SizedBox(height: 20),

              /// Harga & Waktu Persiapan in Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Harga (Rp) *'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _priceCtrl,
                          hint: '15000',
                          icon: Icons.attach_money,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Harga wajib';
                            }
                            final p = int.tryParse(v.trim());
                            if (p == null || p <= 0) {
                              return 'Harga > 0';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Waktu (menit) *'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _prepCtrl,
                          hint: '20',
                          icon: Icons.schedule,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Waktu wajib';
                            }
                            final t = int.tryParse(v.trim());
                            if (t == null || t < 0) {
                              return 'Waktu >= 0';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              /// Tersedia Switch
              _buildAvailableSwitch(),
              const SizedBox(height: 28),

              /// Buttons
              _buildActionButtons(widget.menu != null),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) => Text(
    label,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
      letterSpacing: 0.2,
    ),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
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

  Widget _buildCategoryDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _category,
        items: [
          DropdownMenuItem(
            value: 'makanan',
            child: Row(
              children: [
                const Icon(Icons.fastfood, size: 18),
                const SizedBox(width: 8),
                const Text('Makanan'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'minuman',
            child: Row(
              children: [
                const Icon(Icons.local_drink, size: 18),
                const SizedBox(width: 8),
                const Text('Minuman'),
              ],
            ),
          ),
        ],
        onChanged: (v) => setState(() => _category = v ?? 'makanan'),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          prefixIcon: Icon(
            Icons.category_outlined,
            color: AppColors.primary.withOpacity(0.6),
            size: 20,
          ),
        ),
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildAvailableSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _isAvailable
            ? AppColors.success.withOpacity(0.08)
            : AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isAvailable
              ? AppColors.success.withOpacity(0.3)
              : AppColors.error.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isAvailable ? Icons.check_circle : Icons.cancel,
            color: _isAvailable ? AppColors.success : AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isAvailable ? 'Menu Tersedia' : 'Menu Tidak Tersedia',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _isAvailable ? AppColors.success : AppColors.error,
              ),
            ),
          ),
          AnimatedScale(
            scale: 1.0,
            duration: const Duration(milliseconds: 200),
            child: Switch(
              value: _isAvailable,
              onChanged: (v) => setState(() => _isAvailable = v),
              activeThumbColor: AppColors.success,
              inactiveThumbColor: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isEditing) {
    return Row(
      children: [
        if (isEditing)
          Expanded(
            child: Container(
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
                  onTap: _delete,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Hapus',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (isEditing) const SizedBox(width: 12),
        Expanded(
          flex: isEditing ? 2 : 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _saving ? null : _save,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: _saving
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withOpacity(0.9),
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isEditing ? Icons.save : Icons.add_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isEditing ? 'Perbarui' : 'Tambah',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
