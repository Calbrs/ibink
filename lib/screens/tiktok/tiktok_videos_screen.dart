import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_logger.dart';
import '../../core/theme.dart';
import '../../core/tiktok_service.dart';
import '../../models/tiktok_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_shimmer.dart';
import '../../widgets/tiktok_ui.dart';

const String _tag = 'TikTokVideos';

class TikTokVideosScreen extends StatefulWidget {
  const TikTokVideosScreen({super.key});

  @override
  State<TikTokVideosScreen> createState() => _TikTokVideosScreenState();
}

class _TikTokVideosScreenState extends State<TikTokVideosScreen> {
  bool _isLoading = true;
  String? _error;
  List<TikTokVideo> _videos = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final videos = await TikTokService.instance.getVideos();
    if (!mounted) return;

    AppLogger.instance.info(_tag, 'Loaded ${videos.length} video(s).');
    setState(() {
      _videos = videos;
      _isLoading = false;
      _error = null;
    });
  }

  void _openVideo(TikTokVideo video) {
    context.push(
      AppRoutes.tiktokVideoPlayer,
      extra: {
        'id': video.id,
        'title': video.title ?? video.description ?? 'Video',
        'embed': video.embedLink,
      },
    );
  }

  String get _emptyMessage {
    final service = TikTokService.instance;
    if (service.error != null) return service.error!;
    return 'Video utakapozipanga kwenye TikTok zitaonekana hapa.';
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: ttAppBar(
        context,
        title: 'Video',
        actions: [
          IconButton(
            tooltip: 'Onyesha upya',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.ink),
            onPressed: _load,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.green,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: SizedBox(width: 28, height: 28, child: AppShimmerSpinner()),
      );
    }

    if (_error != null) {
      return TtMessageState(
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.danger,
        title: 'Imeshindwa kupakua',
        message: _error!,
        actionLabel: 'Jaribu Tena',
        onAction: _load,
      );
    }

    if (_videos.isEmpty) {
      return TtMessageState(
        icon: Icons.videocam_off_outlined,
        iconColor: AppColors.inkFaint,
        title: 'Hakuna video',
        message: _emptyMessage,
        actionLabel: 'Onyesha upya',
        onAction: _load,
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                const Expanded(child: TtSectionLabel('Video zako')),
                TtPill(text: '${_videos.length} video'),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => TikTokVideoTile(
                video: _videos[index],
                onTap: () => _openVideo(_videos[index]),
              ),
              childCount: _videos.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Tile ─────────────────────────

class TikTokVideoTile extends StatelessWidget {
  final TikTokVideo video;
  final VoidCallback onTap;

  const TikTokVideoTile({
    super.key,
    required this.video,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = (video.title?.isNotEmpty == true)
        ? video.title!
        : (video.description?.isNotEmpty == true ? video.description! : null);

    return Material(
      color: AppColors.panel,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        key: Key('video_tile_${video.id}'),
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Cover(url: video.coverImageUrl),
            // Gradient ya chini kusaidia maandishi yasomeke.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 72,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.62),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.32),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 1.3,
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  video.formattedDuration,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (title != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 11,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final String? url;
  const _Cover({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _placeholder();

    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _placeholder(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: AppColors.greenSoft,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: AppColors.green,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.greenSoft,
      child: const Center(
        child: Icon(Icons.videocam_rounded, color: AppColors.green, size: 28),
      ),
    );
  }
}