import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trailseek/data/repositories/local_store.dart';
import 'package:trailseek/features/community/community_models.dart';
import 'package:trailseek/features/community/community_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalCommunityRepository repo;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = LocalCommunityRepository(LocalStore(await SharedPreferences.getInstance()));
  });

  test('seeds demo posts once and persists them', () async {
    expect(repo.posts().length, 8);
    await repo.deletePost('s1');
    final again = LocalCommunityRepository(LocalStore(await SharedPreferences.getInstance()));
    expect(again.posts().length, 7);
  });

  test('like toggles exactly once per tap', () async {
    final before = repo.posts().first;
    final liked = await repo.toggleLike(before.id);
    expect(liked.likedByMe, isTrue);
    expect(liked.likeCount, before.likeCount + 1);
    final unliked = await repo.toggleLike(before.id);
    expect(unliked.likeCount, before.likeCount);
  });

  test('blocked authors disappear from feed and comments', () async {
    final target = repo.posts().first;
    await repo.addComment(Comment(id: 'c1', postId: 's2', authorId: target.authorId, authorName: target.authorName, text: 'hi', createdAt: DateTime.now()));
    await repo.setBlocked(target.authorId, true);
    expect(repo.posts().any((p) => p.authorId == target.authorId), isFalse);
    expect(repo.comments('s2'), isEmpty);
  });

  test('three reports hide a post', () async {
    final id = repo.posts().first.id;
    await repo.report(id, 'spam');
    await repo.report(id, 'spam');
    expect(repo.posts().any((p) => p.id == id), isTrue);
    await repo.report(id, 'spam');
    expect(repo.posts().any((p) => p.id == id), isFalse);
  });

  test('demo explorers can be followed and unfollowed, and counts follow', () async {
    final people = await repo.people();
    expect(people.length, 12);
    final riya = (await repo.profile('demo-riya'))!;
    expect(riya.username, 'riya');
    final before = riya.followers;
    await repo.setFollowing('demo-riya', true);
    final after = (await repo.profile('demo-riya'))!;
    expect(after.followedByMe, isTrue);
    expect(after.followers, before + 1);
    expect((await repo.followingOf('me')).map((c) => c.id), contains('demo-riya'));
    await repo.setFollowing('demo-riya', false);
    expect((await repo.profile('demo-riya'))!.followers, before);
    expect((await repo.people(query: 'chalakudy')).map((c) => c.username), containsAll(['arjun', 'lakshmi']));
  });

  test('hashtags are parsed case-insensitively and de-duplicated', () {
    final p = Post(id: 'x', authorId: 'u', authorName: 'U', createdAt: DateTime.now(), text: 'Loved it #TrekLife #treklife #Wayanad!');
    expect(p.hashtags, ['treklife', 'wayanad']);
  });
}
