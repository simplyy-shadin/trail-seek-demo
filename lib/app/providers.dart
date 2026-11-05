import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/group_secret_vault.dart';
import '../data/models/activity_category.dart';
import '../data/models/app_user.dart';
import '../data/models/adventure.dart';
import '../data/models/destination.dart';
import '../data/models/group_session.dart';
import '../data/models/region.dart';
import '../data/models/session_summary.dart';
import '../data/repositories/adventure_repository.dart';
import '../data/repositories/activity_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/supabase_auth_repository.dart';
import 'backend.dart';
import '../data/repositories/local_store.dart';
import '../features/progress/progress.dart';
import '../features/rope/links/rope_roster.dart';
import '../features/rope/links/rope_security.dart';

// ---------------------------------------------------------------- storage

/// Overridden in main() once SharedPreferences is ready.
final localStoreProvider = Provider<LocalStore>((ref) => throw UnimplementedError('LocalStore not initialised'));

final adventureRepositoryProvider = Provider<AdventureRepository>((ref) => AdventureRepository());

final regionsProvider = FutureProvider<List<Region>>((ref) => ref.watch(adventureRepositoryProvider).regions());

final adventuresProvider = FutureProvider<List<Adventure>>((ref) => ref.watch(adventureRepositoryProvider).all());

final adventureByIdProvider = FutureProvider.family<Adventure?, String>(
    (ref, id) => ref.watch(adventureRepositoryProvider).byId(id));

final destinationsProvider = FutureProvider<List<Destination>>((ref) => ref.watch(adventureRepositoryProvider).destinations());

final destinationByIdProvider = FutureProvider.family<Destination?, String>(
    (ref, id) => ref.watch(adventureRepositoryProvider).destinationById(id));

/// ISO date the programme data was last pulled from the Forest Department portal.
final dataGeneratedAtProvider = FutureProvider<String?>((ref) => ref.watch(adventureRepositoryProvider).generatedAt());

class AdventureQuery {
  const AdventureQuery({this.regionId, this.category, this.difficulty, this.query = ''});
  final String? regionId;
  final ActivityCategory? category;
  final Difficulty? difficulty;
  final String query;

  @override
  bool operator ==(Object other) =>
      other is AdventureQuery &&
      other.regionId == regionId &&
      other.category == category &&
      other.difficulty == difficulty &&
      other.query == query;

  @override
  int get hashCode => Object.hash(regionId, category, difficulty, query);
}

final adventureSearchProvider = FutureProvider.family<List<Adventure>, AdventureQuery>((ref, q) =>
    ref.watch(adventureRepositoryProvider).search(
        regionId: q.regionId, category: q.category, difficulty: q.difficulty, query: q.query));

// ------------------------------------------------------------- onboarding

class OnboardingController extends Notifier<bool> {
  @override
  bool build() => ref.read(localStoreProvider).onboarded;

  Future<void> complete() async {
    await ref.read(localStoreProvider).setOnboarded(true);
    state = true;
  }
}

final onboardedProvider = NotifierProvider<OnboardingController, bool>(OnboardingController.new);

class RegionController extends Notifier<String?> {
  @override
  String? build() => ref.read(localStoreProvider).regionId;

  Future<void> select(String? id) async {
    await ref.read(localStoreProvider).setRegionId(id);
    state = id;
  }
}

final selectedRegionProvider = NotifierProvider<RegionController, String?>(RegionController.new);

// ------------------------------------------------------------------- auth

/// Supabase Auth when the build carries its config, else the on-device
/// prototype store.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (Backend.isCloud) {
    final repo = SupabaseAuthRepository(Backend.client, ref.read(localStoreProvider));
    ref.onDispose(repo.dispose);
    return repo;
  }
  return LocalAuthRepository(ref.read(localStoreProvider));
});

