import 'package:flutter/material.dart';
import '/core/constants/app_colors.dart';

class HelpPrivacyPage extends StatefulWidget {
  const HelpPrivacyPage({super.key});

  @override
  State<HelpPrivacyPage> createState() => _HelpPrivacyPageState();
}

class _HelpPrivacyPageState extends State<HelpPrivacyPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _appBar(context, 'Kebijakan Privasi'),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              children: [
                _header(),
                const SizedBox(height: 24),
                _content(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, String title) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(72),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: Colors.white,
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: const [
          Icon(Icons.shield_outlined, color: Colors.white, size: 32),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Privasi Anda adalah Prioritas Kami',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Perlindungan Data',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'Kami menjaga keamanan data pribadi Anda. Informasi yang dikumpulkan '
            'digunakan hanya untuk keperluan pemesanan dan peningkatan layanan.',
            style: TextStyle(
                fontSize: 13, color: AppColors.textGrey, height: 1.6),
          ),
          const SizedBox(height: 20),
          const Text(
            'Data yang Dikumpulkan',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          _item('Nama pengguna'),
          _item('Email'),
          _item('Riwayat pesanan'),
        ],
      ),
    );
  }

  Widget _item(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
          ),
        ],
      ),
    );
  }
}
