import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/app_shimmer.dart';

/// ============================================================================
/// notification_modals.dart
///
/// Global notification & modal system with bottom alignment.
/// ============================================================================

enum NotificationType { success, error, warning, info }

class _NotificationColors {
  final Color background;
  final Color foreground;
  final IconData icon;

  const _NotificationColors({
    required this.background,
    required this.foreground,
    required this.icon,
  });
}

class NotificationService {
  NotificationService._();

  static GlobalKey<NavigatorState>? navigatorKey;
  static OverlayEntry? _bannerEntry;
  static Timer? _bannerTimer;

  static _NotificationColors _colorsFor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return const _NotificationColors(
          background: AppColors.green,
          foreground: Colors.white,
          icon: Icons.check_circle_rounded,
        );
      case NotificationType.error:
        return const _NotificationColors(
          background: AppColors.danger,
          foreground: Colors.white,
          icon: Icons.error_rounded,
        );
      case NotificationType.warning:
        return const _NotificationColors(
          background: Color(0xFFF59E0B),
          foreground: Colors.white,
          icon: Icons.warning_rounded,
        );
      case NotificationType.info:
        return const _NotificationColors(
          background: AppColors.ink,
          foreground: Colors.white,
          icon: Icons.info_rounded,
        );
    }
  }

  static BuildContext? _resolveContext(BuildContext? context) {
    return context ?? navigatorKey?.currentContext;
  }

  // --------------------------------------------------------------------
  // DIALOG BUILDER (Bottom alignment transition)
  // FIX: useRootNavigator: true prevents GoRouter from intercepting pop()
  // --------------------------------------------------------------------
  static Future<T?> _showIOSDialog<T>({
    required BuildContext context,
    required Widget child,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            alignment: Alignment.bottomCenter,
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------------
  // TOP BANNER
  // --------------------------------------------------------------------
  static void showTopBanner(
    BuildContext? context, {
    required String message,
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 4),
    String? title,
  }) {
    final ctx = _resolveContext(context);
    if (ctx == null) return;

    final overlay = Overlay.of(ctx, rootOverlay: true);
    _removeBanner();

    final colors = _colorsFor(type);

    _bannerEntry = OverlayEntry(
      builder: (context) => _TopBanner(
        message: message,
        title: title,
        background: colors.background,
        foreground: colors.foreground,
        icon: colors.icon,
        onDismiss: _removeBanner,
      ),
    );

    overlay.insert(_bannerEntry!);

    _bannerTimer?.cancel();
    _bannerTimer = Timer(duration, _removeBanner);
  }

  static void _removeBanner() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
    _bannerEntry?.remove();
    _bannerEntry = null;
  }

  static void dismissBanner() => _removeBanner();

  static void showSuccessBanner(BuildContext? context, {required String message, String? title}) =>
      showTopBanner(context, message: message, type: NotificationType.success, title: title);

  static void showErrorBanner(BuildContext? context, {required String message, String? title}) =>
      showTopBanner(context, message: message, type: NotificationType.error, title: title);

  static void showWarningBanner(BuildContext? context, {required String message, String? title}) =>
      showTopBanner(context, message: message, type: NotificationType.warning, title: title);

  static void showInfoBanner(BuildContext? context, {required String message, String? title}) =>
      showTopBanner(context, message: message, type: NotificationType.info, title: title);

  // --------------------------------------------------------------------
  // SUCCESS MODAL
  // --------------------------------------------------------------------
  static Future<void> showSuccess(
    BuildContext context, {
    String title = "Kikamilifu",
    required String message,
    String buttonText = "Sawa",
    VoidCallback? onDismiss,
  }) {
    return _showStatusModal(
      context,
      title: title,
      message: message,
      buttonText: buttonText,
      type: NotificationType.success,
      onDismiss: onDismiss,
    );
  }

  // --------------------------------------------------------------------
  // ERROR MODAL
  // --------------------------------------------------------------------
  static Future<void> showError(
    BuildContext context, {
    String title = "Kuna tatizo",
    required String message,
    String buttonText = "Sawa",
    VoidCallback? onDismiss,
  }) {
    return _showStatusModal(
      context,
      title: title,
      message: message,
      buttonText: buttonText,
      type: NotificationType.error,
      onDismiss: onDismiss,
    );
  }

  static Future<void> _showStatusModal(
    BuildContext context, {
    required String title,
    required String message,
    required String buttonText,
    required NotificationType type,
    VoidCallback? onDismiss,
  }) async {
    final colors = _colorsFor(type);

    await _showIOSDialog(
      context: context,
      child: _StatusDialog(
        title: title,
        message: message,
        buttonText: buttonText,
        background: colors.background,
        onPressed: () {
          // FIX: rootNavigator kuzuia GoRouter kujaribu kufuta page badala ya dialog
          Navigator.of(context, rootNavigator: true).pop();
          onDismiss?.call();
        },
      ),
    );
  }

  // --------------------------------------------------------------------
  // CONFIRMATION MODAL
  // --------------------------------------------------------------------
  static Future<bool> showConfirmation(
    BuildContext context, {
    String title = "Una uhakika?",
    required String message,
    String confirmText = "Thibitisha",
    String cancelText = "Ghairi",
    bool isDestructive = false,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) async {
    final result = await _showIOSDialog<bool>(
      context: context,
      child: _ConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
      ),
    );

    if (result == true) {
      onConfirm?.call();
    } else {
      onCancel?.call();
    }

    return result ?? false;
  }

  // --------------------------------------------------------------------
  // LOADING MODAL
  // --------------------------------------------------------------------
  static void showLoading(BuildContext context, {String message = "Tafadhali subiri..."}) {
    _showIOSDialog(
      context: context,
      barrierDismissible: false,
      child: PopScope(
        canPop: false,
        child: Dialog(
          alignment: Alignment.bottomCenter,
          insetPadding: const EdgeInsets.only(left: 10, right: 10, bottom: 30),
          backgroundColor: AppColors.panel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: AppShimmerSpinner(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    message, 
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void hideLoading(BuildContext context) {
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

/// ============================================================================
/// WIDGETS
/// ============================================================================

class _TopBanner extends StatefulWidget {
  final String message;
  final String? title;
  final Color background;
  final Color foreground;
  final IconData icon;
  final VoidCallback onDismiss;

  const _TopBanner({
    required this.message,
    required this.title,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.onDismiss,
  });

  @override
  State<_TopBanner> createState() => _TopBannerState();
}

class _TopBannerState extends State<_TopBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: SlideTransition(
          position: _offsetAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onDismiss,
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) < 0) {
                  widget.onDismiss();
                }
              },
              child: Container(
                margin: EdgeInsets.only(top: topPadding > 0 ? 8 : 16, left: 16, right: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: widget.background.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: widget.background.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(widget.icon, color: widget.foreground, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.title != null) ...[
                                  Text(
                                    widget.title!,
                                    style: TextStyle(
                                      color: widget.foreground,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                Text(
                                  widget.message,
                                  style: TextStyle(
                                    color: widget.foreground.withValues(alpha: 0.95),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusDialog extends StatelessWidget {
  final String title;
  final String message;
  final String buttonText;
  final Color background;
  final VoidCallback onPressed;

  const _StatusDialog({
    required this.title,
    required this.message,
    required this.buttonText,
    required this.background,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.bottomCenter,
      insetPadding: const EdgeInsets.only(left: 10, right: 10, bottom: 30),
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14.5, color: AppColors.inkSoft, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: background,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  elevation: 0,
                ),
                child: Text(buttonText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool isDestructive;

  const _ConfirmationDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.isDestructive,
  });

  @override
  Widget build(BuildContext context) {
    final confirmColor = isDestructive ? AppColors.danger : AppColors.greenDeep;

    return Dialog(
      alignment: Alignment.bottomCenter,
      insetPadding: const EdgeInsets.only(left: 10, right: 10, bottom: 30),
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14.5, color: AppColors.inkSoft, height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.line, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: const Text(
                      'Ghairi',
                      style: TextStyle(fontSize: 15, color: AppColors.ink, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      elevation: 0,
                    ),
                    child: Text(confirmText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}