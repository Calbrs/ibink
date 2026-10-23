import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/app_logger.dart';
import '../../core/theme.dart';
import '../../routes/app_routes.dart';
import '../../widgets/notification_modals.dart';
import '../../widgets/tiktok_ui.dart';

const String _tag = 'TikTokPlayer';

class TikTokVideoPlayerScreen extends StatefulWidget {
  final String videoId;
  final String title;
  final String? embedLink;

  const TikTokVideoPlayerScreen({
    super.key,
    required this.videoId,
    required this.title,
    this.embedLink,
  });

  @override
  State<TikTokVideoPlayerScreen> createState() =>
      _TikTokVideoPlayerScreenState();
}

class _TikTokVideoPlayerScreenState extends State<TikTokVideoPlayerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hadError = false;
  double _progress = 0;

  String get _url {
    final embed = widget.embedLink;
    if (embed != null && embed.trim().isNotEmpty) return embed.trim();
    return 'https://www.tiktok.com/embed/v2/${widget.videoId}';
  }

  String get _watchUrl => 'https://www.tiktok.com/@/video/${widget.videoId}';

  @override
  void initState() {
    super.initState();

    AppLogger.instance.info(_tag, 'Opening video ${widget.videoId}');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress / 100);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            AppLogger.instance.info(_tag, 'Player page finished loading.');
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hadError = false;
              });
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != true) return;
            AppLogger.instance.error(_tag, 'Player failed to load', error);
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hadError = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_url));
  }

  // ───────────────────────── Actions ─────────────────────────

  void _openInTikTok() {
    AppLogger.instance.info(_tag, 'Handing off to TikTok: $_watchUrl');
    context.pushReplacement(
      AppRoutes.browser,
      extra: {'url': _watchUrl, 'title': 'TikTok'},
    );
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _watchUrl));
    if (!mounted) return;
    NotificationService.showSuccessBanner(
      context,
      message: 'Kiungo kimenakiliwa.',
    );
  }

  void _retry() {
    setState(() {
      _hadError = false;
      _isLoading = true;
      _progress = 0;
    });
    _controller.loadRequest(Uri.parse(_url));
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: ttAppBar(context, title: widget.title),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            children: [
              Expanded(
                child: _hadError ? _buildError() : _buildPlayer(),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TtButton(
                      label: 'Fungua TikTok',
                      onPressed: _openInTikTok,
                      icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TtButton(
                      label: 'Nakili kiungo',
                      onPressed: _copyLink,
                      outlined: true,
                      icon: const Icon(Icons.link_rounded, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Video inakaa kwenye kadi nyeusi yenye kona za mviringo.
  Widget _buildPlayer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.green),
            ),
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _progress == 0 ? null : _progress,
                minHeight: 3,
                backgroundColor: Colors.white12,
                color: AppColors.green,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      decoration: ttCardDecoration,
      clipBehavior: Clip.antiAlias,
      child: TtMessageState(
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.danger,
        title: 'Video haijapatikana',
        message: 'Video hii inaweza kuondolewa au kuhitaji ruhusa ya ziada.',
        actionLabel: 'Jaribu Tena',
        onAction: _retry,
      ),
    );
  }
}