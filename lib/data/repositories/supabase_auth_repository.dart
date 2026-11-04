import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/app_user.dart';
import 'auth_repository.dart';
import 'local_store.dart';

/// Supabase Auth + the `profiles` row. The profile is cached in [LocalStore]
/// so the app opens signed in while offline.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client, this._store) : _current = _store.user == null ? null : AppUser.fromJson(_store.user!) {
    _sub = _client.auth.onAuthStateChange.listen((e) async {
      final session = e.session;
      if (e.event == sb.AuthChangeEvent.signedOut || session == null && e.event != sb.AuthChangeEvent.initialSession) {
        if (_current != null) {
          _current = null;
          await _store.setUser(null);
          _controller.add(null);
        }
        return;
      }
      if (session != null && (e.event == sb.AuthChangeEvent.initialSession || e.event == sb.AuthChangeEvent.tokenRefreshed || e.event == sb.AuthChangeEvent.userUpdated)) {
        try {
          _current = await _loadProfile(session.user.id);
          await _store.setUser(_current!.toJson());
          _controller.add(_current);
        } catch (_) {}
      }
    });
  }

  final sb.SupabaseClient _client;
  final LocalStore _store;
  final _controller = StreamController<AppUser?>.broadcast();
  StreamSubscription? _sub;
  AppUser? _current;

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }

  @override
  Future<AppUser> signUpWithEmail({required String fullName, required String email, required String password}) async {
    final name = fullName.trim();
    if (name.isEmpty) throw const AuthException('name', 'Enter your name.');
    try {
      final res = await _client.auth.signUp(email: email.trim().toLowerCase(), password: password, data: {'display_name': name});
      final user = res.user;
      if (user == null) throw const AuthException('signup', 'Sign-up failed. Try again.');
      if (res.session == null) {
        throw const AuthException('confirm', 'Check your email and confirm the address, then log in.');
      }
      return await _setCurrent(await _loadProfile(user.id, fallbackName: name));
    } on sb.AuthException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<AppUser> signInWithEmail({required String email, required String password}) async {
    try {
      final res = await _client.auth.signInWithPassword(email: email.trim().toLowerCase(), password: password);
      return await _setCurrent(await _loadProfile(res.user!.id));
    } on sb.AuthException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<AppUser> signInWithGoogle({String? displayNameHint}) => _oauth(sb.OAuthProvider.google);

  @override
  Future<AppUser> signInWithApple({String? displayNameHint}) => _oauth(sb.OAuthProvider.apple);

  Future<AppUser> _oauth(sb.OAuthProvider provider) async {
    try {
      final ok = await _client.auth.signInWithOAuth(provider, redirectTo: 'io.trailseek.app://login-callback', authScreenLaunchMode: sb.LaunchMode.externalApplication);
      if (!ok) throw const AuthException('oauth', 'Could not open the sign-in page.');
      // The session arrives through the deep link; wait for it.
      final session = await _client.auth.onAuthStateChange
          .where((e) => e.session != null && (e.event == sb.AuthChangeEvent.signedIn || e.event == sb.AuthChangeEvent.initialSession))
          .map((e) => e.session!)
          .first
          .timeout(const Duration(minutes: 3));
      return await _setCurrent(await _loadProfile(session.user.id));
    } on TimeoutException {
      throw const AuthException('cancelled', 'Sign-in was not completed.');
    } on sb.AuthException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim().toLowerCase());
    } on sb.AuthException catch (e) {
      throw _map(e);
    }
  }

  /// Second step of the reset: the 6-digit code from the email + new password.
  Future<AppUser> resetPassword({required String email, required String code, required String newPassword}) async {
    try {
      final res = await _client.auth.verifyOTP(type: sb.OtpType.recovery, token: code.trim(), email: email.trim().toLowerCase());
      await _client.auth.updateUser(sb.UserAttributes(password: newPassword));
      return await _setCurrent(await _loadProfile(res.user!.id));
    } on sb.AuthException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<AppUser> updateProfile({String? displayName, String? username, String? avatarId}) async {
    final cur = _current;
    if (cur == null) throw const AuthException('signed-out', 'Sign in first.');
    final patch = <String, dynamic>{};
    if (displayName != null && displayName.trim().isNotEmpty) patch['display_name'] = displayName.trim();
    if (username != null && username.trim().isNotEmpty) {
      final want = username.trim().toLowerCase();
      if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(want)) throw const AuthException('username', 'Usernames are 3–20 letters, digits or underscores.');
      patch['username'] = want;
    }
    if (avatarId != null) patch['avatar_id'] = avatarId;
    try {
      if (patch.isNotEmpty) await _client.from('profiles').update(patch).eq('id', cur.id);
    } on sb.PostgrestException catch (e) {
      if (e.code == '23505') throw const AuthException('username', 'That username is taken.');
      throw AuthException('profile', e.message);
    }
    return _setCurrent(await _loadProfile(cur.id));
  }

  Future<void> updateBio({required String bio, required String homeTown}) async {
    final cur = _current;
    if (cur == null) return;
    await _client.from('profiles').update({'bio': bio.trim(), 'home_town': homeTown.trim()}).eq('id', cur.id);
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
    _current = null;
    await _store.setUser(null);
    _controller.add(null);
  }

  Future<AppUser> _loadProfile(String uid, {String? fallbackName}) async {
    final row = await _client.from('profiles').select().eq('id', uid).maybeSingle();
    if (row == null) {
      // Trigger has not run yet (rare race right after sign-up): wait a moment and retry once.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final again = await _client.from('profiles').select().eq('id', uid).maybeSingle();
      if (again == null) throw const AuthException('profile', 'Your profile is still being created. Try again in a moment.');
      return _fromRow(again);
    }
    return _fromRow(row);
  }

  static AppUser _fromRow(Map<String, dynamic> r) => AppUser(
        id: r['id'] as String,
        displayName: r['display_name'] as String? ?? 'Trail Seeker',
        email: r['email'] as String? ?? '',
        username: r['username'] as String? ?? '',
        provider: AuthProviderKind.values.where((p) => p.name == r['provider']).firstOrNull ?? AuthProviderKind.email,
        createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
        avatarId: r['avatar_id'] as String?,
      );

  Future<AppUser> _setCurrent(AppUser user) async {
    _current = user;
    await _store.setUser(user.toJson());
    _controller.add(user);
    return user;
  }

  static AuthException _map(sb.AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('already registered') || m.contains('already exists')) return const AuthException('exists', 'An account with this email already exists. Log in instead.');
    if (m.contains('invalid login') || m.contains('invalid credentials')) return const AuthException('credentials', 'Email or password is wrong.');
    if (m.contains('email not confirmed')) return const AuthException('confirm', 'Confirm your email first (check your inbox), then log in.');
    if (m.contains('password') && m.contains('least')) return const AuthException('password', 'Use at least 6 characters.');
    if (m.contains('rate limit') || m.contains('too many')) return const AuthException('rate', 'Too many attempts. Try again in a few minutes.');
    if (m.contains('token') && (m.contains('invalid') || m.contains('expired'))) return const AuthException('code', 'That code is wrong or has expired.');
    if (m.contains('network') || m.contains('socket') || m.contains('failed host lookup')) return const AuthException('offline', 'No connection. Check your network and try again.');
    return AuthException(e.statusCode ?? 'auth', e.message);
  }
}
