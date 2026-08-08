import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/local_storage.dart';
import '../models/product_model.dart';
import 'notification_modals.dart';

class CartItem {
  final ProductModel product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});
}

class PosScannerSheet extends StatefulWidget {
  const PosScannerSheet({super.key});

  @override
  State<PosScannerSheet> createState() => _PosScannerSheetState();
}

class _PosScannerSheetState extends State<PosScannerSheet> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.itf14,
      BarcodeFormat.codabar,
    ],
  );

  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<CartItem> _cart = [];
  final Set<String> _recentlyScanned = {};

  // Size of the camera preview box and the green viewfinder rectangle.
  // These MUST match the values used in the widget tree below.
  static const double _cameraHeight = 250;
  static const double _viewportWidth = 280;
  static const double _viewportHeight = 140;

  List<ProductModel> _allProducts = [];
  bool _isProcessingCheckout = false;
  bool _soundEnabled = false;

  @override
  void initState() {
    super.initState();
    _allProducts = LocalStorage.instance.getCachedProducts();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _soundEnabled = prefs.getBool('scanner_sound') ?? false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Returns true only if the barcode's bounding box center falls inside
  // the green viewport rectangle drawn over the camera preview.
  bool _isInsideViewport(Barcode barcode, Size previewSize) {
    final corners = barcode.corners;
    if (corners.isEmpty) return false;

    // Average the corner points to get the barcode's center in preview coords.
    double cx = 0, cy = 0;
    for (final p in corners) {
      cx += p.dx;
      cy += p.dy;
    }
    cx /= corners.length;
    cy /= corners.length;

    // mobile_scanner reports corners relative to the raw camera preview size.
    // Map that into the widget's displayed box (BoxFit.cover behavior).
    final double scaleX = _cameraWidthFallback / previewSize.width;
    final double scaleY = _cameraHeight / previewSize.height;
    final double scale = scaleX > scaleY ? scaleX : scaleY;

    final double displayedX = cx * scale;
    final double displayedY = cy * scale;

    final double offsetX = (previewSize.width * scale - _cameraWidthFallback) / 2;
    final double offsetY = (previewSize.height * scale - _cameraHeight) / 2;

    final double mappedX = displayedX - offsetX;
    final double mappedY = displayedY - offsetY;

    final double left = (_cameraWidthFallback - _viewportWidth) / 2;
    final double top = (_cameraHeight - _viewportHeight) / 2;
    final double right = left + _viewportWidth;
    final double bottom = top + _viewportHeight;

    return mappedX >= left && mappedX <= right && mappedY >= top && mappedY <= bottom;
  }

  // Filled in via LayoutBuilder at build time; kept as a field so
  // _isInsideViewport (called from onDetect) can access it.
  double _cameraWidthFallback = 0;

  void _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null) return;

    final Barcode firstBarcode = barcodes.first;
    final String code = firstBarcode.rawValue!;

    // Reject QR codes
    if (firstBarcode.format == BarcodeFormat.qrCode ||
        firstBarcode.format == BarcodeFormat.dataMatrix ||
        firstBarcode.format == BarcodeFormat.aztec ||
        firstBarcode.format == BarcodeFormat.pdf417) {
      if (!_recentlyScanned.contains(code)) {
        _recentlyScanned.add(code);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tafadhali scan Barcode tu (mistari). QR Code hairuhusiwi.'),
            backgroundColor: AppColors.danger,
            duration: Duration(seconds: 2),
          ),
        );
        Timer(const Duration(seconds: 3), () => _recentlyScanned.remove(code));
      }
      return;
    }

    // Only accept barcodes whose center lies inside the green viewport.
    final previewSize = capture.size;
    if (previewSize.width == 0 || previewSize.height == 0) return;
    if (!_isInsideViewport(firstBarcode, previewSize)) {
      // Barcode detected but outside the green frame — ignore silently.
      return;
    }

    // Add cooldown for the same barcode to avoid instant multiple scans
    if (_recentlyScanned.contains(code)) return;
    _recentlyScanned.add(code);
    Timer(const Duration(seconds: 2), () {
      if (mounted) _recentlyScanned.remove(code);
    });

    // Find product
    final product = _allProducts.where((p) => p.barcode == code).firstOrNull;

    if (product != null) {
      _playSuccessFeedback();
      setState(() {
        final existingItem = _cart.where((i) => i.product.id == product.id).firstOrNull;
        if (existingItem != null) {
          existingItem.quantity += 1;
        } else {
          _cart.add(CartItem(product: product));
        }
      });
    } else {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bidhaa haijapatikana.'),
          backgroundColor: AppColors.danger,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _playSuccessFeedback() {
    // Kila mara inatetema (vibrate) ukifanikiwa kuscan
    HapticFeedback.vibrate();

    // Kama sauti imeruhusiwa, piga mlio wa scanner
    if (_soundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      _cart[index].quantity += delta;
      if (_cart[index].quantity <= 0) {
        _cart.removeAt(index);
      }
    });
  }

  double get _totalAmount {
    return _cart.fold(0, (sum, item) => sum + (item.product.price * item.quantity));
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;

    setState(() => _isProcessingCheckout = true);

    final salesData = _cart.map((item) => {
      'product_id': item.product.id,
      'quantity': item.quantity,
      'total_price': item.product.price * item.quantity,
    }).toList();

    try {
      final response = await ApiClient.instance.post(ApiConfig.salesBatchEndpoint, {'sales': salesData});
      if (response.success) {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        NotificationService.showSuccessBanner(
          context,
          title: 'Imefanikiwa',
          message: 'Mauzo yamerekodiwa kikamilifu.',
        );
      } else {
        throw Exception(response.error);
      }
    } catch (e) {
      // Offline fallback
      for (var sale in salesData) {
        await LocalStorage.instance.addPendingSale(sale);
      }
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      NotificationService.showSuccessBanner(
        context,
        title: 'Imehifadhiwa Nje ya Mtandao',
        message: 'Mauzo yamehifadhiwa, yatatumwa pindi mtandao ukirudi.',
      );
    } finally {
      if (mounted) setState(() => _isProcessingCheckout = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'POS Scanner',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
          ),
          const SizedBox(height: 12),

          // Camera Area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Capture the actual rendered width of the camera box so
                // _isInsideViewport can map coordinates correctly.
                _cameraWidthFallback = constraints.maxWidth;
                return SizedBox(
                  height: _cameraHeight,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(
                          controller: _controller,
                          onDetect: _onDetect,
                        ),
                        // Rectangle overlay
                        Center(
                          child: Container(
                            width: _viewportWidth,
                            height: _viewportHeight,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.green, width: 3),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        // Focus point
                        Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          right: 20,
                          child: IconButton(
                            onPressed: () => _controller.toggleTorch(),
                            icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
                            style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1, color: AppColors.line),

          // Cart Area
          Expanded(
            child: _cart.isEmpty
                ? const Center(
                    child: Text(
                      'Scan bidhaa ili kuziongeza hapa...',
                      style: TextStyle(color: AppColors.inkSoft),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _cart.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.line),
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'TZS ${item.product.price} @',
                                    style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            // Quantity Controls
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.line),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () => _updateQuantity(index, -1),
                                    icon: const Icon(Icons.remove, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  ),
                                  Text(
                                    '${item.quantity}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                  ),
                                  IconButton(
                                    onPressed: () => _updateQuantity(index, 1),
                                    icon: const Icon(Icons.add, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'TZS ${item.product.price * item.quantity}',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.green),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Checkout Bottom Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Jumla', style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                      Text(
                        'TZS $_totalAmount',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.ink),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 50,
                  width: 150,
                  child: ElevatedButton(
                    onPressed: _cart.isEmpty || _isProcessingCheckout ? null : _checkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isProcessingCheckout
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Kamilisha', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}