/// Exposes the signed-in user and the auth actions screens call.
class AuthController extends Notifier<AppUser?> {
  @override
  AppUser? build() {
    final repo = ref.read(authRepositoryProvider);
    final sub = repo.authStateChanges().listen((u) => state = u);
    ref.onDispose(sub.cancel);
    return repo.currentUser;
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> signUp({required String fullName, required String email, required String password}) async {
    state = await _repo.signUpWithEmail(fullName: fullName, email: email, password: password);
  }

  Future<void> signIn({required String email, required String password}) async {
    state = await _repo.signInWithEmail(email: email, password: password);
  }

  Future<void> signInWithGoogle({String? displayNameHint}) async {
    state = await _repo.signInWithGoogle(displayNameHint: displayNameHint);
  }

  Future<void> signInWithApple({String? displayNameHint}) async {
    state = await _repo.signInWithApple(displayNameHint: displayNameHint);
  }

  Future<void> sendPasswordReset(String email) => _repo.sendPasswordReset(email);

  Future<void> updateProfile({String? displayName, String? username, String? avatarId}) async {
    state = await _repo.updateProfile(displayName: displayName, username: username, avatarId: avatarId);
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = null;
  }
}

final authProvider = NotifierProvider<AuthController, AppUser?>(AuthController.new);

// ------------------------------------------------------------------ saved

class SavedController extends Notifier<Set<String>> {
  @override
  Set<String> build() => ref.read(localStoreProvider).saved;

  Future<void> toggle(String id) async {
    final next = {...state};
    next.contains(id) ? next.remove(id) : next.add(id);
    await ref.read(localStoreProvider).setSaved(next);
    state = next;
  }
}

final savedProvider = NotifierProvider<SavedController, Set<String>>(SavedController.new);

// ---------------------------------------------------------------- history

@immutable
class HistoryState {
  const HistoryState({required this.summaries, required this.freeSessionsRemaining});
  final List<SessionSummary> summaries;
  final int freeSessionsRemaining;
  int get completed => summaries.length;
}

class HistoryController extends Notifier<HistoryState> {
  @override
  HistoryState build() {
    final s = ref.read(localStoreProvider);
    return HistoryState(summaries: s.history, freeSessionsRemaining: s.freeSessionsRemaining);
  }

  Future<void> record(SessionSummary summary) async {
    final s = ref.read(localStoreProvider);
    final next = [summary, ...state.summaries];
    final free = math.max(0, state.freeSessionsRemaining - 1);
    await s.setHistory(next);
    await s.setFreeSessionsRemaining(free);
    state = HistoryState(summaries: next, freeSessionsRemaining: free);
  }
}

final historyProvider = NotifierProvider<HistoryController, HistoryState>(HistoryController.new);

// ------------------------------------------------------------- activities

final activityRepositoryProvider = Provider<ActivityRepository>((ref) => ActivityRepository(ref.read(localStoreProvider)));

/// Something the UI should celebrate (task 14).
sealed class ProgressEvent {
  const ProgressEvent(this.delta);
  final ProgressDelta delta;
}

class XpGainedEvent extends ProgressEvent {
  const XpGainedEvent(super.delta);
}

class LevelUpEvent extends ProgressEvent {
  const LevelUpEvent(super.delta);
}

class BadgeUnlockedEvent extends ProgressEvent {
  const BadgeUnlockedEvent(super.delta, this.badgeId);
  final String badgeId;
}

class AchievementCompletedEvent extends ProgressEvent {
  const AchievementCompletedEvent(super.delta, this.achievementId);
  final String achievementId;
}

/// The activity log. Adding or deleting an activity recomputes progress.
class ActivitiesController extends Notifier<List<ActivityRecord>> {
  static const engine = ProgressEngine();
  final _events = StreamController<ProgressEvent>.broadcast();

  @override
  List<ActivityRecord> build() {
    ref.onDispose(_events.close);
    return ref.read(activityRepositoryProvider).load();
  }

  Stream<ProgressEvent> get events => _events.stream;

  Future<ProgressDelta> add(ActivityRecord record) async {
    final before = engine.rebuild(state);
    final (after, delta) = engine.apply(before, state, record);
    if (delta.isEmpty && before.appliedActivityIds.contains(record.id)) return delta;
    final next = [...state, record]..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    await ref.read(activityRepositoryProvider).save(next);
    state = next;
    if (delta.xpGained > 0) _events.add(XpGainedEvent(delta));
    if (delta.leveledUp) _events.add(LevelUpEvent(delta));
    for (final b in delta.newBadges) {
      _events.add(BadgeUnlockedEvent(delta, b));
    }
    for (final a in delta.achievementsCompleted) {
      _events.add(AchievementCompletedEvent(delta, a));
    }
    assert(after.totalXp == engine.rebuild(next).totalXp);
    return delta;
  }

