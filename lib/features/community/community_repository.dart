import 'dart:convert';


import '../../data/repositories/local_store.dart';
import '../../data/models/activity_record.dart';
import 'community_models.dart';
import 'explorers.dart';

/// Community data boundary. [LocalCommunityRepository] seeds demo explorers and
/// keeps everything on-device; SupabaseCommunityRepository is the cloud one.
abstract class CommunityRepository {
  /// Fires whenever the backing data changed outside a call (live updates).
  Stream<void> get changes;

  /// Re-pull from the backend (pull to refresh). No-op locally.
  Future<void> refresh();

  /// Explorers to discover, most followed first; [query] matches name, handle, town.
  Future<List<ProfileCard>> people({String query = ''});
  Future<ProfileCard?> profile(String userId);
  Future<List<ProfileCard>> followers(String userId);
  Future<List<ProfileCard>> followingOf(String userId);

  /// Completed outings of an explorer, for their character sheet.
  Future<List<ActivityRecord>> activitiesOf(String userId);

  /// Publishes the signed-in user's own outings and XP (cloud only).
  Future<void> syncMine(List<ActivityRecord> records, int xp);

  /// Turns local photo files into shareable references (URLs in the cloud).
  Future<List<String>> uploadPhotos(List<String> localPaths);
  List<Post> posts();
  List<Comment> comments(String postId);
  Set<String> following();
  Set<String> blocked();
  Future<Post> createPost(Post post);
  Future<void> deletePost(String id);
  Future<Post> updatePostText(String id, String text);
  Future<Post> toggleLike(String postId);
  Future<Comment> addComment(Comment c);
  Future<void> report(String postId, String reason);
  Future<void> setFollowing(String userId, bool follow);
  Future<void> setBlocked(String userId, bool block, {String? name});
  Map<String, String> blockedNames();
}

class LocalCommunityRepository implements CommunityRepository {
  LocalCommunityRepository(this._store);
  final LocalStore _store;

  static const _kPosts = 'community_posts';
  static const _kComments = 'community_comments';
  static const _kFollowing = 'community_following';
  static const _kBlocked = 'community_blocked';
  static const _kSeeded = 'community_seeded_v3';

  List<Post> _posts = [];
  List<Comment> _comments = [];
  bool _loaded = false;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<void> refresh() async {}

  /// Demo explorers' follow graph (who follows whom among them).
  static const _demoFollows = {
    'demo-riya': ['demo-arjun', 'demo-sneha', 'demo-meera'],
    'demo-arjun': ['demo-riya', 'demo-deepa'],
    'demo-sneha': ['demo-riya', 'demo-vishnu', 'demo-fathima'],
    'demo-fathima': ['demo-sneha'],
    'demo-nikhil': ['demo-riya', 'demo-lakshmi'],
    'demo-deepa': ['demo-arjun', 'demo-meera'],
    'demo-vishnu': ['demo-sneha'],
    'demo-anu': ['demo-riya', 'demo-meera', 'demo-sneha'],
    'demo-rahul': ['demo-deepa'],
    'demo-meera': ['demo-riya', 'demo-arjun'],
    'demo-joel': ['demo-nikhil'],
    'demo-lakshmi': ['demo-nikhil', 'demo-riya'],
  };

  @override
  Future<List<ActivityRecord>> activitiesOf(String userId) async => (await ExplorerDirectory.load()).activities[userId] ?? const [];

  @override
  Future<void> syncMine(List<ActivityRecord> records, int xp) async {}

  ExplorerDirectory? _dir;

