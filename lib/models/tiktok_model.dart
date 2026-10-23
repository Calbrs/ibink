class TikTokProfile {
  final String? displayName;
  final String? username;
  final String? avatarUrl;
  final String? bioDescription;
  final bool isVerified;
  final int followerCount;
  final int followingCount;
  final int likesCount;
  final int videoCount;

  const TikTokProfile({
    this.displayName,
    this.username,
    this.avatarUrl,
    this.bioDescription,
    this.isVerified = false,
    this.followerCount = 0,
    this.followingCount = 0,
    this.likesCount = 0,
    this.videoCount = 0,
  });

  factory TikTokProfile.fromJson(Map<String, dynamic> json) {
    return TikTokProfile(
      displayName: json['display_name'] as String?,
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bioDescription: json['bio_description'] as String?,
      isVerified: json['is_verified'] ?? false,
      followerCount: json['follower_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      likesCount: json['likes_count'] ?? 0,
      videoCount: json['video_count'] ?? 0,
    );
  }

  String get formattedFollowers {
    if (followerCount >= 1000000) {
      return '${(followerCount / 1000000).toStringAsFixed(1)}M';
    } else if (followerCount >= 1000) {
      return '${(followerCount / 1000).toStringAsFixed(1)}K';
    }
    return followerCount.toString();
  }

  String get formattedFollowing {
    if (followingCount >= 1000000) {
      return '${(followingCount / 1000000).toStringAsFixed(1)}M';
    } else if (followingCount >= 1000) {
      return '${(followingCount / 1000).toStringAsFixed(1)}K';
    }
    return followingCount.toString();
  }

  String get formattedLikes {
    if (likesCount >= 1000000) {
      return '${(likesCount / 1000000).toStringAsFixed(1)}M';
    } else if (likesCount >= 1000) {
      return '${(likesCount / 1000).toStringAsFixed(1)}K';
    }
    return likesCount.toString();
  }

  String get formattedVideos {
    if (videoCount >= 1000000) {
      return '${(videoCount / 1000000).toStringAsFixed(1)}M';
    } else if (videoCount >= 1000) {
      return '${(videoCount / 1000).toStringAsFixed(1)}K';
    }
    return videoCount.toString();
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
