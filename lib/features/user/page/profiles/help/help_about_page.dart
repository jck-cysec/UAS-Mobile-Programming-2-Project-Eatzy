import 'package:flutter/material.dart';
import '/core/constants/app_colors.dart';

class HelpAboutPage extends StatefulWidget {
  const HelpAboutPage({super.key});

  @override
  State<HelpAboutPage> createState() => _HelpAboutPageState();
}

class _HelpAboutPageState extends State<HelpAboutPage>
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
      appBar: _appBar(context, 'Tentang Aplikasi'),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              children: [
                _headerCard(),
                const SizedBox(height: 26),
                _infoCard(),
                const SizedBox(height: 28),
                _footer(),
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
                      color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCard() {
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
          Icon(Icons.fastfood_rounded, color: Colors.white, size: 36),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Eatzy',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text(
                  'Pesan makanan lebih cepat & praktis',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Informasi Aplikasi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 14),
          Divider(),
          SizedBox(height: 14),
          _InfoRow(title: 'Versi', value: '1.0.0'),
          SizedBox(height: 12),
          _InfoRow(
            title: 'Tentang',
            value:
                'Eatzy membantu Anda memesan makanan favorit tanpa perlu antre. '
                'Cocok untuk mahasiswa dan pengguna dengan aktivitas padat.',
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Column(
      children: [
        Text('© ${DateTime.now().year} Team Eatzy',
            style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String title;
  final String value;

  const _InfoRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 80, child: Text(title, style: const TextStyle(fontSize: 13))),
        Expanded(
            child:
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ],
    );
  }
}
