import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/theme.dart';
import '../core/local_storage.dart';
import '../core/session.dart';
import '../models/product_model.dart';
import '../widgets/notification_modals.dart';

class BarcodesScreen extends StatefulWidget {
  const BarcodesScreen({super.key});

  @override
  State<BarcodesScreen> createState() => _BarcodesScreenState();
}

class _BarcodesScreenState extends State<BarcodesScreen> {
  List<ProductModel> _productsWithBarcodes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBarcodes();
  }

  void _loadBarcodes() {
    final allProducts = LocalStorage.instance.getCachedProducts();
    setState(() {
      _productsWithBarcodes = allProducts
          .where((p) => p.barcode != null && p.barcode!.isNotEmpty)
          .toList();
      _isLoading = false;
    });
  }

  /// Inachora barcode widget kwenye image bytes (PNG)
  Future<List<int>?> _capturePng(GlobalKey repaintKey) async {
    try {
      final boundary =
          repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _downloadBarcode(ProductModel product, GlobalKey repaintKey) async {
    var storageStatus = await Permission.storage.request();
    var photosStatus = await Permission.photos.request();

    if (!storageStatus.isGranted && !photosStatus.isGranted) {
      if (!mounted) return;
      NotificationService.showError(
        context,
        title: 'Ruhusa Inahitajika',
        message: 'Tafadhali ruhusu app kuhifadhi picha kwenye simu yako.',
      );
      return;
    }

    final pngBytes = await _capturePng(repaintKey);
    if (pngBytes == null) {
      if (!mounted) return;
      NotificationService.showError(context, title: 'Hitilafu', message: 'Imeshindwa kutengeneza picha.');
      return;
    }

    try {
      final result = await ImageGallerySaverPlus.saveImage(
        pngBytes as dynamic,
        quality: 100,
        name: 'Barcode_${product.barcode}',
      );
      if (!mounted) return;
      if (result['isSuccess'] == true) {
        NotificationService.showSuccessBanner(
          context,
          title: 'Imehifadhiwa',
          message: 'Barcode ya ${product.name} imehifadhiwa kwenye Gallery.',
        );
      } else {
        throw Exception('save failed');
      }
    } catch (_) {
      if (!mounted) return;
      NotificationService.showError(context, title: 'Hitilafu', message: 'Kuna tatizo wakati wa kuhifadhi picha.');
    }
  }

  Future<void> _shareBarcode(ProductModel product, GlobalKey repaintKey) async {
    final pngBytes = await _capturePng(repaintKey);
    if (pngBytes == null) {
      if (!mounted) return;
      NotificationService.showError(context, title: 'Hitilafu', message: 'Imeshindwa kutengeneza picha ya kushare.');
      return;
    }

    try {
      // Hifadhi kwenye folder ya muda (temp directory)
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/Barcode_${product.barcode}.png');
      await file.writeAsBytes(pngBytes);

      // Shiriki faili kwa kutumia share_plus
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: 'Barcode ya ${product.name} — ibink.me',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      NotificationService.showError(
        context,
        title: 'Hitilafu ya Kushare',
        message: 'Imeshindwa kushare barcode. Jaribu tena.',
      );
    }
  }

  void _showPlaceholderFeature(String feature) {
    NotificationService.showSuccessBanner(
      context,
      title: 'Inakuja Hivi Karibuni',
      message: 'Kipengele cha $feature kitakuwepo kwenye toleo lijalo!',
    );
  }

  Widget _buildBarcodeCard(ProductModel product, bool isGrid) {
    final GlobalKey repaintKey = GlobalKey();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Barcode preview area ---
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                child: RepaintBoundary(
                  key: repaintKey,
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BarcodeWidget(
                          barcode: Barcode.code128(),
                          data: product.barcode!,
                          drawText: false,
                          width: double.infinity,
                          height: isGrid ? 44 : 56,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '@${Session.instance.shopSlug ?? 'ibink'}',
                          style: TextStyle(
                            fontSize: isGrid ? 9 : 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'ibink.me',
                          style: TextStyle(
                            fontSize: isGrid ? 7 : 9,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // --- Product name ---
          const Divider(height: 1, color: AppColors.line),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isGrid ? 8 : 12,
              vertical: isGrid ? 5 : 8,
            ),
            child: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: isGrid ? 12 : 13,
                color: AppColors.ink,
              ),
            ),
          ),

          // --- Action buttons ---
          Padding(
            padding: EdgeInsets.fromLTRB(
              isGrid ? 6 : 12, 0, isGrid ? 6 : 12, isGrid ? 8 : 10,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionButton(
                  icon: Icons.download_rounded,
                  label: 'Download',
                  onTap: () => _downloadBarcode(product, repaintKey),
                ),
                _ActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: () => _shareBarcode(product, repaintKey),
                ),
                _ActionButton(
                  icon: Icons.print_rounded,
                  label: 'Print',
                  onTap: () => _showPlaceholderFeature('Kuprint'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.ink),
        title: const Text(
          'Barcodes Zangu',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : _productsWithBarcodes.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.68,
              ),
              itemCount: _productsWithBarcodes.length,
              itemBuilder: (context, index) =>
                  _buildBarcodeCard(_productsWithBarcodes[index], true),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.panel,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.line),
              ),
              child: const Icon(Icons.qr_code_2_rounded, size: 64, color: AppColors.inkFaint),
            ),
            const SizedBox(height: 24),
            const Text(
              'Hakuna Barcodes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hujatengeneza barcode yoyote kwa ajili ya bidhaa zako. Ukiongeza barcode kwenye bidhaa zitaonekana hapa.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.inkSoft, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.greenSoft.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.green),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
