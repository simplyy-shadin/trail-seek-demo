import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_record.dart';
import '../models/group_session.dart';
import '../models/session_summary.dart';

/// Thin persistence layer over SharedPreferences. Everything the app needs
/// to remember between launches lives here until a real backend exists.
class LocalStore {
  LocalStore(this._prefs);
  final SharedPreferences _prefs;

  static const _kOnboarded = 'onboarded';
  static const _kRegion = 'region';
  static const _kUser = 'user';
  static const _kSaved = 'saved';
  static const _kSessions = 'sessions';
  static const _kHistory = 'history';
  static const _kFreeSessions = 'free_sessions_remaining';
  static const _kDisplayName = 'display_name';
  static const _kAccounts = 'accounts';
  static const _kActivities = 'activities';

  static const freeSessionsIncluded = 3;

  bool get onboarded => _prefs.getBool(_kOnboarded) ?? false;
  Future<void> setOnboarded(bool v) => _prefs.setBool(_kOnboarded, v);

  String? get regionId => _prefs.getString(_kRegion);
  Future<void> setRegionId(String? id) =>
      id == null ? _prefs.remove(_kRegion) : _prefs.setString(_kRegion, id);

  Map<String, dynamic>? get user {
    final raw = _prefs.getString(_kUser);
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> setUser(Map<String, dynamic>? u) =>
      u == null ? _prefs.remove(_kUser) : _prefs.setString(_kUser, jsonEncode(u));

  /// Prototype account table for [LocalAuthRepository]: email -> record.
  Map<String, dynamic> get accounts {
    final raw = _prefs.getString(_kAccounts);
    return raw == null ? <String, dynamic>{} : (jsonDecode(raw) as Map).cast<String, dynamic>();
  }

  Future<void> setAccounts(Map<String, dynamic> a) => _prefs.setString(_kAccounts, jsonEncode(a));

  String get displayName => _prefs.getString(_kDisplayName) ?? '';
  Future<void> setDisplayName(String v) => _prefs.setString(_kDisplayName, v);

  Set<String> get saved => (_prefs.getStringList(_kSaved) ?? const []).toSet();
  Future<void> setSaved(Set<String> ids) => _prefs.setStringList(_kSaved, ids.toList());

  List<GroupSession> get sessions {
    final raw = _prefs.getString(_kSessions);
    if (raw == null) return const [];
    return (jsonDecode(raw) as List)
        .map((e) => GroupSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setSessions(List<GroupSession> s) =>
      _prefs.setString(_kSessions, jsonEncode(s.map((e) => e.toJson()).toList()));

  List<SessionSummary> get history {
    final raw = _prefs.getString(_kHistory);
    if (raw == null) return const [];
    return (jsonDecode(raw) as List)
        .map((e) => SessionSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setHistory(List<SessionSummary> h) =>
      _prefs.setString(_kHistory, jsonEncode(h.map((e) => e.toJson()).toList()));

  List<ActivityRecord> get activities {
    final raw = _prefs.getString(_kActivities);
    if (raw == null) return const [];
    return (jsonDecode(raw) as List).map((e) => ActivityRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> setActivities(List<ActivityRecord> a) =>
      _prefs.setString(_kActivities, jsonEncode(a.map((e) => e.toJson()).toList()));

  /// Removes everything personal; keeps onboarding + region.
  Future<void> wipeUserData() async {
    for (final k in _prefs.getKeys().toList()) {
      if (k == _kOnboarded || k == _kRegion) continue;
      await _prefs.remove(k);
    }
  }

  /// Raw string slots for feature-owned blobs (active track snapshot, saved tracks).
  String? rawString(String key) => _prefs.getString(key);
  Future<void> setRaw(String key, String value) => _prefs.setString(key, value);
  Future<void> removeRaw(String key) => _prefs.remove(key);

  int get freeSessionsRemaining => _prefs.getInt(_kFreeSessions) ?? freeSessionsIncluded;
  Future<void> setFreeSessionsRemaining(int n) => _prefs.setInt(_kFreeSessions, n);
}
