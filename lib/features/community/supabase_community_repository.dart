import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/app_user.dart';
import '../../data/models/activity_record.dart';
import 'community_models.dart';
import 'community_repository.dart';

/// Community on Supabase: `feed_posts` view for the feed, tables for follows,
/// likes, comments, reports and blocks, Storage bucket `post-photos`.
/// Keeps a cache so the controller can read synchronously; raises [changes]
/// when a fetch or a realtime event lands.
class SupabaseCommunityRepository implements CommunityRepository {
  SupabaseCommunityRepository({required SupabaseClient client, required AppUser? Function() currentUser})
      : _c = client,
        _me = currentUser;

  final SupabaseClient _c;
  final AppUser? Function() _me;
  final _changes = StreamController<void>.broadcast();
  RealtimeChannel? _channel;
  Timer? _debounce;

  List<Post> _posts = [];
  final Map<String, List<Comment>> _comments = {};
  final Set<String> _loadingComments = {};
  Set<String> _following = {};
  Map<String, String> _blocked = {};
  String? _uid;
  bool _loading = false;

  @override
  Stream<void> get changes => _changes.stream;

  void _ping() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void _ensure() {
    final uid = _me()?.id;
    if (uid == _uid) return;
    _uid = uid;
    _posts = [];
    _comments.clear();
    _following = {};
    _blocked = {};
    _channel?.unsubscribe();
    _channel = null;
    if (uid == null) return;
    unawaited(refresh());
    _channel = _c
        .channel('community')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'posts', callback: (_) => _soon())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'likes', callback: (_) => _soon())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'comments', callback: (p) {
          final pid = (p.newRecord['post_id'] ?? p.oldRecord['post_id'])?.toString();
          if (pid != null && _comments.containsKey(pid)) unawaited(_loadComments(pid));
          _soon();
        })
        .subscribe();
  }

  void _soon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => unawaited(refresh()));
  }

  /// Pulls the feed, follows and blocks.
  @override
  Future<void> refresh() async {
    final uid = _uid;
    if (uid == null || _loading) return;
    _loading = true;
    try {
      final results = await Future.wait([
        _c.from('feed_posts').select().order('created_at', ascending: false).limit(200),
        _c.from('follows').select('followee_id').eq('follower_id', uid),
        _c.from('blocks').select('blocked_id, name').eq('blocker_id', uid),
      ]);
      _posts = [for (final r in results[0]) _post(r)];
      _following = {for (final r in results[1]) r['followee_id'] as String};
      _blocked = {for (final r in results[2]) r['blocked_id'] as String: (r['name'] as String?) ?? ''};
      _ping();
    } catch (_) {
      // Offline: keep the cache.
    } finally {
      _loading = false;
    }
  }

  static Post _post(Map<String, dynamic> r) => Post(
        id: r['id'] as String,
        authorId: r['author_id'] as String,
        authorName: r['author_name'] as String? ?? 'Trail Seeker',
        authorAvatarId: r['author_avatar_id'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        text: r['text'] as String? ?? '',
        photoPaths: (r['photos'] as List?)?.cast<String>() ?? const [],
        placeName: r['place_name'] as String?,
        lat: (r['lat'] as num?)?.toDouble(),
        lng: (r['lng'] as num?)?.toDouble(),
        activityId: r['activity_id'] as String?,
        likeCount: (r['like_count'] as num?)?.toInt() ?? 0,
        commentCount: (r['comment_count'] as num?)?.toInt() ?? 0,
        likedByMe: r['liked_by_me'] as bool? ?? false,
        reportCount: (r['report_count'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Post> posts() {
    _ensure();
    return [for (final p in _posts) if (!p.hidden && !_blocked.containsKey(p.authorId)) p];
  }

  Future<void> _loadComments(String postId) async {
    if (_loadingComments.contains(postId)) return;
    _loadingComments.add(postId);
    try {
      final rows = await _c.from('comments').select('id, post_id, author_id, text, created_at, profiles(display_name)').eq('post_id', postId).order('created_at');
      _comments[postId] = [
        for (final r in rows)
          Comment(
            id: r['id'] as String,
            postId: postId,
            authorId: r['author_id'] as String,
            authorName: (r['profiles'] as Map?)?['display_name'] as String? ?? 'Trail Seeker',
            text: r['text'] as String,
            createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          ),
      ];
      _ping();
    } catch (_) {
    } finally {
      _loadingComments.remove(postId);
    }
  }

  @override
  List<Comment> comments(String postId) {
    _ensure();
    if (!_comments.containsKey(postId)) {
      _comments[postId] = const [];
      unawaited(_loadComments(postId));
    }
    return [for (final c in _comments[postId]!) if (!_blocked.containsKey(c.authorId)) c];
  }

  @override
  Set<String> following() {
    _ensure();
    return _following;
  }

  @override
  Set<String> blocked() {
    _ensure();
    return _blocked.keys.toSet();
  }

  @override
  Map<String, String> blockedNames() {
    _ensure();
    return Map.of(_blocked);
  }

  @override
  Future<List<String>> uploadPhotos(List<String> localPaths) async {
    final uid = _uid;
    if (uid == null) return const [];
    final urls = <String>[];
    for (final path in localPaths) {
      if (path.startsWith('http')) {
        urls.add(path);
        continue;
      }
      final f = File(path);
      if (!f.existsSync()) continue;
      final key = '$uid/${DateTime.now().millisecondsSinceEpoch}_${urls.length}.jpg';
      await _c.storage.from('post-photos').upload(key, f, fileOptions: const FileOptions(contentType: 'image/jpeg'));
      urls.add(_c.storage.from('post-photos').getPublicUrl(key));
    }
    return urls;
  }

  @override
  Future<Post> createPost(Post post) async {
    _ensure();
    final row = await _c
        .from('posts')
        .insert({
          'author_id': post.authorId,
          'text': post.text,
          'photos': post.photoPaths,
          'place_name': post.placeName,
          'lat': post.lat,
          'lng': post.lng,
          'activity_id': post.activityId,
        })
        .select('id, created_at')
        .single();
    final saved = Post(
      id: row['id'] as String, authorId: post.authorId, authorName: post.authorName, authorAvatarId: post.authorAvatarId,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(), text: post.text, photoPaths: post.photoPaths,
      placeName: post.placeName, lat: post.lat, lng: post.lng, activityId: post.activityId,
    );
    _posts = [saved, ..._posts];
    _ping();
    return saved;
  }

  @override
  Future<void> deletePost(String id) async {
    await _c.from('posts').delete().eq('id', id);
    _posts = _posts.where((p) => p.id != id).toList();
    _ping();
  }

  @override
  Future<Post> updatePostText(String id, String text) async {
    await _c.from('posts').update({'text': text, 'edited_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
    final i = _posts.indexWhere((p) => p.id == id);
    if (i < 0) throw StateError('No post $id');
    final p = _posts[i];
    final next = Post(
      id: p.id, authorId: p.authorId, authorName: p.authorName, authorAvatarId: p.authorAvatarId, createdAt: p.createdAt, text: text,
      photoPaths: p.photoPaths, placeName: p.placeName, lat: p.lat, lng: p.lng, activityId: p.activityId,
      likeCount: p.likeCount, commentCount: p.commentCount, likedByMe: p.likedByMe, reportCount: p.reportCount,
    );
    _posts[i] = next;
    _ping();
    return next;
  }

  @override
  Future<Post> toggleLike(String postId) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in first');
    final i = _posts.indexWhere((p) => p.id == postId);
    if (i < 0) throw StateError('No post $postId');
    final p = _posts[i];
    if (p.likedByMe) {
      await _c.from('likes').delete().eq('user_id', uid).eq('post_id', postId);
    } else {
      await _c.from('likes').upsert({'user_id': uid, 'post_id': postId}, ignoreDuplicates: true);
    }
    final next = p.copyWith(likedByMe: !p.likedByMe, likeCount: p.likedByMe ? p.likeCount - 1 : p.likeCount + 1);
    _posts[i] = next;
    _ping();
    return next;
  }

  @override
  Future<Comment> addComment(Comment c) async {
    final row = await _c.from('comments').insert({'post_id': c.postId, 'author_id': c.authorId, 'text': c.text}).select('id, created_at').single();
    final saved = Comment(id: row['id'] as String, postId: c.postId, authorId: c.authorId, authorName: c.authorName, text: c.text, createdAt: DateTime.parse(row['created_at'] as String).toLocal());
    _comments[c.postId] = [...?_comments[c.postId], saved];
    final i = _posts.indexWhere((p) => p.id == c.postId);
    if (i >= 0) _posts[i] = _posts[i].copyWith(commentCount: _posts[i].commentCount + 1);
    _ping();
    return saved;
  }

  @override
  Future<void> report(String postId, String reason) async {
    final uid = _uid;
    if (uid == null) return;
    await _c.from('reports').upsert({'post_id': postId, 'user_id': uid, 'reason': reason}, ignoreDuplicates: true);
    final i = _posts.indexWhere((p) => p.id == postId);
    if (i >= 0) _posts[i] = _posts[i].copyWith(reportCount: _posts[i].reportCount + 1);
    _ping();
  }

  @override
  Future<void> setFollowing(String userId, bool follow) async {
    final uid = _uid;
    if (uid == null || userId == uid) return;
    if (follow) {
      await _c.from('follows').upsert({'follower_id': uid, 'followee_id': userId}, ignoreDuplicates: true);
      _following = {..._following, userId};
    } else {
      await _c.from('follows').delete().eq('follower_id', uid).eq('followee_id', userId);
      _following = {..._following}..remove(userId);
    }
    _ping();
  }

  @override
  Future<void> setBlocked(String userId, bool block, {String? name}) async {
    final uid = _uid;
    if (uid == null) return;
    if (block) {
      await _c.from('blocks').upsert({'blocker_id': uid, 'blocked_id': userId, 'name': name ?? ''}, ignoreDuplicates: true);
      await _c.from('follows').delete().eq('follower_id', uid).eq('followee_id', userId);
      _blocked = {..._blocked, userId: name ?? ''};
      _following = {..._following}..remove(userId);
    } else {
      await _c.from('blocks').delete().eq('blocker_id', uid).eq('blocked_id', userId);
      _blocked = Map.of(_blocked)..remove(userId);
    }
    _ping();
  }

  // ------------------------------------------------------------ people

  @override
  Future<List<ProfileCard>> people({String query = ''}) async {
    var q = _c.from('profile_cards').select();
    final t = query.trim();
    if (t.isNotEmpty) q = q.or('display_name.ilike.%$t%,username.ilike.%$t%,home_town.ilike.%$t%');
    final rows = await q.order('xp', ascending: false).limit(100);
    return [for (final r in rows) if (r['id'] != _uid && !_blocked.containsKey(r['id'])) ProfileCard.fromRow(r)];
  }

  @override
  Future<ProfileCard?> profile(String userId) async {
    final r = await _c.from('profile_cards').select().eq('id', userId).maybeSingle();
    return r == null ? null : ProfileCard.fromRow(r);
  }

  @override
  Future<List<ProfileCard>> followers(String userId) async {
    final ids = [for (final r in await _c.from('follows').select('follower_id').eq('followee_id', userId)) r['follower_id'] as String];
    if (ids.isEmpty) return const [];
    return [for (final r in await _c.from('profile_cards').select().inFilter('id', ids)) ProfileCard.fromRow(r)];
  }

  @override
  Future<List<ProfileCard>> followingOf(String userId) async {
    final ids = [for (final r in await _c.from('follows').select('followee_id').eq('follower_id', userId)) r['followee_id'] as String];
    if (ids.isEmpty) return const [];
    return [for (final r in await _c.from('profile_cards').select().inFilter('id', ids)) ProfileCard.fromRow(r)];
  }

  @override
  Future<List<ActivityRecord>> activitiesOf(String userId) async {
    final rows = await _c.from('activities').select('data').eq('user_id', userId).order('ended_at', ascending: false).limit(500);
    return [for (final r in rows) ActivityRecord.fromJson((r['data'] as Map).cast<String, dynamic>())];
  }

  @override
  Future<void> syncMine(List<ActivityRecord> records, int xp) async {
    final uid = _uid ?? _me()?.id;
    if (uid == null) return;
    final real = records.where((r) => !r.simulated).toList();
    if (real.isNotEmpty) {
      await _c.from('activities').upsert([
        for (final r in real) {'id': '$uid-${r.id}', 'user_id': uid, 'data': r.toJson(), 'ended_at': r.endedAt.toUtc().toIso8601String()},
      ]);
    }
    await _c.from('profiles').update({'xp': xp, 'activity_count': real.length}).eq('id', uid);
  }

  void dispose() {
    _debounce?.cancel();
    _channel?.unsubscribe();
    _changes.close();
  }
}
