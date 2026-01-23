import 'package:flutter/material.dart';
import '/core/constants/app_colors.dart';

class HelpFaqPage extends StatefulWidget {
  const HelpFaqPage({super.key});

  @override
  State<HelpFaqPage> createState() => _HelpFaqPageState();
}

class _HelpFaqPageState extends State<HelpFaqPage>
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
      appBar: _appBar(context, 'FAQ'),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              children: [
                _header(),
                const SizedBox(height: 24),
                Expanded(child: _faqList()),
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
          Icon(Icons.help_outline_rounded, color: Colors.white, size: 32),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pusat Bantuan',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Jawaban untuk pertanyaan umum pengguna',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _faqList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: const [
          _FaqTile(
            title: 'Bagaimana cara memesan makanan?',
            content:
                'Pilih menu yang tersedia, tambahkan ke keranjang, lalu lanjutkan ke pembayaran.',
          ),
          Divider(height: 1),
          _FaqTile(
            title: 'Bagaimana melihat riwayat pesanan?',
            content:
                'Masuk ke menu Profil lalu pilih Riwayat Pesanan.',
          ),
          Divider(height: 1),
          _FaqTile(
            title: 'Apakah pesanan bisa dibatalkan?',
            content:
                'Pesanan hanya dapat dibatalkan sebelum diproses oleh penjual.',
          ),
          Divider(height: 1),
          _FaqTile(
            title: 'Metode pembayaran apa saja yang tersedia?',
            content:
                'Metode pembayaran akan ditampilkan saat proses checkout.',
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String title;
  final String content;

  const _FaqTile({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: Icon(Icons.question_answer_rounded, color: AppColors.primary),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text(
          content,
          style: TextStyle(fontSize: 13, color: AppColors.textGrey),
        ),
      ],
    );
  }
}
