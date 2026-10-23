import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/tiktok_service.dart';
import '../../core/tiktok_settings_service.dart';
import '../../models/tiktok_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_shimmer.dart';
import '../../widgets/notification_modals.dart';
import '../../widgets/tiktok_ui.dart';

class TikTokScreen extends StatefulWidget {
  const TikTokScreen({super.key});

  @override
  State<TikTokScreen> createState() => _TikTokScreenState();
}

class _TikTokScreenState extends State<TikTokScreen> {
  bool _isLoading = true;
  String? _error;
  int _videoCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ───────────────────────── Data ─────────────────────────

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await TikTokService.instance.checkConnection();
      // Haizuii wasifu kupakia ikishindwa.
      if (TikTokService.instance.isConnected) {
        unawaited(TikTokSettingsService.instance.refreshCreatorInfo());
      }
      final videos = await TikTokService.instance.getVideos();
      if (mounted) {
        setState(() {
          _videoCount = videos.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Imeshindwa kupakua data. Jaribu tena.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async => await _loadData();

  // ───────────────────────── Actions ─────────────────────────

  void _openVideos() => context.push(AppRoutes.tiktokVideos);

  void _openSettings() => context.push(AppRoutes.tiktokSettings);

  Future<void> _disconnect() async {
    final confirmed = await NotificationService.showConfirmation(
      context,
      title: 'Toa muunganisho wa TikTok?',
      message: 'Muunganisho wa TikTok utaondolewa na data yako itafutwa.',
      confirmText: 'Toa',
      cancelText: 'Ghairi',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final success = await TikTokService.instance.disconnect();
    if (!mounted) return;

    if (success) {
      NotificationService.showSuccessBanner(
        context,
        message: 'TikTok imeondolewa',
      );
      context.go(AppRoutes.profile);
    } else {
      NotificationService.showErrorBanner(
        context,
        message: TikTokService.instance.error ?? 'Imeshindwa kuondoa',
      );
    }
  }

  Future<void> _connectTikTok() async {
    final url = await TikTokService.instance.getAuthUrl();
    if (!mounted) return;

    if (url != null && url.isNotEmpty) {
      context.push(AppRoutes.tiktokWebView, extra: {'url': url});
    } else {
      NotificationService.showErrorBanner(
        context,
        message: 'Imeshindwa kupata kiungo cha TikTok. Jaribu tena.',
      );
    }
  }

  void _openTikTokProfile() {
    final username = TikTokService.instance.profile?.username;
    if (username != null && username.isNotEmpty) {
      context.push(AppRoutes.browser, extra: {
        'url': 'https://www.tiktok.com/@$username',
        'title': 'TikTok Profile',
      });
    }
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final isConnected = TikTokService.instance.isConnected;
    final profile = TikTokService.instance.profile;
    final connected = isConnected && profile != null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: ttAppBar(
        context,
        actions: [
          if (connected) ...[
            _buildOpenPill(),
            const SizedBox(width: 8),
            _buildUnlinkPill(),
            const SizedBox(width: 16),
          ],
        ],
      ),
      body: SafeArea(
        top: false,
        child: !connected
            ? _buildDisconnectedBody()
            : _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: AppShimmerSpinner(),
                    ),
                  )
                : _error != null
                    ? RefreshIndicator(
                        onRefresh: _refresh,
                        color: AppColors.green,
                        child: TtMessageState(
                          icon: Icons.error_outline_rounded,
                          iconColor: AppColors.danger,
                          title: 'Imeshindwa kupakua',
                          message: _error!,
                          actionLabel: 'Jaribu Tena',
                          onAction: _refresh,
                        ),
                      )
                    : _buildAccount(profile),
      ),
    );
  }

  // ───────────────────────── App bar pills ─────────────────────────

  Widget _buildOpenPill() {
    return _buildActionPill(
      key: const Key('tiktok_open_pill'),
      label: 'Fungua',
      trailing: Image.asset('assets/icons/tik-tok.png', width: 15, height: 15),
      onTap: _openTikTokProfile,
    );
  }

  Widget _buildUnlinkPill() {
    return _buildActionPill(
      key: const Key('tiktok_unlink_pill'),
      label: 'Ondoa',
      tint: AppColors.danger.withValues(alpha: 0.08),
      borderColor: AppColors.danger.withValues(alpha: 0.3),
      textColor: AppColors.danger,
      trailing:
          const Icon(Icons.link_off_rounded, size: 14, color: AppColors.danger),
      onTap: _disconnect,
    );
  }

  Widget _buildActionPill({
    required Key key,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
    Color tint = AppColors.panel,
    Color borderColor = AppColors.line,
    Color textColor = AppColors.ink,
  }) {
    return Center(
      child: Material(
        key: key,
        color: tint,
        shape: StadiumBorder(side: BorderSide(color: borderColor)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  trailing,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Disconnected ─────────────────────────

  Widget _buildDisconnectedBody() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.line),
              ),
              child: Center(
                child: Image.asset(
                  'assets/icons/tik-tok.png',
                  width: 40,
                  height: 40,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'TikTok haujaunganishwa',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Unganisha akaunti yako ya TikTok ili kuona mtandao wako na video zako hapa.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.inkSoft,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            TtButton(
              label: 'Unganisha TikTok',
              onPressed: _connectTikTok,
              icon: Image.asset(
                'assets/icons/tik-tok.png',
                width: 18,
                height: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Connected ─────────────────────────

  /// Muhtasari mfupi wa mipangilio ya kuchapisha.
  String get _settingsSummary =>
      TikTokSettingsService.instance.settings.summary;

  Widget _buildAccount(TikTokProfile profile) {
    // Inajichora upya mtumiaji akibadilisha mipangilio ya kuchapisha.
    return ListenableBuilder(
      listenable: TikTokSettingsService.instance,
      builder: (context, _) => _buildAccountInner(profile),
    );
  }

  Widget _buildAccountInner(TikTokProfile profile) {
    final name = (profile.displayName?.isNotEmpty == true)
        ? profile.displayName!
        : (profile.username ?? 'TikTok');
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final username = profile.username;
    final bio = profile.bioDescription;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.green,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ── Identity
          Center(child: TtAvatar(initial: initial)),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              if (profile.isVerified) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.verified_rounded,
                  size: 20,
                  color: AppColors.green,
                ),
              ],
            ],
          ),
          if (username != null && username.isNotEmpty) ...[
            const SizedBox(height: 8),
            Center(child: TtPill(text: '@$username')),
          ],
          const SizedBox(height: 32),

          // ── Tools
          const TtSectionLabel('Zana'),
          const SizedBox(height: 10),
          TtGroupCard(
            children: [
              TtActionRow(
                key: const Key('tiktok_videos_button'),
                leading: const Icon(Icons.playlist_play_rounded,
                    size: 18, color: AppColors.green),
                title: 'Video',
                subtitle: _videoCount > 0
                    ? 'Video $_videoCount zilizopo'
                    : 'Hakuna video bado',
                onTap: _openVideos,
              ),
              TtActionRow(
                key: const Key('tiktok_settings_button'),
                leading: const Icon(Icons.tune_rounded,
                    size: 18, color: AppColors.green),
                title: 'Mipangilio',
                subtitle: _settingsSummary,
                onTap: _openSettings,
              ),
            ],
          ),

          // ── Account info
          const SizedBox(height: 24),
          const TtSectionLabel('Taarifa za akaunti'),
          const SizedBox(height: 10),
          TtGroupCard(
            children: [
              TtInfoRow(
                icon: Icons.alternate_email_rounded,
                label: 'Jina la mtumiaji',
                value: username ?? '—',
              ),
              TtInfoRow(
                icon: Icons.badge_outlined,
                label: 'Jina la kuonesha',
                value: profile.displayName ?? '—',
              ),
              TtInfoRow(
                icon: profile.isVerified
                    ? Icons.verified_rounded
                    : Icons.shield_outlined,
                label: 'Hali ya uthibitisho',
                value: profile.isVerified
                    ? 'Imethibitishwa'
                    : 'Haijathibitishwa',
                iconColor:
                    profile.isVerified ? AppColors.green : AppColors.inkSoft,
              ),
            ],
          ),

          // ── Bio
          const SizedBox(height: 24),
          const TtSectionLabel('Bio'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: ttCardDecoration,
            child: Text(
              (bio != null && bio.isNotEmpty) ? bio : 'Hakuna bio',
              style: TextStyle(
                fontSize: 14,
                color: (bio != null && bio.isNotEmpty)
                    ? AppColors.inkSoft
                    : AppColors.inkFaint,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}