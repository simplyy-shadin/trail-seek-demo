import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import 'local_store.dart';

class AuthException implements Exception {
  const AuthException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

/// Authentication boundary. Screens and controllers only talk to this.
/// [LocalAuthRepository] is the on-device prototype; SupabaseAuthRepository is the cloud one.
abstract class AuthRepository {
  AppUser? get currentUser;
  Stream<AppUser?> authStateChanges();
  Future<AppUser> signUpWithEmail({required String fullName, required String email, required String password});
  Future<AppUser> signInWithEmail({required String email, required String password});
  Future<AppUser> signInWithGoogle({String? displayNameHint});
  Future<AppUser> signInWithApple({String? displayNameHint});
  Future<void> sendPasswordReset(String email);
  Future<AppUser> updateProfile({String? displayName, String? username, String? avatarId});
  Future<void> signOut();
}

/// PROTOTYPE ONLY. Accounts live in SharedPreferences on this phone with a salted
/// SHA-256 password hash. It exists so every flow can be exercised end to end
/// before the backend exists. It is not production authentication.
class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this._store) : _current = _store.user == null ? null : AppUser.fromJson(_store.user!);

  final LocalStore _store;
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  Map<String, dynamic> get _accounts => _store.accounts;

  @override
  Future<AppUser> signUpWithEmail({required String fullName, required String email, required String password}) async {
    final e = email.trim().toLowerCase();
    final name = fullName.trim();
    if (name.length < 2) throw const AuthException('invalid-name', 'Enter your full name.');
    if (!_emailRe.hasMatch(e)) throw const AuthException('invalid-email', 'Enter a valid email address.');
    if (password.length < 8) throw const AuthException('weak-password', 'Password must be at least 8 characters.');
    final accounts = _accounts;
    if (accounts.containsKey(e)) throw const AuthException('email-in-use', 'An account with this email already exists. Log in instead.');

    await _simulateLatency();
    final salt = _randomSalt();
    final user = AppUser(
      id: const Uuid().v4(),
      displayName: name,
      email: e,
      username: _usernameFor(name, accounts.keys.length),
      provider: AuthProviderKind.email,
      createdAt: DateTime.now(),
    );
    accounts[e] = {'user': user.toJson(), 'salt': salt, 'hash': _hash(password, salt)};
    await _store.setAccounts(accounts);
    return _setCurrent(user);
  }

  @override
  Future<AppUser> signInWithEmail({required String email, required String password}) async {
    final e = email.trim().toLowerCase();
    if (!_emailRe.hasMatch(e)) throw const AuthException('invalid-email', 'Enter a valid email address.');
    await _simulateLatency();
    final record = _accounts[e] as Map<String, dynamic>?;
    if (record == null || _hash(password, record['salt'] as String) != record['hash']) {
      throw const AuthException('wrong-credentials', 'Email or password is incorrect.');
    }
    return _setCurrent(AppUser.fromJson((record['user'] as Map).cast<String, dynamic>()));
  }

  @override
  Future<AppUser> signInWithGoogle({String? displayNameHint}) => _federated(AuthProviderKind.google, displayNameHint);

  @override
  Future<AppUser> signInWithApple({String? displayNameHint}) => _federated(AuthProviderKind.apple, displayNameHint);

  Future<AppUser> _federated(AuthProviderKind kind, String? hint) async {
    await _simulateLatency();
    final e = 'you@${kind.name}.local';
    final accounts = _accounts;
    final existing = accounts[e] as Map<String, dynamic>?;
    if (existing != null) return _setCurrent(AppUser.fromJson((existing['user'] as Map).cast<String, dynamic>()));
    final name = (hint?.trim().isNotEmpty ?? false) ? hint!.trim() : 'Trail Seeker';
    final user = AppUser(
      id: const Uuid().v4(),
      displayName: name,
      email: e,
      username: _usernameFor(name, accounts.keys.length),
      provider: kind,
      createdAt: DateTime.now(),
    );
    accounts[e] = {'user': user.toJson()};
    await _store.setAccounts(accounts);
    return _setCurrent(user);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    final e = email.trim().toLowerCase();
    if (!_accounts.containsKey(e)) throw const AuthException('no-account', 'No account found for that email.');
    await _simulateLatency();
    // Prototype: nothing to send. The cloud build emails a 6-digit code.
  }

  @override
  Future<AppUser> updateProfile({String? displayName, String? username, String? avatarId}) async {
    final current = _current;
    if (current == null) throw const AuthException('not-signed-in', 'Sign in first.');
    final updated = current.copyWith(displayName: displayName, username: username, avatarId: avatarId);
    final accounts = _accounts;
    final record = accounts[current.email] as Map<String, dynamic>?;
    if (record != null) {
      record['user'] = updated.toJson();
      await _store.setAccounts(accounts);
    }
    return _setCurrent(updated);
  }

  @override
  Future<void> signOut() async {
    _current = null;
    await _store.setUser(null);
    _controller.add(null);
  }

  Future<AppUser> _setCurrent(AppUser user) async {
    _current = user;
    await _store.setUser(user.toJson());
    await _store.setDisplayName(user.displayName);
    _controller.add(user);
    return user;
  }

  static Future<void> _simulateLatency() => Future<void>.delayed(const Duration(milliseconds: 350));

  static String _randomSalt() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  static String _hash(String password, String salt) => sha256.convert(utf8.encode('$salt:$password')).toString();

  static String _usernameFor(String name, int n) {
    final base = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final stem = base.isEmpty ? 'trekker' : base.substring(0, base.length.clamp(0, 12));
    return n == 0 ? stem : '$stem${n + 1}';
  }
}
