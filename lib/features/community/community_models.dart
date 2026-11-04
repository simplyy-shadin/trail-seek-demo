class Post {
  const Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    required this.text,
    this.authorAvatarId,
    this.photoPaths = const [],
    this.placeName,
    this.lat,
    this.lng,
    this.activityId,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
    this.reportCount = 0,
  });

  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id: j['id'] as String,
        authorId: j['authorId'] as String,
        authorName: j['authorName'] as String,
        authorAvatarId: j['authorAvatarId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        text: j['text'] as String,
        photoPaths: (j['photoPaths'] as List?)?.cast<String>() ?? const [],
        placeName: j['placeName'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        activityId: j['activityId'] as String?,
        likeCount: j['likeCount'] as int? ?? 0,
        commentCount: j['commentCount'] as int? ?? 0,
        likedByMe: j['likedByMe'] as bool? ?? false,
        reportCount: j['reportCount'] as int? ?? 0,
      );

  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatarId;
  final DateTime createdAt;
  final String text;

  /// Local file paths now; Storage URLs after task 16.
  final List<String> photoPaths;
  final String? placeName;
  final double? lat;
  final double? lng;
  final String? activityId;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final int reportCount;

  bool get hidden => reportCount >= 3;

  /// `#TrekLife` style tags, lower-cased, without the hash.
  List<String> get hashtags => RegExp(r'#([A-Za-z0-9_]+)').allMatches(text).map((m) => m.group(1)!.toLowerCase()).toSet().toList();

  Post copyWith({int? likeCount, int? commentCount, bool? likedByMe, int? reportCount}) => Post(
        id: id,
        authorId: authorId,
        authorName: authorName,
        authorAvatarId: authorAvatarId,
        createdAt: createdAt,
        text: text,
        photoPaths: photoPaths,
        placeName: placeName,
        lat: lat,
        lng: lng,
        activityId: activityId,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        likedByMe: likedByMe ?? this.likedByMe,
        reportCount: reportCount ?? this.reportCount,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'authorAvatarId': authorAvatarId,
        'createdAt': createdAt.toIso8601String(),
        'text': text,
        'photoPaths': photoPaths,
        'placeName': placeName,
        'lat': lat,
        'lng': lng,
        'activityId': activityId,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'likedByMe': likedByMe,
        'reportCount': reportCount,
      };
}

class Comment {
  const Comment({required this.id, required this.postId, required this.authorId, required this.authorName, required this.text, required this.createdAt});

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id'] as String,
        postId: j['postId'] as String,
        authorId: j['authorId'] as String,
        authorName: j['authorName'] as String,
        text: j['text'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {'id': id, 'postId': postId, 'authorId': authorId, 'authorName': authorName, 'text': text, 'createdAt': createdAt.toIso8601String()};
}

enum FeedScope { all, following, nearby }

/// Public profile with social counts, as shown on a profile page and in lists.
class ProfileCard {
  const ProfileCard({
    required this.id,
    required this.displayName,
    required this.username,
    this.avatarId,
    this.bio = '',
    this.homeTown = '',
    this.followers = 0,
    this.following = 0,
    this.posts = 0,
    this.followedByMe = false,
    this.isDemo = false,
    this.xp = 0,
    this.rank,
    this.activityCount = 0,
  });

  factory ProfileCard.fromRow(Map<String, dynamic> r) => ProfileCard(
        id: r['id'] as String,
        displayName: r['display_name'] as String? ?? 'Trail Seeker',
        username: r['username'] as String? ?? '',
        avatarId: r['avatar_id'] as String?,
        bio: r['bio'] as String? ?? '',
        homeTown: r['home_town'] as String? ?? '',
        followers: (r['followers'] as num?)?.toInt() ?? 0,
        following: (r['following'] as num?)?.toInt() ?? 0,
        posts: (r['posts'] as num?)?.toInt() ?? 0,
        followedByMe: r['followed_by_me'] as bool? ?? false,
        isDemo: r['is_demo'] as bool? ?? false,
        xp: (r['xp'] as num?)?.toInt() ?? 0,
        rank: (r['rank'] as num?)?.toInt(),
        activityCount: (r['activity_count'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String displayName;
  final String username;
  final String? avatarId;
  final String bio;
  final String homeTown;
  final int followers;
  final int following;
  final int posts;
  final bool followedByMe;
  final bool isDemo;
  final int xp;

  /// 1 = top of the leaderboard.
  final int? rank;
  final int activityCount;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.length == 1 ? parts.first[0].toUpperCase() : (parts.first[0] + parts.last[0]).toUpperCase();
  }

  ProfileCard copyWith({int? followers, bool? followedByMe, int? rank}) => ProfileCard(
        id: id, displayName: displayName, username: username, avatarId: avatarId, bio: bio, homeTown: homeTown,
        followers: followers ?? this.followers, following: following, posts: posts, followedByMe: followedByMe ?? this.followedByMe, isDemo: isDemo,
        xp: xp, rank: rank ?? this.rank, activityCount: activityCount,
      );
}
