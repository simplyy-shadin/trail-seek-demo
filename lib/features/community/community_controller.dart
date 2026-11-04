import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/backend.dart';
import '../../app/providers.dart';
import 'supabase_community_repository.dart';
import '../../data/models/activity_record.dart';
import 'community_models.dart';
import 'community_repository.dart';

/// Supabase when the build carries its config, else on-device.
final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  if (Backend.isCloud) {
    final repo = SupabaseCommunityRepository(client: Backend.client, currentUser: () => ref.read(authProvider));
    ref.onDispose(repo.dispose);
    return repo;
  }
  return LocalCommunityRepository(ref.read(localStoreProvider));
});

@immutable
class CommunityState {
  const CommunityState({required this.posts, required this.following, required this.blocked, this.tag});
  final List<Post> posts;
  final Set<String> following;
  final Set<String> blocked;

  /// Active hashtag filter (lower-case, no hash).
  final String? tag;

  CommunityState copyWith({List<Post>? posts, Set<String>? following, Set<String>? blocked, String? tag, bool clearTag = false}) => CommunityState(
        posts: posts ?? this.posts,
        following: following ?? this.following,
        blocked: blocked ?? this.blocked,
        tag: clearTag ? null : (tag ?? this.tag),
      );
}

class CommunityController extends Notifier<CommunityState> {
  CommunityRepository get _repo => ref.read(communityRepositoryProvider);

  @override
  CommunityState build() {
    final sub = _repo.changes.listen((_) => _refresh());
    ref.onDispose(sub.cancel);
    // A different user signs in: the cloud repository re-subscribes on next read.
    ref.listen(authProvider, (_, _) => _refresh());
    // Keep my outings and XP on the leaderboard.
    ref.listen(progressProvider, (_, p) {
      if (ref.read(authProvider) != null) _repo.syncMine(ref.read(activitiesProvider), p.totalXp).catchError((_) {});
    });
    return CommunityState(posts: _repo.posts(), following: _repo.following(), blocked: _repo.blocked());
  }

  void _refresh() => state = state.copyWith(posts: _repo.posts(), following: _repo.following(), blocked: _repo.blocked());

  List<Post> feed(FeedScope scope, {double? lat, double? lng, double nearbyKm = 50}) {
    var list = state.posts;
    switch (scope) {
      case FeedScope.all:
        break;
      case FeedScope.following:
        list = list.where((p) => state.following.contains(p.authorId) || p.authorId == ref.read(authProvider)?.id).toList();
      case FeedScope.nearby:
        if (lat == null || lng == null) return const [];
        list = list.where((p) => p.lat != null && p.lng != null && _km(lat, lng, p.lat!, p.lng!) <= nearbyKm).toList();
    }
    final tag = state.tag;
    if (tag != null) list = list.where((p) => p.hashtags.contains(tag)).toList();
    return list;
  }

  void setTag(String? tag) => state = tag == null ? state.copyWith(clearTag: true) : state.copyWith(tag: tag.toLowerCase());

  Future<Post?> post({required String text, List<String> photoPaths = const [], String? placeName, double? lat, double? lng, String? activityId}) async {
    final user = ref.read(authProvider);
    if (user == null || text.trim().isEmpty && photoPaths.isEmpty) return null;
    final refs = await _repo.uploadPhotos(photoPaths);
    final p = Post(
      id: const Uuid().v4(),
      authorId: user.id,
      authorName: user.displayName,
      authorAvatarId: user.avatarId,
      createdAt: DateTime.now(),
      text: text.trim(),
      photoPaths: refs,
      placeName: placeName,
      lat: lat,
      lng: lng,
      activityId: activityId,
    );
    await _repo.createPost(p);
    _refresh();
    return p;
  }

  Future<void> refresh() async {
    await _repo.refresh();
    _refresh();
  }

  Future<List<ProfileCard>> people({String query = ''}) => _repo.people(query: query);
  Future<ProfileCard?> profile(String id) => _repo.profile(id);
  Future<List<ProfileCard>> followers(String id) => _repo.followers(id);
  Future<List<ProfileCard>> followingOf(String id) => _repo.followingOf(id);
  Future<List<ActivityRecord>> activitiesOf(String id) => _repo.activitiesOf(id);

  /// Posts by one author, newest first.
  List<Post> postsBy(String userId) => state.posts.where((p) => p.authorId == userId).toList();

  Future<void> toggleLike(String id) async {
    // Optimistic flip, then persist.
    state = state.copyWith(posts: [for (final p in state.posts) p.id == id ? p.copyWith(likedByMe: !p.likedByMe, likeCount: p.likedByMe ? p.likeCount - 1 : p.likeCount + 1) : p]);
    await _repo.toggleLike(id);
    _refresh();
  }

  Future<void> comment(String postId, String text) async {
    final user = ref.read(authProvider);
    if (user == null || text.trim().isEmpty) return;
    await _repo.addComment(Comment(id: const Uuid().v4(), postId: postId, authorId: user.id, authorName: user.displayName, text: text.trim(), createdAt: DateTime.now()));
    _refresh();
  }

  List<Comment> comments(String postId) => _repo.comments(postId);

  Future<void> edit(String id, String text) async {
    if (text.trim().isEmpty) return;
    await _repo.updatePostText(id, text.trim());
    _refresh();
  }

  Future<void> delete(String id) async {
    await _repo.deletePost(id);
    _refresh();
  }

  Future<void> report(String id, String reason) async {
    await _repo.report(id, reason);
    _refresh();
  }

  Future<void> follow(String userId, bool f) async {
    await _repo.setFollowing(userId, f);
    _refresh();
  }

  Future<void> block(String userId, {String? name}) async {
    await _repo.setBlocked(userId, true, name: name);
    _refresh();
  }

  Future<void> unblock(String userId) async {
    await _repo.setBlocked(userId, false);
    _refresh();
  }

  Map<String, String> blockedNames() => _repo.blockedNames();

  static double _km(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = _sin2(dLat / 2) + _cos(_rad(lat1)) * _cos(_rad(lat2)) * _sin2(dLng / 2);
    return 2 * r * _asin(_sqrt(a));
  }

  static double _rad(double d) => d * 3.141592653589793 / 180;
  static double _sin2(double x) {
    final s = _sin(x);
    return s * s;
  }

  static double _sin(double a) => _series(a, false);
  static double _cos(double a) => _series(a, true);
  static double _sqrt(double x) {
    if (x <= 0) return 0;
    var g = x;
    for (var i = 0; i < 30; i++) {
      g = 0.5 * (g + x / g);
    }
    return g;
  }

  static double _asin(double x) {
    var y = x;
    for (var i = 0; i < 12; i++) {
      y -= (_sin(y) - x) / _cos(y);
    }
    return y;
  }

  static double _series(double a, bool cos) {
    const pi = 3.141592653589793;
    a = a % (2 * pi);
    if (a > pi) a -= 2 * pi;
    if (a < -pi) a += 2 * pi;
    double term = cos ? 1 : a;
    double sum = term;
    final a2 = a * a;
    for (var n = 1; n < 12; n++) {
      final k = cos ? (2 * n - 1) * (2 * n) : (2 * n) * (2 * n + 1);
      term *= -a2 / k;
      sum += term;
    }
    return sum;
  }
}

final communityProvider = NotifierProvider<CommunityController, CommunityState>(CommunityController.new);
