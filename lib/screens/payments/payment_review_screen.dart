import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../core/theme.dart';
import '../../core/payment_service.dart';
import '../../models/payment_confirmation.dart';
import '../../widgets/notification_modals.dart';

class PaymentReviewScreen extends StatefulWidget {
  final PaymentConfirmation confirmation;
  const PaymentReviewScreen({super.key, required this.confirmation});

  @override
  State<PaymentReviewScreen> createState() => _PaymentReviewScreenState();
}

class _PaymentReviewScreenState extends State<PaymentReviewScreen> {
  late PaymentConfirmation _confirmation;
  bool _isProcessing = false;
  String? _ocrResult;

  @override
  void initState() {
    super.initState();
    _confirmation = widget.confirmation;
    _ocrResult = _confirmation.ocrRawText;
  }

  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    final source = await _showImageSourceSelector();
    if (source == null) return;

    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked == null || !mounted) return;

    NotificationService.showLoading(context, message: 'Inasoma picha...');
    try {
      final inputImage = InputImage.fromFilePath(picked.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognized = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      setState(() {
        _ocrResult = recognized.text;
      });

      if (!mounted) return;
      NotificationService.hideLoading(context);
      NotificationService.showSuccessBanner(
        context,
        title: 'Imesomwa',
        message: 'Picha imesomwa kikamilifu.',
      );
    } catch (e) {
      if (!mounted) return;
      NotificationService.hideLoading(context);
      NotificationService.showErrorBanner(
        context,
        title: 'Hitilafu',
        message: 'Imeshindwa kusoma picha.',
      );
    }
  }

  Future<ImageSource?> _showImageSourceSelector() async {
    return showModalBottomSheet<ImageSource>(
      useRootNavigator: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSourceSheet(),
    );
  }

  Future<void> _confirmPayment() async {
    final agreed = await NotificationService.showConfirmation(
      context,
      title: 'Thibitisha Malipo?',
      message: 'Una uhakika malipo haya ni sahihi kwa oda #${_confirmation.orderNumber}?',
      confirmText: 'Thibitisha',
      cancelText: 'Ghairi',
    );

    if (!agreed || !mounted) return;

    setState(() => _isProcessing = true);
    NotificationService.showLoading(context, message: 'Inathibitisha...');

    final success = await PaymentService.instance.confirmPayment(_confirmation.id);

    if (!mounted) return;
    NotificationService.hideLoading(context);

    if (success) {
      NotificationService.showSuccessBanner(
        context,
        title: 'Imethibitishwa',
        message: 'Malipo ya oda #${_confirmation.orderNumber} yamethibitishwa.',
      );
      Navigator.of(context).pop();
    } else {
      NotificationService.showErrorBanner(
        context,
        title: 'Imeshindwa',
        message: 'Imeshindwa kuthibitisha malipo.',
      );
    }

    setState(() => _isProcessing = false);
  }

  Future<void> _rejectPayment() async {
    final agreed = await NotificationService.showConfirmation(
      context,
      title: 'Kataa Malipo?',
      message: 'Una uhakika malipo haya si sahihi?',
      confirmText: 'Kataa',
      cancelText: 'Ghairi',
      isDestructive: true,
    );

    if (!agreed || !mounted) return;

    setState(() => _isProcessing = true);
    NotificationService.showLoading(context, message: 'Inakataa...');

    final success = await PaymentService.instance.rejectPayment(_confirmation.id);

    if (!mounted) return;
    NotificationService.hideLoading(context);

    if (success) {
      NotificationService.showSuccessBanner(
        context,
        title: 'Imekataliwa',
        message: 'Malipo ya oda #${_confirmation.orderNumber} yamekataliwa.',
      );
      Navigator.of(context).pop();
    } else {
      NotificationService.showErrorBanner(
        context,
        title: 'Imeshindwa',
        message: 'Imeshindwa kukataa malipo.',
      );
    }

    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = _confirmation.provider;
    final status = _confirmation.status;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.panel,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Oda #${_confirmation.orderNumber}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  // Screenshot / OCR section
                  const _SheetLabel('THIBITISHO LA MALIPO'),
                  const SizedBox(height: 8),
                  _confirmation.screenshotUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              _confirmation.screenshotUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: AppColors.panelDeep,
                                child: const Center(child: Icon(Icons.broken_image_rounded, size: 48, color: AppColors.inkFaint)),
                              ),
                            ),
                          ),
                        )
                      : GestureDetector(
                          onTap: _pickScreenshot,
                          child: Container(
                            height: 160,
                            decoration: BoxDecoration(
                              color: AppColors.panelDeep,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.line, width: 1.4),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_rounded, size: 36, color: AppColors.inkFaint),
                                SizedBox(height: 8),
                                Text('Gusa ili kupakia picha', style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                              ],
                            ),
                          ),
                        ),
                  const SizedBox(height: 12),

                  // OCR result
                  if (_ocrResult != null && _ocrResult!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.greenSoft.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MAELEZO YA PICHA',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.greenDeep, letterSpacing: 0.6),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _ocrResult!,
                            style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.5),
                          ),
                        ],
                      ),
                    ),

                  if (_confirmation.screenshotUrl == null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickScreenshot,
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: const Text('Pakia Pisha ya Malipo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.line, width: 1.4),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Payment details
                  const _SheetLabel('MWONESHANO'),
                  const SizedBox(height: 8),
                  _InfoCard(children: [
                    _InfoRow(icon: Icons.payment_rounded, label: provider.label),
                    const Divider(height: 20),
                    _InfoRow(icon: Icons.attach_money_rounded, label: _confirmation.formattedAmount),
                    if (_confirmation.senderPhone != null) ...[
                      const Divider(height: 20),
                      _InfoRow(icon: Icons.phone_outlined, label: _confirmation.senderPhone!),
                    ],
                    if (_confirmation.senderName != null) ...[
                      const Divider(height: 20),
                      _InfoRow(icon: Icons.person_outline_rounded, label: _confirmation.senderName!),
                    ],
                    if (_confirmation.reference != null) ...[
                      const Divider(height: 20),
                      _InfoRow(icon: Icons.tag_rounded, label: _confirmation.reference!),
                    ],
                  ]),
                  const SizedBox(height: 16),

                  // Confidence score
                  if (_confirmation.confidenceScore != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.panel,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.speed_rounded, size: 20, color: AppColors.inkSoft),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ukadiriaji wa Ulinganifu',
                                  style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _confirmation.confidenceScore!,
                                    backgroundColor: AppColors.line,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _confirmation.confidenceScore! >= 0.8
                                          ? AppColors.green
                                          : _confirmation.confidenceScore! >= 0.5
                                              ? const Color(0xFFF59E0B)
                                              : AppColors.danger,
                                    ),
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(_confirmation.confidenceScore! * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Action buttons
                  if (status == PaymentConfirmationStatus.pending) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _confirmPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Thibitisha Malipo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isProcessing ? null : _rejectPayment,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger, width: 1.4),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Kataa Malipo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ] else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: status == PaymentConfirmationStatus.confirmed
                            ? AppColors.greenSoft
                            : AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: status == PaymentConfirmationStatus.confirmed
                              ? AppColors.green.withValues(alpha: 0.3)
                              : AppColors.danger.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            status == PaymentConfirmationStatus.confirmed
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: status == PaymentConfirmationStatus.confirmed
                                ? AppColors.green
                                : AppColors.danger,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              status == PaymentConfirmationStatus.confirmed
                                  ? 'Malipo yameithibitishwa'
                                  : 'Malipo yamekataliwa',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: status == PaymentConfirmationStatus.confirmed
                                    ? AppColors.greenDeep
                                    : AppColors.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;
  const _SheetLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkSoft, letterSpacing: 0.6),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.inkSoft),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5, color: AppColors.ink, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _ImageSourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Chagua Chanzo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _SourceButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Kamera',
                    onTap: () => Navigator.of(context).pop(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Galeria',
                    onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: AppColors.green),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
          ],
        ),
      ),
    );
  }
}
