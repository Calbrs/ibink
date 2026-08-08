import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/session.dart';
import '../routes/app_routes.dart';
import '../widgets/notification_modals.dart';
import '../widgets/app_shimmer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  bool _isLoggingOut = false;

  Future<void> _refresh() async {
    try {
      await Session.instance.refreshProfile();
    } catch (_) {
      if (mounted) {
        NotificationService.showErrorBanner(
          context,
          message: 'Imeshindwa kupakua taarifa mpya. Jaribu tena.',
        );
      }
    } finally {
      // Done refreshing
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

    if (confirmed) {
      await _logout();
    }
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

  // Fungua in-app browser kupitia go_router (routes/app_browser.dart)
  // badala ya kufungua app nyingine (TikTok/Instagram/Facebook).
  void _openInAppBrowser(String url, String title) {
    context.push(AppRoutes.browser, extra: {'url': url, 'title': title});
  }

 void _showLinkAccountSheet() {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,   // <-- hii ndiyo inayofanya nav bar iingie kwenye dim overlay kama Orders
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Unganisha Akaunti',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Chagua mtandao wa kuunganisha na duka lako',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SocialLinkButton(
                label: 'TikTok',
                iconAsset: 'assets/icons/tik-tok.png',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openInAppBrowser('https://www.tiktok.com', 'TikTok');
                },
              ),
              const SizedBox(height: 12),
              _SocialLinkButton(
                label: 'Instagram',
                iconAsset: 'assets/icons/instagram.png',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openInAppBrowser('https://www.instagram.com', 'Instagram');
                },
              ),
              const SizedBox(height: 12),
              _SocialLinkButton(
                label: 'Facebook',
                iconAsset: 'assets/icons/facebook.png',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openInAppBrowser('https://www.facebook.com', 'Facebook');
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
  @override
  Widget build(BuildContext context) {
    final session = Session.instance;
    final shopName = session.shopName ?? 'Duka Langu';
    final initial = shopName.isNotEmpty ? shopName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.green,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Wasifu',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Material(
                    color: AppColors.panel,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.line),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.push(AppRoutes.settings),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.settings_outlined, size: 20, color: AppColors.ink),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              Center(
                child: Container(
                  width: 116,
                  height: 116,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.greenSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: AppColors.greenDeep,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (session.shopSlug != null)
                Center(
                  child: Text(
                    '@${session.shopSlug}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              const SizedBox(height: 40),

              _SectionLabel('TAARIFA ZA DUKA'),
              const SizedBox(height: 10),
              _InfoTile(label: 'Namba ya Simu', value: session.phone ?? '—'),
              const SizedBox(height: 10),
              _InfoTile(label: 'Aina ya Biashara', value: session.businessType ?? '—'),
              const SizedBox(height: 10),
              _InfoTile(
                label: 'Mahali',
                value: [session.storeDistrict, session.locationRegion]
                        .where((e) => e != null && e.isNotEmpty)
                        .join(', ')
                        .isEmpty
                    ? '—'
                    : [session.storeDistrict, session.locationRegion]
                        .where((e) => e != null && e.isNotEmpty)
                        .join(', '),
              ),
              const SizedBox(height: 10),
              _InfoTile(label: 'Mwanachama Tangu', value: _formatDate(session.createdAt)),

              if (session.storeDescription != null && session.storeDescription!.isNotEmpty) ...[
                const SizedBox(height: 24),
                _SectionLabel('KUHUSU DUKA'),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    session.storeDescription!,
                    style: const TextStyle(fontSize: 14, color: AppColors.inkSoft, height: 1.6),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              _SectionLabel('BARCODES'),
              const SizedBox(height: 10),
              Material(
                color: AppColors.panel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.line),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push(AppRoutes.barcodes),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.greenSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Image.asset('assets/icons/barcode.png', width: 18, height: 18, color: AppColors.green),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Barcodes Zangu',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Angalia, download au share barcodes za bidhaa zako',
                                style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.inkSoft),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              _SectionLabel('MITANDAO'),
              const SizedBox(height: 10),
              Material(
                color: AppColors.panel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.line),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _showLinkAccountSheet,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.link_rounded, size: 20, color: AppColors.greenDeep),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Unganisha Akaunti',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.inkSoft),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoggingOut ? null : _confirmLogout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger.withValues(alpha: 0.1),
                    foregroundColor: AppColors.danger,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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
                            Icon(Icons.logout_rounded, size: 20, color: AppColors.danger),
                            SizedBox(width: 8),
                            Text('Toka',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.danger)),
                          ],
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

// Kila field ni "stand alone" yenye subtle background inayofanana na ile ya
// button ya "Unganisha Akaunti" (AppColors.green alpha 0.08), corners za kawaida.
class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: AppColors.inkSoft, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: AppColors.ink, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// Buttons za drawer -- zinatumia icons za assets (facebook.png, tik-tok.png,
// instagram.png) na rangi za app (AppColors) badala ya rangi za brand ngumu.
class _SocialLinkButton extends StatelessWidget {
  final String label;
  final String iconAsset;
  final VoidCallback onTap;

  const _SocialLinkButton({
    required this.label,
    required this.iconAsset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.greenSoft,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(iconAsset, width: 18, height: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}