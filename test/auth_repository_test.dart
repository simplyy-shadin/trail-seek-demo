import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trailseek/data/models/app_user.dart';
import 'package:trailseek/data/repositories/auth_repository.dart';
import 'package:trailseek/data/repositories/local_store.dart';

void main() {
  late LocalAuthRepository repo;
  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = LocalStore(await SharedPreferences.getInstance());
    repo = LocalAuthRepository(store);
  });

  test('sign up creates a user with a derived username and signs them in', () async {
    final u = await repo.signUpWithEmail(fullName: 'Fayaz FF', email: 'Fayaz@Example.com ', password: 'secret123');
    expect(u.email, 'fayaz@example.com');
    expect(u.username, 'fayazff');
    expect(u.provider, AuthProviderKind.email);
    expect(repo.currentUser?.id, u.id);
    expect(store.user?['id'], u.id);
  });

  test('passwords are stored salted and hashed, never in clear', () async {
    await repo.signUpWithEmail(fullName: 'A B', email: 'a@b.co', password: 'secret123');
    final record = store.accounts['a@b.co'] as Map<String, dynamic>;
    expect(record['hash'], isNot(contains('secret123')));
    expect(record['salt'], isNotEmpty);
    expect((record['hash'] as String).length, 64);
  });

  test('log in succeeds with the right password and fails with the wrong one', () async {
    await repo.signUpWithEmail(fullName: 'A B', email: 'a@b.co', password: 'secret123');
    await repo.signOut();
    expect(repo.currentUser, isNull);
    await expectLater(repo.signInWithEmail(email: 'a@b.co', password: 'nope-nope'), throwsA(isA<AuthException>()));
    final u = await repo.signInWithEmail(email: 'a@b.co', password: 'secret123');
    expect(u.displayName, 'A B');
  });

  test('duplicate email, weak password and bad email are rejected', () async {
    await repo.signUpWithEmail(fullName: 'A B', email: 'a@b.co', password: 'secret123');
    await expectLater(repo.signUpWithEmail(fullName: 'C D', email: 'a@b.co', password: 'secret123'),
        throwsA(predicate((e) => e is AuthException && e.code == 'email-in-use')));
    await expectLater(repo.signUpWithEmail(fullName: 'C D', email: 'c@d.co', password: 'short'),
        throwsA(predicate((e) => e is AuthException && e.code == 'weak-password')));
    await expectLater(repo.signUpWithEmail(fullName: 'C D', email: 'not-an-email', password: 'secret123'),
        throwsA(predicate((e) => e is AuthException && e.code == 'invalid-email')));
  });

  test('google sign-in is idempotent and profile updates persist', () async {
    final a = await repo.signInWithGoogle(displayNameHint: 'Riya Sharma');
    final b = await repo.signInWithGoogle();
    expect(b.id, a.id);
    final c = await repo.updateProfile(username: 'riya_hikes', avatarId: 'av-3');
    expect(c.username, 'riya_hikes');
    final reloaded = LocalAuthRepository(store);
    expect(reloaded.currentUser?.avatarId, 'av-3');
  });

  test('auth state stream emits on sign in and sign out', () async {
    final events = <String?>[];
    final sub = repo.authStateChanges().listen((u) => events.add(u?.email));
    await repo.signUpWithEmail(fullName: 'A B', email: 'a@b.co', password: 'secret123');
    await repo.signOut();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(events, ['a@b.co', null]);
  });
}