  ProfileCard _card(String id) {
    final d = demoPeople[id];
    final ex = _dir?.byId(id);
    final mine = following();
    final followers = _demoFollows.entries.where((e) => e.value.contains(id)).length + (mine.contains(id) ? 1 : 0);
    if (d == null) {
      final p = _posts.where((p) => p.authorId == id).firstOrNull;
      return ProfileCard(id: id, displayName: p?.authorName ?? 'Trail Seeker', username: '', avatarId: p?.authorAvatarId, followers: followers, posts: _posts.where((p) => p.authorId == id).length, followedByMe: mine.contains(id));
    }
    final ranked = [...?_dir?.people]..sort((a, b) => b.xp.compareTo(a.xp));
    final rank = ex == null ? null : ranked.indexWhere((p) => p.id == ex.id) + 1;
    return ProfileCard(
      id: id, displayName: d.$1, username: d.$2, avatarId: ex?.avatar ?? d.$3, homeTown: d.$4, bio: ex?.bio ?? d.$5,
      followers: followers, following: (_demoFollows[id] ?? const []).length, posts: _posts.where((p) => p.authorId == id).length,
      followedByMe: mine.contains(id), isDemo: true, xp: ex?.xp ?? 0, rank: rank, activityCount: _dir?.activities[id]?.length ?? 0,
    );
  }

  @override
  Future<List<ProfileCard>> people({String query = ''}) async {
    _load();
    _dir ??= await ExplorerDirectory.load();
    final q = query.trim().toLowerCase();
    final b = blocked();
    final list = [for (final id in demoPeople.keys) if (!b.contains(id)) _card(id)]
        .where((c) => q.isEmpty || '${c.displayName} ${c.username} ${c.homeTown}'.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => b.xp.compareTo(a.xp));
    return list;
  }

  @override
  Future<ProfileCard?> profile(String userId) async {
    _load();
    _dir ??= await ExplorerDirectory.load();
    return _card(userId);
  }

  @override
  Future<List<ProfileCard>> followers(String userId) async {
    _load();
    _dir ??= await ExplorerDirectory.load();
    return [for (final e in _demoFollows.entries) if (e.value.contains(userId)) _card(e.key)];
  }

  @override
  Future<List<ProfileCard>> followingOf(String userId) async {
    _load();
    _dir ??= await ExplorerDirectory.load();
    final ids = demoPeople.containsKey(userId) ? (_demoFollows[userId] ?? const <String>[]) : following().toList();
    return [for (final id in ids) _card(id)];
  }

  /// id → (name, username, avatar, town, bio)
  static const demoPeople = <String, (String, String, String, String, String)>{
    'demo-riya': ('Riya Sharma', 'riya', 'asset:assets/images/people/riya.jpg', 'Thrissur', 'Weekend trekker. Peechi regular. Birds over summits.'),
    'demo-arjun': ('Arjun Nair', 'arjun', 'asset:assets/images/people/arjun.jpg', 'Chalakudy', 'Grew up next to Athirappilly. Hornbill count: 212.'),
    'demo-sneha': ('Sneha Thomas', 'sneha', 'asset:assets/images/people/sneha.jpg', 'Kochi', 'Organiser of the Kochi Trekkers group. Safety first.'),
    'demo-fathima': ('Fathima K', 'fathima', 'asset:assets/images/people/fathima.jpg', 'Kodungallur', 'Family treks with two kids and a very slow uncle.'),
    'demo-nikhil': ('Nikhil Menon', 'nikhil', 'asset:assets/images/people/nikhil.jpg', 'Thrissur', 'Forest walks, coracles, chai at the dam.'),
    'demo-deepa': ('Deepa Krishnan', 'deepa', 'asset:assets/images/people/deepa.jpg', 'Irinjalakuda', 'Butterfly photographer. Chimmony after the rains is home.'),
    'demo-vishnu': ('Vishnu Prasad', 'vishnu', 'asset:assets/images/people/vishnu.jpg', 'Wadakkanchery', 'Marathon runner trying trails. Falls behind on purpose.'),
    'demo-anu': ('Anu Jose', 'anu', 'asset:assets/images/people/anu.jpg', 'Guruvayur', 'Student. First trek this year, hooked.'),
    'demo-rahul': ('Rahul Varma', 'rahul', 'asset:assets/images/people/rahul.jpg', 'Palakkad', 'Peacocks, rocks and sunrise at Chulannur.'),
    'demo-meera': ('Meera Pillai', 'meera', 'asset:assets/images/people/meera.jpg', 'Thrissur', 'Forest guide trainee. Ask me about leeches.'),
    'demo-joel': ('Joel Mathew', 'joel', 'asset:assets/images/people/joel.jpg', 'Angamaly', 'Cycling the sanctuary roads one weekend at a time.'),
    'demo-lakshmi': ('Lakshmi Suresh', 'lakshmi', 'asset:assets/images/people/lakshmi.jpg', 'Chalakudy', 'Coracle convert. 40 minutes is never enough.'),
  };

