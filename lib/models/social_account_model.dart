import 'tiktok_model.dart' hide TikTokVideo;

enum SocialPlatform {
  tiktok,
  instagram,
  facebook,
  youtube,
  twitter,
}

extension SocialPlatformExtension on SocialPlatform {
  String get name {
    switch (this) {
      case SocialPlatform.tiktok:
        return 'TikTok';
      case SocialPlatform.instagram:
        return 'Instagram';
      case SocialPlatform.facebook:
        return 'Facebook';
      case SocialPlatform.youtube:
        return 'YouTube';
      case SocialPlatform.twitter:
        return 'Twitter';
    }
  }

  String get iconAsset {
    switch (this) {
      case SocialPlatform.tiktok:
        return 'assets/icons/tik-tok.png';
      case SocialPlatform.instagram:
        return 'assets/icons/instagram.png';
      case SocialPlatform.facebook:
        return 'assets/icons/facebook.png';
      case SocialPlatform.youtube:
        return 'assets/icons/youtube.png';
      case SocialPlatform.twitter:
        return 'assets/icons/twitter.png';
    }
  }

  String get brandColorHex {
    switch (this) {
      case SocialPlatform.tiktok:
        return '#000000';
      case SocialPlatform.instagram:
        return '#E4405F';
      case SocialPlatform.facebook:
        return '#1877F2';
      case SocialPlatform.youtube:
        return '#FF0000';
      case SocialPlatform.twitter:
        return '#1DA1F2';
    }
  }
}

abstract class SocialAccount {
  final SocialPlatform platform;
  final String? displayName;
  final String? username;
  final String? avatarUrl;
  final String? bioDescription;
  final bool isVerified;
  final int followerCount;
  final int followingCount;
  final int postsCount;

  const SocialAccount({
    required this.platform,
    this.displayName,
    this.username,
    this.avatarUrl,
    this.bioDescription,
    this.isVerified = false,
    this.followerCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
  });

  String get formattedFollowers {
    if (followerCount >= 1000000) {
      return '${(followerCount / 1000000).toStringAsFixed(1)}M';
    } else if (followerCount >= 1000) {
      return '${(followerCount / 1000).toStringAsFixed(1)}K';
    }
    return followerCount.toString();
  }

  String get formattedPosts {
    if (postsCount >= 1000000) {
      return '${(postsCount / 1000000).toStringAsFixed(1)}M';
    } else if (postsCount >= 1000) {
      return '${(postsCount / 1000).toStringAsFixed(1)}K';
    }
    return postsCount.toString();
  }
}

class TikTokSocialAccount extends SocialAccount {
  final int likesCount;

  const TikTokSocialAccount({
    super.displayName,
    super.username,
    super.avatarUrl,
    super.bioDescription,
    super.isVerified,
    super.followerCount,
    super.followingCount,
    this.likesCount = 0,
    super.postsCount,
  }) : super(
          platform: SocialPlatform.tiktok,
        );

  factory TikTokSocialAccount.fromTikTokProfile(TikTokProfile profile) {
    return TikTokSocialAccount(
      displayName: profile.displayName,
      username: profile.username,
      avatarUrl: profile.avatarUrl,
      bioDescription: profile.bioDescription,
      isVerified: profile.isVerified,
      followerCount: profile.followerCount,
      followingCount: profile.followingCount,
      likesCount: profile.likesCount,
      postsCount: profile.videoCount,
    );
  }
}

class InstagramSocialAccount extends SocialAccount {
  const InstagramSocialAccount({
    super.displayName,
    super.username,
    super.avatarUrl,
    super.bioDescription,
    super.isVerified,
    super.followerCount,
    super.followingCount,
    super.postsCount,
  }) : super(
          platform: SocialPlatform.instagram,
        );
}

class FacebookSocialAccount extends SocialAccount {
  const FacebookSocialAccount({
    super.displayName,
    super.username,
    super.avatarUrl,
    super.bioDescription,
    super.isVerified,
    super.followerCount,
    super.followingCount,
    super.postsCount,
  }) : super(
          platform: SocialPlatform.facebook,
        );
}

class SocialAccountConnection {
  final SocialPlatform platform;
  final bool isConnected;
  final SocialAccount? account;
  final DateTime? connectedAt;

  const SocialAccountConnection({
    required this.platform,
    this.isConnected = false,
    this.account,
    this.connectedAt,
  });

  factory SocialAccountConnection.disconnected(SocialPlatform platform) {
    return SocialAccountConnection(
      platform: platform,
      isConnected: false,
    );
  }
}

class SocialVideo {
  final String id;
  final String? title;
  final String? description;
  final String? thumbnailUrl;
  final String? videoUrl;
  final int? duration;
  final DateTime? createdAt;

  const SocialVideo({
    required this.id,
    this.title,
    this.description,
    this.thumbnailUrl,
    this.videoUrl,
    this.duration,
    this.createdAt,
  });

  factory SocialVideo.fromTikTokVideo(TikTokVideo video) {
    return SocialVideo(
      id: video.id,
      title: video.title,
      description: video.description,
      thumbnailUrl: video.coverImageUrl,
      duration: video.duration,
      createdAt: video.createdAt,
    );
  }
}

class TikTokVideo {
  final String id;
  final String? title;
  final String? description;
  final String? coverImageUrl;
  final String? embedLink;
  final int? duration;
  final DateTime? createdAt;

  const TikTokVideo({
    required this.id,
    this.title,
    this.description,
    this.coverImageUrl,
    this.embedLink,
    this.duration,
    this.createdAt,
  });

  factory TikTokVideo.fromJson(Map<String, dynamic> json) {
    return TikTokVideo(
      id: json['id'] as String,
      title: json['title'] as String?,
      description: json['video_description'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      embedLink: json['embed_link'] as String?,
      duration: json['duration'] as int?,
      createdAt: json['create_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['create_time'] as int) * 1000)
          : null,
    );
  }

  String get formattedDuration {
    if (duration == null) return '0:00';
    final minutes = (duration! / 60).floor();
    final seconds = (duration! % 60).floor();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}