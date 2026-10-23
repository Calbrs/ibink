import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/theme.dart';

class BarcodeScannerSheet extends StatefulWidget {
  const BarcodeScannerSheet({super.key});

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet> {
  final MobileScannerController _controller = MobileScannerController(
    // Ruhusu 1D barcodes tu. Kataa QR Code, Data Matrix, Aztec, n.k.
    formats: [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.codabar,
    ],
  );
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final detectedBarcode = barcodes.first;

      // Usalama wa ziada: Hakikisha sio QR Code au 2D Barcode
      if (detectedBarcode.format == BarcodeFormat.qrCode ||
          detectedBarcode.format == BarcodeFormat.dataMatrix ||
          detectedBarcode.format == BarcodeFormat.aztec ||
          detectedBarcode.format == BarcodeFormat.pdf417) {
        
        // Zuia kuscan mara nyingi
        setState(() => _isProcessing = true);
        
        // Onyesha ujumbe kisha uruhusu kuscan tena
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tafadhali scan Barcode tu (mistari). QR Code hairuhusiwi.'),
            backgroundColor: AppColors.danger,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Baada ya sekunde 3 rusu tena
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _isProcessing = false);
        });
        return;
      }

      setState(() {
        _isProcessing = true;
      });
      // Stop scanner immediately to prevent multiple triggers
      _controller.stop();
      
      // Return the scanned value
      Navigator.of(context).pop(detectedBarcode.rawValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Scan Barcode',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Elekeza kamera kwenye barcode ya bidhaa ili kuscan. Hakikisha kuna mwanga wa kutosha.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.inkSoft,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scanWindow = Rect.fromCenter(
                    center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
                    width: 280,
                    height: 180,
                  );

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _controller,
                        scanWindow: scanWindow,
                        onDetect: _onDetect,
                      ),
                      // Scanner overlay box
                      Center(
                        child: Container(
                          width: 280,
                          height: 180,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.green, width: 3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 30,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: IconButton(
                            onPressed: () => _controller.toggleTorch(),
                            icon: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 28),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