  Future<void> updateTitle(String activityId, String title) async {
    final next = [
      for (final r in state)
        if (r.id == activityId)
          ActivityRecord(
            id: r.id, type: r.type, title: title, startedAt: r.startedAt, endedAt: r.endedAt, distanceM: r.distanceM,
            elevationGainM: r.elevationGainM, maxAltitudeM: r.maxAltitudeM, verified: r.verified, trailId: r.trailId,
            district: r.district, groupSessionId: r.groupSessionId, memberCount: r.memberCount, separations: r.separations,
            simulated: r.simulated,
          )
        else
          r,
    ];
    await ref.read(activityRepositoryProvider).save(next);
    state = next;
  }

  /// Puts a deleted record back without replaying reward events (undo).
  Future<void> restore(ActivityRecord record) async {
    if (state.any((r) => r.id == record.id)) return;
    final next = [...state, record]..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    await ref.read(activityRepositoryProvider).save(next);
    state = next;
  }

  Future<void> remove(String activityId) async {
    final next = state.where((r) => r.id != activityId).toList();
    await ref.read(activityRepositoryProvider).save(next);
    state = next;
  }

  ActivityRecord? byId(String id) {
    for (final r in state) {
      if (r.id == id) return r;
    }
    return null;
  }
}

final activitiesProvider = NotifierProvider<ActivitiesController, List<ActivityRecord>>(ActivitiesController.new);

/// Derived, always consistent with the activity list.
final progressProvider = Provider<ProgressState>((ref) => ActivitiesController.engine.rebuild(ref.watch(activitiesProvider)));

final progressEventsProvider = StreamProvider<ProgressEvent>((ref) => ref.watch(activitiesProvider.notifier).events);

// ----------------------------------------------------------------- groups

/// Local group registry. Sessions created here are stored on-device; the
/// join path accepts any well-formed code so two phones can be exercised
/// before the sync backend exists (BLE matches on the code hash).
class GroupController extends Notifier<List<GroupSession>> {
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  @override
  List<GroupSession> build() {
    final loaded = ref.read(localStoreProvider).sessions;
    // A session left "active" across an app restart (yesterday's trek, a crash)
    // is not live any more: nothing is advertising for it. Close it after a day.
    final now = DateTime.now();
    var changed = false;
    final cleaned = [
      for (final s in loaded)
        if (s.status == SessionStatus.active && now.difference(s.startedAt ?? s.date) > const Duration(hours: 24))
          (() {
            changed = true;
            return s.copyWith(status: SessionStatus.completed, endedAt: (s.startedAt ?? s.date).add(const Duration(hours: 24)));
          })()
        else
          s,
    ];
    if (changed) ref.read(localStoreProvider).setSessions(cleaned);
    return cleaned;
  }

  GroupSession? byId(String id) {
    for (final s in state) {
      if (s.id == id) return s;
    }
    return null;
  }

