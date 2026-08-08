import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../core/theme.dart';
import '../core/session.dart';
import 'notification_modals.dart';

class BarcodeGeneratorDialog extends StatefulWidget {
  const BarcodeGeneratorDialog({super.key});

  @override
  State<BarcodeGeneratorDialog> createState() => _BarcodeGeneratorDialogState();
}

class _BarcodeGeneratorDialogState extends State<BarcodeGeneratorDialog> {
  late String _generatedCode;
  final GlobalKey _globalKey = GlobalKey();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _generatedCode = _generateBarcodeId();
  }

  String _generateBarcodeId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return List.generate(9, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<void> _saveToGallery() async {
    // Omba ruhusa ya storage
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

    setState(() => _isSaving = true);

    try {
      final boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Haikuweza kupata picha ya barcode.');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final result = await ImageGallerySaverPlus.saveImage(
        pngBytes,
        quality: 100,
        name: 'Barcode_$_generatedCode',
      );

      if (!mounted) return;
      if (result['isSuccess'] == true) {
        NotificationService.showSuccessBanner(
          context,
          title: 'Imehifadhiwa',
          message: 'Picha ya barcode imehifadhiwa kwenye simu yako kikamilifu.',
        );
        // Funga drawer na rudisha barcode iliyozalishwa ili itumike kwenye form
        Navigator.of(context, rootNavigator: true).pop(_generatedCode);
      } else {
        throw Exception('Imeshindwa kuhifadhi picha.');
      }
    } catch (e) {
      if (!mounted) return;
      NotificationService.showError(
        context,
        title: 'Hitilafu',
        message: 'Kuna tatizo wakati wa kuhifadhi picha.',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              const Text(
                'Barcode Mpya',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Unaweza kudownload picha hii na kuiprint ili kuibandika kwenye bidhaa yako.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 24),
              RepaintBoundary(
                key: _globalKey,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BarcodeWidget(
                        barcode: Barcode.code128(),
                        data: _generatedCode,
                        drawText: false,
                        width: double.infinity,
                        height: 70,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '@${Session.instance.shopSlug ?? 'username'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Colors.black87,
                        ),
                      ),
                      const Text(
                        'ibink.me',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveToGallery,
                  icon: _isSaving 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded, size: 20),
                  label: const Text('Download & Save', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.inkSoft,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Funga', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
