import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '/data/models/order_item_model.dart';
import '/data/services/order_service.dart';
import '/state/session_provider.dart';
import '/data/services/cart_service.dart';
import '/features/user/page/invoice_page.dart';
import '/core/constants/app_colors.dart';

class PaymentPage extends StatefulWidget {
  final List<OrderItemModel> items;
  final double total;
  final OrderService? orderService; // optional override for testing or DI

  const PaymentPage({super.key, required this.items, required this.total, this.orderService});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String _method = 'cash';
  String _deliveryType = 'pickup';
  final TextEditingController _buildingController = TextEditingController();
  bool _loading = false;

  Future<void> _pay() async {
    setState(() => _loading = true);

    // Show quick processing feedback for longer payment methods (card). Cash is immediate.
    if (_method == 'card') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Memproses pembayaran...'), duration: Duration(seconds: 2)));
      await Future.delayed(const Duration(seconds: 1));
    } else {
      // small yield so UI updates immediately
      await Future.delayed(const Duration(milliseconds: 150));
    }

    // After payment success, create order
    final session = Provider.of<SessionProvider>(context, listen: false);
    // Prefer explicit supabase user id; fall back to cached profile id (useful in widget tests)
    final userIdRaw = session.user?.id ?? session.userProfile?['id']?.toString();
    final uuidRe = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (userIdRaw == null || !uuidRe.hasMatch(userIdRaw)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap login ulang terlebih dahulu')));
      setState(() => _loading = false);
      return;
    }
    final userId = userIdRaw;

    // Basic client-side validation
    if (widget.items.isEmpty || widget.total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keranjang kosong atau total tidak valid')));
      setState(() => _loading = false);
      return;
    }

    if (!['pickup', 'delivery'].contains(_deliveryType)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jenis pengiriman tidak valid')));
      setState(() => _loading = false);
      return;
    }

    final building = _buildingController.text.trim();

    // Validate cart items (qty and price)
    for (final it in widget.items) {
      if (it.qty <= 0 || it.price < 0.0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item keranjang tidak valid')));
        setState(() => _loading = false);
        return;
      }
    }

    // Validation: if delivery, delivery address is required (stop before payment)
    if (_deliveryType == 'delivery' && building.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan alamat pengiriman sebelum melanjutkan pembayaran')));
      setState(() => _loading = false);
      return;
    }

    if (_deliveryType == 'delivery' && building.isNotEmpty && building.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan lokasi pengiriman yang lebih spesifik')));
      setState(() => _loading = false);
      return;
    }

    final itemsMap = widget.items.map((e) => e.toMap()).toList();

    String? id;
    String? createErr;

    try {
      // Prepare shipping/payment info
      final shippingFee = (_deliveryType == 'delivery') ? 3000.0 : 0.0; // TODO: compute dynamic fee if available

      // Create order using two-step insert (orders then order_items).
      // Do not throw on partial failures here — prefer to let the user proceed and
      // surface a warning on the Invoice page if items failed to attach.
      final svc = widget.orderService ?? OrderService();
      id = await svc.createOrder(
        userId: userId,
        items: itemsMap,
        deliveryType: _deliveryType,
        buildingId: (_deliveryType == 'delivery' && building.isNotEmpty) ? building : null,
        paymentMethod: _method,
        shippingFee: shippingFee,
      );
    } catch (e) {
      // Non-recoverable/server/network error — surface to user
      createErr = e.toString();
      if (kDebugMode) debugPrint('createOrder error (propagated): $createErr');
      id = null;
    }

    setState(() => _loading = false);