  String _code() {
    final r = math.Random.secure();
    return List.generate(6, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
  }

  Future<GroupSession> create({
    required String name,
    required Adventure adventure,
    required DateTime date,
    required DateTime expectedStart,
    required int plannedSize,
    required bool simulated,
  }) async {
    final user = ref.read(authProvider);
    final selfId = user?.id ?? 'local-user';
    final selfName = user?.displayName.isNotEmpty == true ? user!.displayName : 'You';
    final self = Member(id: selfId, displayName: selfName, role: MemberRole.organizer, memberIndex: 0, isSelf: true, avatarId: user?.avatarId);
    final session = GroupSession(
      id: const Uuid().v4(),
      code: _code(),
      name: name.trim().isEmpty ? '${adventure.name} group' : name.trim(),
      adventureId: adventure.id,
      adventureName: adventure.name,
      date: date,
      expectedStart: expectedStart,
      plannedSize: plannedSize,
      organizerId: selfId,
      members: [self],
      status: SessionStatus.lobby,
      simulated: simulated,
      securityKey: simulated ? null : RopeSecurity.generateKey(),
    );
    await _save([session, ...state]);
    return session;
  }

  Future<GroupSession> join({required String code, Adventure? adventure, required bool simulated, String? securityKey}) async {
    if (!simulated && !RopeSecurity.validKey(securityKey)) {
      throw StateError('Scan the organizer secure QR invitation to join a real group.');
    }
    final user = ref.read(authProvider);
    final selfId = user?.id ?? 'local-user';
    final selfName = user?.displayName.isNotEmpty == true ? user!.displayName : 'You';
    final existing = state.where((s) => s.code == code.toUpperCase()).firstOrNull;
    if (existing != null) {
      if (existing.simulated != simulated) {
        throw StateError('Saved demo/real group conflicts with this invitation; use a new group.');
      }
      if (!simulated && existing.securityKey != null && existing.securityKey != securityKey!.toLowerCase()) {
        throw StateError('This secure invitation does not match the saved group.');
      }
      if (existing.members.any((m) => m.id == selfId)) {
        if (!simulated && existing.securityKey == null) {
          final updated = existing.copyWith(securityKey: securityKey!.toLowerCase());
          await _replace(updated);
          return updated;
        }
        return existing;
      }
      final me = Member(
          id: selfId, displayName: selfName, role: MemberRole.member, memberIndex: existing.members.length, isSelf: true, avatarId: user?.avatarId);
      final updated = existing.copyWith(members: [...existing.members, me],
          securityKey: simulated ? null : securityKey!.toLowerCase());
      await _replace(updated);
      return updated;
    }
    // Unknown locally. Demo mode invents an organizer; Bluetooth mode starts
    // with just us (index unassigned) and the organizer's phone assigns the
    // real index and shares the roster over GATT in the lobby.
    final me = Member(
      id: selfId,
      displayName: selfName,
      role: MemberRole.member,
      memberIndex: simulated ? 1 : unassignedMemberIndex,
      isSelf: true,
      avatarId: user?.avatarId,
    );
    const demoOrganizer = Member(id: 'organizer', displayName: 'Organizer', role: MemberRole.organizer, memberIndex: 0);
    final session = GroupSession(
      id: const Uuid().v4(),
      code: code.toUpperCase(),
      name: adventure == null ? 'Group $code' : '${adventure.name} group',
      adventureId: adventure?.id ?? '',
      adventureName: adventure?.name ?? 'Adventure',
      date: DateTime.now(),
      expectedStart: DateTime.now(),
      plannedSize: 2,
      organizerId: simulated ? demoOrganizer.id : 'pending',
      members: simulated ? [demoOrganizer, me] : [me],
      status: SessionStatus.lobby,
      simulated: simulated,
      securityKey: simulated ? null : securityKey!.toLowerCase(),
    );
    await _save([session, ...state]);
    return session;
  }

  /// Dev helper: fills the lobby with pretend members so the whole flow can
  /// be walked on one phone.
  Future<GroupSession> addSimulatedMembers(String sessionId) async {
    final s = byId(sessionId);
    if (s == null) throw StateError('No session $sessionId');
    const names = ['Rahul', 'Anu', 'Joseph', 'Meera', 'Arjun', 'Fathima', 'Vishnu', 'Lakshmi', 'Nikhil', 'Sneha', 'Akhil', 'Divya', 'Rohan', 'Priya', 'Sameer'];
    final members = [...s.members];
    var i = 0;
    while (members.length < s.plannedSize && members.length < 16 && i < names.length) {
      final name = names[i++];
      if (members.any((m) => m.displayName == name)) continue;
      final r = math.Random(name.hashCode);
      members.add(Member(
        id: 'sim-${name.toLowerCase()}',
        displayName: name,
        role: MemberRole.member,
        memberIndex: members.length,
        avatarId: 'v1:${r.nextInt(8)}.${r.nextInt(4)}.${r.nextInt(4)}.${r.nextInt(6)}.${r.nextInt(6)}',
      ));
    }
    final updated = s.copyWith(members: members);
    await _replace(updated);
    return updated;
  }

  /// Roster learned over Bluetooth (names, indices, organizer).
  /// A joiner's placeholder session learns the real adventure, date and name from the organizer.
  Future<GroupSession?> applySessionInfo(String sessionId, SessionInfo info) async {
    final s = byId(sessionId);
    if (s == null) return null;
    final same = s.adventureId == info.adventureId &&
        s.adventureName == info.adventureName &&
        s.name == info.groupName &&
        s.date.isAtSameMomentAs(info.date) &&
        s.expectedStart.isAtSameMomentAs(info.expectedStart) &&
        s.plannedSize >= info.plannedSize;
    if (same) return s;
    final updated = s.copyWith(
      adventureId: info.adventureId,
      adventureName: info.adventureName,
      name: info.groupName,
      date: info.date,
      expectedStart: info.expectedStart,
      plannedSize: info.plannedSize > s.plannedSize ? info.plannedSize : s.plannedSize,
    );
    await _replace(updated);
    return updated;
  }

  Future<GroupSession> replaceMembers(String sessionId, List<Member> incoming, {String? organizerId}) async {
    final s = byId(sessionId);
    if (s == null) throw StateError('No session $sessionId');
    final members = disambiguateNames(incoming);
    final updated = GroupSession(
      id: s.id,
      code: s.code,
      name: s.name,
      adventureId: s.adventureId,
      adventureName: s.adventureName,
      date: s.date,
      expectedStart: s.expectedStart,
      expectedEnd: s.expectedEnd,
      plannedSize: members.length > s.plannedSize ? members.length : s.plannedSize,
      organizerId: organizerId ?? s.organizerId,
      members: members,
      status: s.status,
      startedAt: s.startedAt,
      endedAt: s.endedAt,
      simulated: s.simulated,
      securityKey: s.securityKey,
    );
    await _replace(updated);
    return updated;
  }

  Future<GroupSession> setStatus(String sessionId, SessionStatus status, {DateTime? startedAt, DateTime? endedAt}) async {
    final s = byId(sessionId);
    if (s == null) throw StateError('No session $sessionId');
    final updated = s.copyWith(status: status, startedAt: startedAt, endedAt: endedAt);
    await _replace(updated);
    return updated;
  }

  Future<GroupSession> setSimulated(String sessionId, bool simulated) async {
    final s = byId(sessionId);
    if (s == null) throw StateError('No session $sessionId');
    final updated = s.copyWith(simulated: simulated);
    await _replace(updated);
    return updated;
  }

  /// Deletes a group from this phone (any status).
  Future<void> delete(String sessionId) async {
    if (byId(sessionId)?.securityKey != null) {
      await GroupSecretVault.remove(sessionId);
    }
    await _save([for (final s in state) if (s.id != sessionId) s]);
  }

  Future<void> _replace(GroupSession updated) => _save([for (final s in state) s.id == updated.id ? updated : s]);

  Future<void> _save(List<GroupSession> sessions) async {
    for (final s in sessions) {
      final secret = s.securityKey;
      if (secret != null && GroupSecretVault.get(s.id) != secret) {
        await GroupSecretVault.save(s.id, secret);
      }
    }
    await ref.read(localStoreProvider).setSessions(sessions);
    state = sessions;
  }
}

final groupProvider = NotifierProvider<GroupController, List<GroupSession>>(GroupController.new);

final sessionByIdProvider = Provider.family<GroupSession?, String>((ref, id) {
  final sessions = ref.watch(groupProvider);
  for (final s in sessions) {
    if (s.id == id) return s;
  }
  return null;
});

final activeSessionProvider = Provider<GroupSession?>((ref) {
  final sessions = ref.watch(groupProvider);
  for (final s in sessions) {
    if (s.status == SessionStatus.active) return s;
  }
  return null;
});

/// Two phones signed in with the default name would both show as "Trail Seeker".
/// Suffix repeats by member index so every phone derives the same labels.
List<Member> disambiguateNames(List<Member> members) {
  final sorted = [...members]..sort((a, b) => a.memberIndex.compareTo(b.memberIndex));
  final seen = <String, int>{};
  final renamed = <String, String>{};
  for (final m in sorted) {
    final key = m.displayName.trim().toLowerCase();
    final n = (seen[key] ?? 0) + 1;
    seen[key] = n;
    if (n > 1) renamed[m.id] = '${m.displayName.trim()} $n';
  }
  if (renamed.isEmpty) return members;
  return [for (final m in members) renamed.containsKey(m.id) ? m.copyWith(displayName: renamed[m.id]) : m];
}
