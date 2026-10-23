import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/session.dart';
import '../../core/social_links_service.dart';
import '../../core/tiktok_service.dart';
import '../../models/social_account_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/notification_modals.dart';
import '../../widgets/app_shimmer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    SocialLinksService.instance.refresh();
  }

  // ───────────────────────── Actions ─────────────────────────

  Future<void> _refresh() async {
    try {
      await Session.instance.refreshProfile();
      await SocialLinksService.instance.refresh();
    } catch (_) {
      if (mounted) {
        NotificationService.showErrorBanner(
          context,
          message: 'Imeshindwa kupakua taarifa mpya. Jaribu tena.',
        );
      }
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await NotificationService.showConfirmation(
      context,
      title: 'Toka kwenye Akaunti?',
      message: 'Utahitaji kuingia tena kwa namba yako ya simu ili kuendelea.',
      confirmText: 'Toka',
      cancelText: 'Ghairi',
      isDestructive: true,
    );
    if (confirmed) await _logout();
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await Session.instance.logout();
      if (!mounted) return;
      context.go(AppRoutes.auth);
    } catch (_) {
      if (mounted) {
        NotificationService.showError(
          context,
          message: 'Imeshindwa kutoka kwenye akaunti. Jaribu tena.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  void _openInAppBrowser(String url, String title) {
    context.push(AppRoutes.browser, extra: {'url': url, 'title': title});
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

  /// Linked → account page. Not linked → start the link flow.
  void _onPlatformTap(SocialLinkState link) {
    if (link.isConnected) {
      _openAccountPage(link.platform);
    } else {
      _startLinking(link.platform);
    }
  }

  void _openAccountPage(SocialPlatform platform) {
    if (platform == SocialPlatform.tiktok) {
      context.push(AppRoutes.tiktok);
      return;
    }
    _openInAppBrowser(_platformSite(platform), platform.name);
  }

  void _startLinking(SocialPlatform platform) {
    if (platform == SocialPlatform.tiktok) {
      _connectTikTok();
      return;
    }
    // No OAuth backend for these yet, so this opens the site for now.
    _openInAppBrowser(_platformSite(platform), platform.name);
  }

  String _platformSite(SocialPlatform platform) {
    switch (platform) {
      case SocialPlatform.instagram:
        return 'https://www.instagram.com';
      case SocialPlatform.facebook:
        return 'https://www.facebook.com';
      default:
        return 'https://www.tiktok.com';
    }
  }

  // ───────────────────────── Helpers ─────────────────────────

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    const months = [
      'Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
  }

  String _location(Session s) {
    final parts = [s.storeDistrict, s.locationRegion]
        .where((e) => e != null && e.isNotEmpty)
        .cast<String>()
        .toList();
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        // Repaints when a link is added or removed.
        child: ListenableBuilder(
          listenable: SocialLinksService.instance,
          builder: (context, _) => _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final session = Session.instance;
    final shopName = session.shopName ?? 'Duka Langu';
    final initial = shopName.isNotEmpty ? shopName[0].toUpperCase() : '?';
    final links = SocialLinksService.instance.links;
    final description = session.storeDescription;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.green,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
        children: [
          // ── Identity
          Center(child: _Avatar(initial: initial)),
          const SizedBox(height: 18),
          Text(
            shopName,
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
          if (session.shopSlug != null) ...[
            const SizedBox(height: 8),
            Center(child: _Pill(text: '@${session.shopSlug}')),
          ],
          const SizedBox(height: 6),
          Text(
            'Mwanachama tangu ${_formatDate(session.createdAt)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.inkFaint),
          ),

          // ── Social shortcuts: linked = check, not linked = faded plus
          if (links.isNotEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final link in links)
                    _SocialIcon(link: link, onTap: () => _onPlatformTap(link)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),

          // ── Shop info
          const _SectionLabel('TAARIFA ZA DUKA'),
          const SizedBox(height: 10),
          _GroupCard(
            children: [
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'Namba ya Simu',
                value: session.phone ?? '—',
              ),
              _InfoRow(
                icon: Icons.storefront_outlined,
                label: 'Aina ya Biashara',
                value: session.businessType ?? '—',
              ),
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Mahali',
                value: _location(session),
              ),
            ],
          ),

          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SectionLabel('KUHUSU DUKA'),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: _cardDecoration,
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.inkSoft,
                  height: 1.6,
                ),
              ),
            ),
          ],

          // ── Tools
          const SizedBox(height: 24),
          const _SectionLabel('ZANA'),
          const SizedBox(height: 10),
          _GroupCard(
            children: [
              _ActionRow(
                leading: Image.asset(
                  'assets/icons/barcode.png',
                  width: 18,
                  height: 18,
                  color: AppColors.green,
                ),
                title: 'Barcodes Zangu',
                subtitle: 'Angalia, download au share barcodes za bidhaa zako',
                onTap: () => context.push(AppRoutes.barcodes),
              ),
              _ActionRow(
                leading: const Icon(Icons.settings_outlined,
                    size: 18, color: AppColors.green),
                title: 'Mipangilio',
                subtitle: 'Akaunti, usalama na mapendeleo',
                onTap: () => context.push(AppRoutes.settings),
              ),
            ],
          ),

          // ── Logout
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _isLoggingOut ? null : _confirmLogout,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
                backgroundColor: AppColors.danger.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoggingOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: AppShimmerSpinner(),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded,
                            size: 20, color: AppColors.danger),
                        SizedBox(width: 8),
                        Text(
                          'Toka',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Shared styling ─────────────────────────

final BoxDecoration _cardDecoration = BoxDecoration(
  color: AppColors.panel,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: AppColors.line),
);

// ───────────────────────── Widgets ─────────────────────────

class _Avatar extends StatelessWidget {
  final String initial;
  const _Avatar({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 136,
      height: 136,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.35),
          width: 2,
        ),
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.greenSoft,
          shape: BoxShape.circle,
        ),
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w800,
            color: AppColors.greenDeep,
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.greenDeep,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: AppColors.inkFaint,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// A card that stacks rows with hairline dividers between them.
class _GroupCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.line,
                indent: 62,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final Widget child;
  const _IconBadge({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _IconBadge(child: Icon(icon, size: 18, color: AppColors.green)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
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

class _ActionRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            _IconBadge(child: leading),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.inkFaint,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact platform icon under the shop name.
/// Linked → green check badge. Not linked → faded icon with a faded plus.
class _SocialIcon extends StatelessWidget {
  final SocialLinkState link;
  final VoidCallback onTap;

  const _SocialIcon({required this.link, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final connected = link.isConnected;

    return Tooltip(
      message: link.platform.name,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: connected ? AppColors.greenSoft : AppColors.panel,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: connected ? AppColors.green : AppColors.line,
                    width: connected ? 1.5 : 1,
                  ),
                ),
                child: Opacity(
                  opacity: connected ? 1 : 0.4,
                  child: Image.asset(
                    link.platform.iconAsset,
                    width: 16,
                    height: 16,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    color: connected ? AppColors.green : AppColors.panel,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: connected ? AppColors.bg : AppColors.line,
                      width: connected ? 2 : 1,
                    ),
                  ),
                  child: Icon(
                    connected ? Icons.check : Icons.add,
                    size: 9,
                    color: connected
                        ? Colors.white
                        : AppColors.inkFaint.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}