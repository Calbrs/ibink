// ============================================================
// tiktok_callback_screen.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/tiktok_service.dart';
import '../../core/theme.dart';
import '../../routes/app_routes.dart';
import '../../widgets/notification_modals.dart';

class TikTokCallbackScreen extends StatefulWidget {
  final String code;
  final String state;

  const TikTokCallbackScreen({
    super.key,
    required this.code,
    required this.state,
  });

  @override
  State<TikTokCallbackScreen> createState() => _TikTokCallbackScreenState();
}

class _TikTokCallbackScreenState extends State<TikTokCallbackScreen> {
  bool _isProcessing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    try {
      final success = await TikTokService.instance.handleCallback(
        widget.code,
        widget.state,
      );

      if (mounted) {
        if (success) {
          setState(() => _isProcessing = false);

          NotificationService.showSuccessBanner(
            context,
            message: 'TikTok imeunganishwa kwa mafanikio!',
          );

          await Future.delayed(const Duration(milliseconds: 900));
          if (mounted) context.go(AppRoutes.profile);
        } else {
          setState(() {
            _isProcessing = false;
            _error = TikTokService.instance.error ??
                'Imeshindwa kuunganisha TikTok';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = 'Hitilafu imetokea: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mark
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.line, width: 1.2),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/icons/tik-tok.png',
                      width: 34,
                      height: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                if (_isProcessing) ...[
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Inakamilisha muunganisho',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tafadhali subiri sekunde chache…',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.inkSoft,
                      height: 1.35,
                    ),
                  ),
                ] else if (_error != null) ...[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.danger,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Muunganisho umeshindikana',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.inkSoft,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go(AppRoutes.profile),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Rudi kwenye Wasifu',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}