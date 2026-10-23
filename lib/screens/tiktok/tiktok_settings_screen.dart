import 'package:flutter/material.dart';

import '../../core/app_logger.dart';
import '../../core/theme.dart';
import '../../core/tiktok_settings_service.dart';
import '../../models/tiktok_settings.dart';
import '../../widgets/app_shimmer.dart';
import '../../widgets/notification_modals.dart';
import '../../widgets/tiktok_ui.dart';

const String _tag = 'TikTokSettingsUI';

/// Mipangilio ya kuchapisha ya akaunti ya TikTok.
///
/// Kila kitu hapa kimewekewa mipaka na kile akaunti inaruhusu: orodha ya
/// faragha ina viwango vilivyoripotiwa na TikTok tu, na ruhusa ambazo muuzaji
/// amezizima kwenye TikTok zinaonekana zimefifia pamoja na sababu.
class TikTokSettingsScreen extends StatefulWidget {
  const TikTokSettingsScreen({super.key});

  @override
  State<TikTokSettingsScreen> createState() => _TikTokSettingsScreenState();
}

class _TikTokSettingsScreenState extends State<TikTokSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Pakia upya ukifunguliwa ili chaguo zionyeshe hali ya sasa ya akaunti.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TikTokSettingsService.instance.refreshCreatorInfo();
    });
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: ttAppBar(context, title: 'Mipangilio ya TikTok'),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: TikTokSettingsService.instance,
          builder: (context, _) => _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final service = TikTokSettingsService.instance;
    final settings = service.settings;
    final creator = service.creator;

    if (service.isLoading && creator == null) {
      return const Center(
        child: SizedBox(width: 28, height: 28, child: AppShimmerSpinner()),
      );
    }

    if (creator == null) {
      return TtMessageState(
        icon: Icons.info_outline_rounded,
        title: 'Mipangilio haipatikani',
        message: 'Imeshindwa kupakia mipangilio ya akaunti ya TikTok. '
            'Hakiki kuwa umeunganishwa.',
        actionLabel: 'Jaribu Tena',
        onAction: () => TikTokSettingsService.instance.refreshCreatorInfo(),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _creatorHeader(creator),
        if (creator.isPrivateOnly) ...[
          const SizedBox(height: 20),
          const TtNotice(
            icon: Icons.lock_outline_rounded,
            text: 'Akaunti yako bado haijasajiliwa kwenye TikTok Developers, '
                'kwa hivyo TikTok inaruhusu posti faragha pekee. '
                'Ukishajiliwa, chaguo zaidi zitaonekana hapa.',
          ),
        ],
        const SizedBox(height: 28),
        _modeSection(settings),
        const SizedBox(height: 24),
        _privacySection(creator, settings),
        const SizedBox(height: 24),
        _interactionsSection(creator, settings),
        const SizedBox(height: 24),
        _extraSection(settings),
        const SizedBox(height: 32),
        _saveSection(),
      ],
    );
  }

  // ───────────────────────── Sections ─────────────────────────

  Widget _creatorHeader(TikTokCreator creator) {
    final nickname = creator.nickname;
    final initial = nickname.isNotEmpty ? nickname[0].toUpperCase() : '?';
    final username = creator.username;

    return Column(
      children: [
        TtAvatar(
          initial: initial,
          size: 92,
          imageUrl: creator.avatarUrl,
        ),
        const SizedBox(height: 14),
        Text(
          nickname,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.3,
          ),
        ),
        if (username != null && username.isNotEmpty) ...[
          const SizedBox(height: 8),
          TtPill(text: '@$username'),
        ],
      ],
    );
  }

  Widget _modeSection(TikTokPostSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TtSectionLabel('Jinsi ya kuchapisha'),
        const SizedBox(height: 10),
        _optionTile(
          key: const Key('tiktok_mode_draft'),
          selected: settings.mode == TikTokPostMode.draft,
          icon: Icons.drafts_outlined,
          title: 'Draft',
          subtitle: 'Pika kwenda kwenye TikTok inbox. Unaimaliza mwenyewe '
              'kwenye TikTok app. Inafanya kazi kwa kila muuzaji.',
          onTap: () =>
              TikTokSettingsService.instance.setMode(TikTokPostMode.draft),
        ),
        const SizedBox(height: 10),
        _optionTile(
          key: const Key('tiktok_mode_direct'),
          selected: settings.mode == TikTokPostMode.direct,
          icon: Icons.bolt_rounded,
          title: 'Moja kwa moja',
          subtitle: 'Posti moja kwa moja kwenye profile. Inahitaji '
              'idhini ya TikTok Developers, na hadi ipo faragha pekee.',
          onTap: () =>
              TikTokSettingsService.instance.setMode(TikTokPostMode.direct),
        ),
      ],
    );
  }

  Widget _privacySection(TikTokCreator creator, TikTokPostSettings settings) {
    final options = creator.privacyLevelOptions;
    final value = options.contains(settings.privacyLevel)
        ? settings.privacyLevel
        : creator.defaultPrivacyLevel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TtSectionLabel('Nani anaweza kuona post'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: ttCardDecoration,
          child: Row(
            children: [
              const TtIconBadge(
                child: Icon(Icons.visibility_outlined,
                    size: 18, color: AppColors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: const Key('tiktok_privacy_dropdown'),
                    value: value,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(16),
                    dropdownColor: AppColors.panel,
                    icon: const Icon(Icons.expand_more_rounded,
                        color: AppColors.inkFaint),
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                    items: options
                        .map((o) => DropdownMenuItem(
                              value: o,
                              child: Text(tiktokPrivacyLabel(o)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        TikTokSettingsService.instance.setPrivacy(v);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Chaguo hili linatoka kwenye akaunti yako ya TikTok, si kwenye '
            'programu. Huwezi kuchagua zaidi ya yale TikTok imeruhusu.',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.inkSoft,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _interactionsSection(
      TikTokCreator creator, TikTokPostSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TtSectionLabel('Ruhusa za post'),
        const SizedBox(height: 10),
        TtGroupCard(
          children: [
            _toggleRow(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Ruhusu maoni',
              value: creator.commentDisabled ? false : settings.allowComments,
              enabled: !creator.commentDisabled,
              disabledHint: 'Umeyazisha maoni kwenye TikTok',
              onChanged: TikTokSettingsService.instance.setComments,
            ),
            _toggleRow(
              icon: Icons.people_outline_rounded,
              label: 'Ruhusu Duet',
              value: creator.duetDisabled ? false : settings.allowDuet,
              enabled: !creator.duetDisabled,
              disabledHint: 'Umeyazisha Duet kwenye TikTok',
              onChanged: TikTokSettingsService.instance.setDuet,
            ),
            _toggleRow(
              icon: Icons.content_cut_rounded,
              label: 'Ruhusu Stitch',
              value: creator.stitchDisabled ? false : settings.allowStitch,
              enabled: !creator.stitchDisabled,
              disabledHint: 'Umeyazisha Stitch kwenye TikTok',
              onChanged: TikTokSettingsService.instance.setStitch,
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Vizuo hivi huwezi kuwasha kama umeyazisha kwenye TikTok mwenyewe.',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.inkSoft,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _extraSection(TikTokPostSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TtSectionLabel('Zingine'),
        const SizedBox(height: 10),
        TtGroupCard(
          children: [
            _toggleRow(
              icon: Icons.auto_awesome_outlined,
              label: 'Weka alama ya AI',
              value: settings.isAigc,
              enabled: true,
              subtitle: 'Weka alama "AI-generated" kwenye post kama video '
                  'ilitengenezwa na AI.',
              onChanged: TikTokSettingsService.instance.setAigc,
            ),
          ],
        ),
      ],
    );
  }

  Widget _saveSection() {
    return Column(
      children: [
        TtButton(
          key: const Key('tiktok_settings_save'),
          label: 'Hifadhi Mipangilio',
          icon: const Icon(Icons.check_rounded, size: 20),
          onPressed: () async {
            await TikTokSettingsService.instance.flush();
            if (!mounted) return;
            NotificationService.showSuccessBanner(
              context,
              message: 'Mipangilio imehifadhiwa.',
            );
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: () async {
            await TikTokSettingsService.instance.resetToAccountDefaults();
            if (!mounted) return;
            AppLogger.instance.info(_tag, 'settings reset to account defaults');
          },
          icon: const Icon(Icons.restart_alt_rounded,
              size: 16, color: AppColors.inkSoft),
          label: const Text(
            'Rudisha kwa chaguo la akaunti',
            style: TextStyle(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────── Building blocks ─────────────────────────

  Widget _optionTile({
    required Key key,
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      key: key,
      color: selected ? AppColors.greenSoft : AppColors.panel,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.green : AppColors.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.green),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: selected ? AppColors.greenDeep : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 20,
                  color: selected ? AppColors.green : AppColors.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
    String? disabledHint,
    String? subtitle,
  }) {
    final hint = !enabled ? disabledHint : subtitle;

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      value: value,
      // Ruhusa iliyozimwa kwenye TikTok haiwezi kuwashwa hapa, lakini muuzaji
      // bado anaweza kuzima kitu ambacho akaunti inaruhusu.
      onChanged: enabled ? onChanged : null,
      activeThumbColor: AppColors.green,
      activeTrackColor: AppColors.green.withValues(alpha: 0.35),
      secondary: TtIconBadge(
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.green : AppColors.inkFaint,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: enabled ? AppColors.ink : AppColors.inkFaint,
        ),
      ),
      subtitle: hint == null
          ? null
          : Text(
              hint,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: enabled ? AppColors.inkSoft : AppColors.inkFaint,
              ),
            ),
    );
  }
}