  @override
  Future<List<String>> uploadPhotos(List<String> localPaths) async => localPaths;

  void _load() {
    if (_loaded) return;
    _loaded = true;
    final raw = _store.rawString(_kSeeded) == null ? null : _store.rawString(_kPosts);
    if (raw != null) {
      _posts = (jsonDecode(raw) as List).map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
    } else if (_store.rawString(_kSeeded) == null) {
      _posts = seedPosts();
      _store.setRaw(_kSeeded, '1');
      _save();
    }
    final rc = _store.rawString(_kComments);
    if (rc != null) _comments = (jsonDecode(rc) as List).map((e) => Comment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _save() async {
    await _store.setRaw(_kPosts, jsonEncode(_posts.map((p) => p.toJson()).toList()));
    await _store.setRaw(_kComments, jsonEncode(_comments.map((c) => c.toJson()).toList()));
  }

  @override
  List<Post> posts() {
    _load();
    final blocked = this.blocked();
    return _posts.where((p) => !p.hidden && !blocked.contains(p.authorId)).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  List<Comment> comments(String postId) {
    _load();
    final blocked = this.blocked();
    return _comments.where((c) => c.postId == postId && !blocked.contains(c.authorId)).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Set<String> following() => (_store.rawString(_kFollowing) ?? '').split(',').where((s) => s.isNotEmpty).toSet();

  @override
  Set<String> blocked() => (_store.rawString(_kBlocked) ?? '').split(',').where((s) => s.isNotEmpty).toSet();

  @override
  Future<Post> createPost(Post post) async {
    _load();
    _posts.add(post);
    await _save();
    return post;
  }

  @override
  Future<void> deletePost(String id) async {
    _load();
    _posts.removeWhere((p) => p.id == id);
    _comments.removeWhere((c) => c.postId == id);
    await _save();
  }

  @override
  Future<Post> updatePostText(String id, String text) async {
    _load();
    final i = _posts.indexWhere((p) => p.id == id);
    if (i < 0) throw StateError('No post $id');
    final p = _posts[i];
    final next = Post(
      id: p.id, authorId: p.authorId, authorName: p.authorName, authorAvatarId: p.authorAvatarId, createdAt: p.createdAt, text: text,
      photoPaths: p.photoPaths, placeName: p.placeName, lat: p.lat, lng: p.lng, activityId: p.activityId,
      likeCount: p.likeCount, commentCount: p.commentCount, likedByMe: p.likedByMe, reportCount: p.reportCount,
    );
    _posts[i] = next;
    await _save();
    return next;
  }

  @override
  Future<Post> toggleLike(String postId) async {
    _load();
    final i = _posts.indexWhere((p) => p.id == postId);
    if (i < 0) throw StateError('No post $postId');
    final p = _posts[i];
    final next = p.copyWith(likedByMe: !p.likedByMe, likeCount: p.likedByMe ? p.likeCount - 1 : p.likeCount + 1);
    _posts[i] = next;
    await _save();
    return next;
  }

  @override
  Future<Comment> addComment(Comment c) async {
    _load();
    _comments.add(c);
    final i = _posts.indexWhere((p) => p.id == c.postId);
    if (i >= 0) _posts[i] = _posts[i].copyWith(commentCount: _posts[i].commentCount + 1);
    await _save();
    return c;
  }

  @override
  Future<void> report(String postId, String reason) async {
    _load();
    final i = _posts.indexWhere((p) => p.id == postId);
    if (i >= 0) _posts[i] = _posts[i].copyWith(reportCount: _posts[i].reportCount + 1);
    await _save();
  }

  @override
  Future<void> setFollowing(String userId, bool follow) async {
    final f = following();
    follow ? f.add(userId) : f.remove(userId);
    await _store.setRaw(_kFollowing, f.join(','));
  }

  static const _kBlockedNames = 'community_blocked_names';

  @override
  Map<String, String> blockedNames() {
    final raw = _store.rawString(_kBlockedNames);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map).cast<String, String>();
  }

  @override
  Future<void> setBlocked(String userId, bool block, {String? name}) async {
    final b = blocked();
    block ? b.add(userId) : b.remove(userId);
    await _store.setRaw(_kBlocked, b.join(','));
    final names = blockedNames();
    if (block) {
      names[userId] = name ?? names[userId] ?? userId;
    } else {
      names.remove(userId);
    }
    await _store.setRaw(_kBlockedNames, jsonEncode(names));
  }

  /// Demo explorers' posts from the Thrissur programmes (same as the cloud seed).
  static List<Post> seedPosts({DateTime? now}) {
    final t = now ?? DateTime.now();
    Post p(String id, String author, Duration ago, String text, String place, double lat, double lng, int likes, int comments) {
      final d = demoPeople[author]!;
      return Post(id: id, authorId: author, authorName: d.$1, authorAvatarId: d.$3, createdAt: t.subtract(ago), text: text, placeName: place, lat: lat, lng: lng, likeCount: likes, commentCount: comments);
    }
    return [
      p('s1', 'demo-arjun', const Duration(hours: 2), 'Top of Athirappilly at 7:40 this morning before the day crowd. Guide Suresh spotted two great hornbills in the first kilometre. #Athirappilly #Hornbill #ForestTrek', 'Athirappilly', 10.2851, 76.5699, 9, 2),
      p('s2', 'demo-riya', const Duration(hours: 6), 'Nasika trail then straight into the coracle. 3 km up, 20 minutes floating back past the dam. Best ₹1,500 I have spent this year. #Peechi #Coracle', 'Peechi dam', 10.5309, 76.3736, 7, 1),
      p('s3', 'demo-deepa', const Duration(hours: 11), "Choorathala after last week's rain is thundering. Leeches were out in force; salt in the socks, no problem. #Chimmony #Choorathala", 'Chimmony Wildlife Sanctuary', 10.4414, 76.4487, 6, 1),
      p('s4', 'demo-rahul', const Duration(days: 1, hours: 1), 'Chulannur at sunrise. Counted 14 peacocks displaying on the laterite before 7. #Chulannur #Peafowl', 'Chulannur', 10.7179, 76.4622, 5, 1),
      p('s5', 'demo-sneha', const Duration(days: 1, hours: 5), 'Digital Rope saved us a scare on the Dam Valley trek: Vishnu stopped for photos, the app flagged him falling behind in 20 seconds, guide waited. #Peechi #GoTogether', 'Peechi dam', 10.5309, 76.3736, 8, 2),
      p('s6', 'demo-fathima', const Duration(days: 2, hours: 3), 'Took the kids on the 20-minute coracle at Peechi. Life jackets on, zero stress, big smiles. #Peechi #FamilyTrek', 'Peechi dam', 10.5309, 76.3736, 4, 0),
      p('s7', 'demo-joel', const Duration(days: 2, hours: 9), 'Panther Ride: cycled the Chimmony sanctuary road from the dam. Gaur on the verge at the 3 km mark. #Chimmony #Cycling', 'Chimmony dam', 10.4414, 76.4487, 3, 1),
      p('s8', 'demo-meera', const Duration(days: 3), 'Trainee guide diary, day 12: Elephant Saga loop with a group of six from Kochi. #Peechi #GuideLife', 'Peechi', 10.5309, 76.3736, 5, 0),
    ];
  }
}
