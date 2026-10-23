import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/tiktok_model.dart';

/// Header for a connected TikTok account.
///
/// Layout: a large avatar on the left, the account name and username to its
/// right, and the unlink control on that same horizontal line. The bio and the
/// follower/following/likes/videos counts sit underneath.
///
/// Extracted from TikTokScreen so the layout can be tested directly — the
/// screen itself depends on a singleton TikTokService that talks to the
/// network.
class TikTokProfileHeader extends StatelessWidget {
  final TikTokProfile profile;

  /// Omit to hide the unlink control — the TikTok screen now renders it in the
  /// app bar instead, so the two buttons line up on one row.
  final VoidCallback? onUnlink;

  const TikTokProfileHeader({
    super.key,
    required this.profile,
    this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    final hasBio =
        profile.bioDescription != null && profile.bioDescription!.isNotEmpty;

    return Container(
      color: AppColors.bg,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatar(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.displayName ?? 'TikTok User',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            color: Color(0xFF25F4EE),
                            size: 19,
                          ),
                        ],
                      ],
                    ),
                    if (profile.username != null &&
                        profile.username!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          '@${profile.username}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.inkSoft,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              // Only takes space when an unlink handler is supplied.
              if (onUnlink != null) ...[
                const SizedBox(width: 12),
                _buildUnlinkButton(),
              ],
            ],
          ),

          if (hasBio) ...[
            const SizedBox(height: 14),
            Text(
              profile.bioDescription!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.inkSoft,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 18),
          _buildStatsBar(),
        ],
      ),
    );
  }

  Widget _buildUnlinkButton() {
    return Material(
      color: AppColors.danger.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        key: const Key('tiktok_header_unlink'),
        borderRadius: BorderRadius.circular(999),
        onTap: onUnlink!,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_off, size: 15, color: AppColors.danger),
              const SizedBox(width: 6),
              const Text(
                'Ondoa',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final hasAvatar =
        profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty;

    return Container(
      key: const Key('tiktok_header_avatar'),
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.line, width: 2),
      ),
      child: ClipOval(
        child: hasAvatar
            ? Image.network(
                profile.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _avatarFallback(),
              )
            : _avatarFallback(),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: AppColors.greenSoft,
      child: const Icon(Icons.person, color: AppColors.green, size: 40),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _buildStatColumn(profile.formattedFollowers, 'Wafuasi'),
          _buildVerticalDivider(),
          _buildStatColumn(profile.formattedFollowing, 'Wanaofuata'),
          _buildVerticalDivider(),
          _buildStatColumn(profile.formattedLikes, 'Mapendeleo'),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 32, color: AppColors.line);
  }
}