    if (id != null) {
      // clear cart
      try {
        // avoid adding a hard dependency but call CartService if available
        // ignore: avoid_dynamic_calls
        final cart = CartService.instance;
        cart.clear();
      } catch (_) {}

      if (!mounted) return;

      // Inform user and navigate to realtime invoice/status so they can monitor processing
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesanan diterima — menampilkan status pesanan...')));

      final orderId = id;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => InvoicePage(orderId: orderId)),
      );
      return;
    }

    // --- recovery / partial-order UX ---
    // If createOrder returned null, try a best-effort recovery: maybe the DB
    // created the order but didn't return the id (common in some PostgREST setups).
    String? recoveredId;
    try {
      recoveredId = await OrderService().recoverRecentOrder(
        userId: userId,
        approxItems: itemsMap,
        withinSeconds: 25,
        approxDeliveryAddress: (_deliveryType == 'delivery' ? building : null),
      );
      if (kDebugMode) debugPrint('PaymentPage: recoverRecentOrder -> $recoveredId');
    } catch (e) {
      if (kDebugMode) debugPrint('recoverRecentOrder error: $e');
    }

    final msg = createErr ?? '';

    if (recoveredId != null) {
      // Let the user proceed to the realtime invoice even if some items are missing.
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Pembayaran terproses, tetapi ada masalah saat memasang item pesanan. Anda dapat melihat pesanan atau mencoba memulihkan item.'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Lihat pesanan',
          onPressed: () {
            if (!mounted) return;
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => InvoicePage(orderId: recoveredId!)));
          },
        ),
      ));

      // Navigate to invoice and surface an inline CTA to repair there as well
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => InvoicePage(orderId: recoveredId!)));

      // Also offer an immediate quick-repair dialog so power-users can try to attach items now
      if (mounted && msg.isNotEmpty) {
        // show details but keep navigation behaviour
        showDialog<void>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Pesanan - Perlu Pemulihan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Text(
                  'Pesanan tampaknya dibuat (id: $recoveredId) tetapi beberapa item mungkin belum terpasang.\n\nDetail:\n\n$msg',
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Mencoba memulihkan item...'),
                          ],
                        ),
                      ),
                    );
                    final ok = await OrderService().attachItemsToOrder(
                      orderId: recoveredId!,
                      items: itemsMap,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                ok ? Icons.check_circle : Icons.error_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  ok
                                      ? 'Item berhasil dipulihkan'
                                      : 'Gagal memulihkan item — coba lagi atau hubungi dukungan',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: ok ? Colors.green.withOpacity(0.85) : AppColors.error,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        ),
                      );
                    }
                  },
                  child: const Text('Pulihkan'),
                ),
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: msg));
                    if (ctx.mounted) Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.content_copy, color: Colors.white, size: 18),
                            SizedBox(width: 10),
                            Text('Error disalin ke clipboard'),
                          ],
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Salin'),
                ),
              ],
            );
          },
        );
      }

      return;
    }

    // No recoverable order found — fall back to previous behaviour but make
    // messaging more actionable (allow copy & retry).
    final shortMsg = msg.isEmpty ? 'Gagal membuat pesanan. Periksa koneksi dan coba lagi.' : (msg.length > 180 ? '${msg.substring(0, 176)}…' : msg);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(shortMsg),
      action: SnackBarAction(
        label: 'Coba lagi',
        onPressed: () {
          if (!_loading) _pay();
        },
      ),
      duration: const Duration(seconds: 6),
    ));

    if (msg.isNotEmpty && mounted) {
      // Offer a detail dialog so user/dev can copy error for debugging and
      // optionally report/view next steps.
      showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
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
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Detail Kesalahan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                msg,
                style: TextStyle(
                  color: Colors.black.withOpacity(0.7),
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: msg));
                  if (ctx.mounted) Navigator.pop(ctx);
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.content_copy, color: Colors.white, size: 18),
                          SizedBox(width: 10),
                          Text('Error disalin ke clipboard'),
                        ],
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text('Salin'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _buildingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(screenWidth < 360 ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ================= CUSTOMER CARD =================
            _buildCustomerCard(session),
            const SizedBox(height: 24),

            /// ================= PAYMENT METHOD =================
            _buildPaymentSection(),
            const SizedBox(height: 24),

            /// ================= DELIVERY TYPE =================
            _buildDeliverySection(),
            const SizedBox(height: 24),

            /// ================= LOCATION INPUT (if delivery) =================
            if (_deliveryType == 'delivery') ...[
              _buildLocationField(),
              const SizedBox(height: 24),
            ],

            /// ================= TOTAL & PAY BUTTON =================
            _buildTotalAndPayButton(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
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
                  'Pembayaran',
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

  Widget _buildCustomerCard(SessionProvider session) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.account_circle,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pelanggan',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  session.displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Metode Pembayaran',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: 0.2,
            ),
          ),
        ),
        _buildPaymentOption(
          value: 'cash',
          icon: Icons.wallet,
          title: 'Tunai',
          subtitle: 'Bayar saat terima pesanan',
        ),
        const SizedBox(height: 10),
        _buildPaymentOption(
          value: 'card',
          icon: Icons.credit_card,
          title: 'Kartu',
          subtitle: 'Simulasi pembayaran kartu',
        ),
      ],
    );
  }

  Widget _buildPaymentOption({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _method == value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.2),
          width: isSelected ? 2 : 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _method = value);
        },
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(isSelected ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedScale(
              scale: isSelected ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Radio<String>(
                value: value,
                groupValue: _method,
                onChanged: (v) {
                  HapticFeedback.lightImpact();
                  setState(() => _method = v!);
                },
                activeColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliverySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Tipe Pengiriman',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: 0.2,
            ),
          ),
        ),
        _buildDeliveryOption(
          value: 'pickup',
          icon: Icons.store,
          title: 'Ambil Sendiri',
          subtitle: 'Gratis - Ambil di toko kami',
        ),
        const SizedBox(height: 10),
        _buildDeliveryOption(
          value: 'delivery',
          icon: Icons.delivery_dining,
          title: 'Diantar',
          subtitle: 'Pesanan dikirim ke lokasi Anda',
        ),
      ],
    );
  }

  Widget _buildDeliveryOption({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _deliveryType == value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.2),
          width: isSelected ? 2 : 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _deliveryType = value);
        },
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(isSelected ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedScale(
              scale: isSelected ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Radio<String>(
                value: value,
                groupValue: _deliveryType,
                onChanged: (v) {
                  HapticFeedback.lightImpact();
                  setState(() => _deliveryType = v!);
                },
                activeColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lokasi Pengiriman',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _buildingController,
          decoration: InputDecoration(
            hintText: 'Masukkan gedung, blok, atau lokasi spesifik',
            hintStyle: TextStyle(
              color: Colors.grey.withOpacity(0.6),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.location_on_outlined,
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
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalAndPayButton() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.12),
                AppColors.primary.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Pembayaran',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withOpacity(0.7),
                ),
              ),
              Text(
                'Rp ${widget.total.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
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
              onTap: _loading ? null : _pay,
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
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.payment,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Bayar Sekarang',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
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
      ],
    );
  }
}
