import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../../app/providers.dart';
import '../../data/models/activity_record.dart';
import '../../data/models/adventure.dart';
import '../../data/models/group_session.dart';
import '../../data/models/session_summary.dart';
import 'engine/geo.dart';
import 'engine/rope_config.dart';
import 'engine/rope_engine.dart';
import 'engine/rope_models.dart';
import 'links/ble_peer_link.dart';
import 'links/peer_link.dart';
import 'links/simulated_peer_link.dart';
import 'rope_alerts.dart';
import 'rope_log.dart';
import '../activity/track_store.dart';
import '../tracking/position_stream.dart';
import '../tracking/track_recorder.dart';

@immutable
class RopeSessionState {
  const RopeSessionState({
    required this.session,
    required this.adventure,
    required this.startedAt,
    required this.route,
    this.snapshot,
    this.positions = const {},
    this.positionTimes = const {},
    this.selfPosition,
    this.selfPositionAt,
    this.elapsed = Duration.zero,
    this.distanceKm = 0,
    this.currentAltitudeM,
    this.log = const [],
    this.error,
    this.simulated = true,
    this.trails = const {},
    this.endedByOrganizer = false,
  });

  final GroupSession session;
  final Adventure adventure;
  final DateTime startedAt;
  final Route route;
  final RopeSnapshot? snapshot;
  final Map<String, GeoPoint> positions;

  /// When each member's position was last updated (for distance freshness).
  final Map<String, DateTime> positionTimes;
  final GeoPoint? selfPosition;
  final DateTime? selfPositionAt;
  final Duration elapsed;
  final double distanceKm;
  final double? currentAltitudeM;
  final List<RopeMessage> log;
  final String? error;
  final bool simulated;

  /// Where each member has walked (key = member id, ours included), for the path lines.
  final Map<String, List<GeoPoint>> trails;

  /// The organizer's phone said the trek is over; every member ends too.
  final bool endedByOrganizer;

  Member? get self => session.self;
  List<Member> get others => session.members.where((m) => !m.isSelf).toList();

  Member? member(String id) {
    for (final m in session.members) {
      if (m.id == id) return m;
    }
    return null;
  }

  RopeState stateOf(String memberId) => snapshot?.members[memberId]?.state ?? RopeState.connected;

  /// Real trips use measured GPS altitude, never the adventure's advertised
  /// elevation. Synthetic elevation is shown only for simulated sessions.
  int? get elevationM {
    if (!simulated) return currentAltitudeM?.round();
    final progress = (distanceKm * 1000 / route.lengthMetres).clamp(0.0, 1.0);
    return (adventure.elevationM - adventure.elevationGainM + adventure.elevationGainM * progress).round();
  }

  RopeSessionState withSession(GroupSession s) => RopeSessionState(
        session: s,
        adventure: adventure,
        startedAt: startedAt,
        route: route,
        snapshot: snapshot,
        positions: positions,
        positionTimes: positionTimes,
        selfPosition: selfPosition,
        selfPositionAt: selfPositionAt,
        elapsed: elapsed,
        distanceKm: distanceKm,
        currentAltitudeM: currentAltitudeM,
        log: log,
        error: error,
        simulated: simulated,
        trails: trails,
        endedByOrganizer: endedByOrganizer,
      );

  RopeSessionState copyWith({
    RopeSnapshot? snapshot,
    Map<String, GeoPoint>? positions,
    Map<String, DateTime>? positionTimes,
    GeoPoint? selfPosition,
    DateTime? selfPositionAt,
    Duration? elapsed,
    double? distanceKm,
    double? currentAltitudeM,
    List<RopeMessage>? log,
    String? error,
    bool clearError = false,
    Map<String, List<GeoPoint>>? trails,
    bool? endedByOrganizer,
  }) =>
      RopeSessionState(
        session: session,
        adventure: adventure,
        startedAt: startedAt,
        route: route,
        snapshot: snapshot ?? this.snapshot,
        positions: positions ?? this.positions,
        positionTimes: positionTimes ?? this.positionTimes,
        selfPosition: selfPosition ?? this.selfPosition,
        selfPositionAt: selfPositionAt ?? this.selfPositionAt,
        elapsed: elapsed ?? this.elapsed,
        distanceKm: distanceKm ?? this.distanceKm,
        currentAltitudeM: currentAltitudeM ?? this.currentAltitudeM,
        log: log ?? this.log,
        error: clearError ? null : (error ?? this.error),
        simulated: simulated,
        trails: trails ?? this.trails,
        endedByOrganizer: endedByOrganizer ?? this.endedByOrganizer,
      );

  /// [trails] with [p] appended to [id]'s line (skipping sub-3 m wiggles).
  Map<String, List<GeoPoint>> trailWith(String id, GeoPoint p) {
    final line = trails[id] ?? const <GeoPoint>[];
    if (line.isNotEmpty && haversineMetres(line.last, p) < 3) return trails;
    return {...trails, id: [...line, p]};
  }
}

/// Owns the engine + link for the active Digital Rope session.
class RopeController extends Notifier<RopeSessionState?> {
  RopeEngine? _engine;
  PeerLink? _link;
  Timer? _ticker;
  final List<StreamSubscription> _subs = [];
  TrackRecorder _ownTrack = TrackRecorder();

  @override
  RopeSessionState? build() {
    ref.onDispose(_teardown);
    return null;
  }

  SimulatedPeerLink? get simulator => _link is SimulatedPeerLink ? _link as SimulatedPeerLink : null;
  List<RopeEvent> get events => _engine?.events ?? const [];
  RopeConfig get config => _engine?.config ?? const RopeConfig();

  Future<void> start({required GroupSession session, required Adventure adventure, RopeConfig? config}) async {
    await _teardown();
    final self = session.self;
    if (self == null) throw StateError('Session has no self member');
    final cfg = config ?? (session.simulated ? RopeConfig.demo : const RopeConfig());
    final now = DateTime.now();
    final route = Route.synthetic(GeoPoint(adventure.lat, adventure.lng), lengthKm: adventure.distanceKm.clamp(1.5, 6.0));

    final engine = RopeEngine(selfId: self.id, memberIds: session.members.map((m) => m.id), startedAt: now, config: cfg);
    final PeerLink link = session.simulated
        ? SimulatedPeerLink(route: route, config: cfg)
        : BlePeerLink(
            config: cfg,
            onLog: (l) => debugPrint('[BLE] $l'),
            onGroupEnd: () {
              debugPrint('[ROPE] organizer ended the trek for everyone');
              state = state?.copyWith(endedByOrganizer: true);
            },
            onPosition: (memberId, fix) {
              final s = state;
              if (s == null) return;
              final p = GeoPoint(fix.lat, fix.lng);
              state = s.copyWith(
                positions: {...s.positions, memberId: p},
                positionTimes: {...s.positionTimes, memberId: fix.at},
                trails: s.trailWith(memberId, p),
              );
            },
            onSessionInfo: (info) async {
              final current = state;
              if (current == null) return;
              final updated = await ref.read(groupProvider.notifier).applySessionInfo(current.session.id, info);
              if (updated == null) return;
              (_link as BlePeerLink?)?.updateSession(updated);
              final s = state;
              if (s != null) state = s.withSession(updated);
            },
            onRosterChanged: (members, organizerId) async {
              final current = state;
              if (current == null) return;
              final updated = await ref.read(groupProvider.notifier).replaceMembers(current.session.id, members, organizerId: organizerId);
              debugPrint('[ROPE] roster ${members.length} members: ${members.map((m) => '${m.displayName}#${m.memberIndex}').join(', ')}');
              for (final m in members) {
                engine.addMember(m.id);
              }
              (_link as BlePeerLink?)?.updateSession(updated);
              final s = state;
              if (s != null) state = s.withSession(updated);
            },
          );
    _engine = engine;
    _link = link;

    // Demo groups walk the synthetic route; a real group shows only real GPS
    // fixes (ours and the ones other phones share), never a trailhead guess.
    state = session.simulated
        ? RopeSessionState(session: session, adventure: adventure, startedAt: now, route: route, simulated: true,
            selfPosition: route.at(0), positions: {for (final m in session.members) if (!m.isSelf) m.id: route.at(0)})
        : RopeSessionState(session: session, adventure: adventure, startedAt: now, route: route, simulated: false);

    _subs.add(link.observations.listen((o) {
      engine.observe(o);
      if (o.position != null) {
        final s = state;
        if (s != null) {
          state = s.copyWith(
            positions: {...s.positions, o.memberId: o.position!},
            positionTimes: {...s.positionTimes, o.memberId: o.at},
          );
        }
      }
    }));
    _subs.add(link.messages.listen((m) {
      final s = state;
      if (s == null) return;
      state = s.copyWith(log: [m, ...s.log].take(50).toList());
      if (m.type != RopeMessageType.position) debugPrint('[ROPE] msg ${m.type.name} from ${s.member(m.fromMemberId)?.displayName ?? m.fromMemberId}');
      if (m.fromMemberId != s.self?.id && m.type != RopeMessageType.position) {
        final who = s.member(m.fromMemberId)?.displayName ?? 'Group';
        RopeAlerts.instance.groupMessage(who, switch (m.type) {
          RopeMessageType.imOk => "I'm OK",
          RopeMessageType.waitForMe => 'Wait for me!',
          RopeMessageType.needHelp => 'NEEDS HELP',
          RopeMessageType.groupAlert => 'Group alert: regroup',
          RopeMessageType.stopGroup => 'Stop the group',
          RopeMessageType.position => '',
        }, alarm: m.type == RopeMessageType.needHelp || m.type == RopeMessageType.stopGroup);
      }
    }));

    debugPrint('[ROPE] start ${session.simulated ? 'demo' : 'ble'} session=${session.code} self=${self.displayName}#${self.memberIndex} members=${session.members.length}');
    try {
      await link.start(session: session, self: self);
      debugPrint('[ROPE] link started');
    } catch (e) {
      debugPrint('[ROPE] link start failed: $e');
      state = state?.copyWith(error: e.toString());
    }

    if (!session.simulated) {
      // Start together skips the checklist, so ask for alarm notifications here.
      await RopeAlerts.instance.requestPermission();
      final problem = await ensureLocationPermission();
      if (problem != null) state = state?.copyWith(error: problem.startsWith('Turn on Location') ? _locationOff : problem);
      _startGps();
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _tick();
  }

  static const _locationOff = 'Location is off. Turn on Location (GPS) so the group can see you.';
  StreamSubscription? _gpsSub;
  Timer? _gpsWatch;
  DateTime? _lastFixAt;

  void _startGps() {
    _listenGps();
    _seedGps();
    // Location switched on (or off) mid-trek: notice it and restart GPS.
    _gpsWatch = Timer.periodic(const Duration(seconds: 5), (_) => _checkGps());
  }

  void _listenGps() {
    _gpsSub?.cancel();
    _gpsSub = ref.read(positionStreamProvider).listen(_onFix, onError: (Object e) => debugPrint('[ROPE] gps error: $e'));
  }

  /// Show us on the map at once from the last known / a quick network fix,
  /// instead of waiting for satellite GPS (slow indoors).
  Future<void> _seedGps() async {
    try {
      final last = await geo.Geolocator.getLastKnownPosition();
      if (last != null && _lastFixAt == null) _onFix(last, countDistance: false);
    } catch (_) {}
    try {
      final now = await geo.Geolocator.getCurrentPosition(locationSettings: const geo.LocationSettings(accuracy: geo.LocationAccuracy.medium, timeLimit: Duration(seconds: 20)));
      if (_lastFixAt == null || DateTime.now().difference(_lastFixAt!) > const Duration(seconds: 20)) _onFix(now, countDistance: false);
    } catch (_) {}
  }

  Future<void> _checkGps() async {
    final s = state;
    if (s == null) return;
    final on = await geo.Geolocator.isLocationServiceEnabled();
    final cur = state;
    if (cur == null) return;
    if (!on) {
      if (cur.error != _locationOff) state = cur.copyWith(error: _locationOff);
    } else if (cur.error == _locationOff || (cur.error?.startsWith('Turn on Location') ?? false)) {
      debugPrint('[ROPE] location back on, restarting GPS');
      state = cur.copyWith(clearError: true);
      ref.invalidate(positionStreamProvider); // the old stream ended when Location went off
      _listenGps();
      _seedGps();
    }
  }

  void _onFix(geo.Position p, {bool countDistance = true}) {
    _lastFixAt = DateTime.now();
    // Do not present cached, invalid or inaccurate GPS as live tracking.
    final age = DateTime.now().difference(p.timestamp).abs();
    if (age > const Duration(seconds: 30) ||
        !p.latitude.isFinite || !p.longitude.isFinite ||
        !p.accuracy.isFinite || p.accuracy < 0 || p.accuracy > _ownTrack.maxAccuracyM) {
      return;
    }

    final fix = TrackPoint(
      lat: p.latitude,
      lng: p.longitude,
      at: p.timestamp,
      altitudeM: p.altitude.isFinite ? p.altitude : null,
      accuracyM: p.accuracy,
      speedMps: p.speed.isFinite && p.speed >= 0 ? p.speed : null,
    );
    final accepted = countDistance && _ownTrack.add(fix);
    final anchor = countDistance ? _ownTrack.last : fix;
    if (anchor == null) return;
    final here = anchor.geo;
    if (_link case final BlePeerLink l) {
      // Relay a stable position rather than a rejected GPS jump.
      l.updateSelfPosition(here.lat, here.lng, p.timestamp);
    }
    final s = state;
    if (s == null) return;
    final selfId = s.self?.id;
    state = s.copyWith(
      selfPosition: here,
      selfPositionAt: p.timestamp,
      distanceKm: _ownTrack.distanceKm,
      currentAltitudeM: _ownTrack.currentAltitudeM,
      trails: selfId == null || !accepted ? null : s.trailWith(selfId, here),
    );
  }

  void _tick() {
    final engine = _engine;
    final s = state;
    if (engine == null || s == null) return;
    final now = DateTime.now();
    final snap = engine.tick(now);
    _raiseAlerts(engine, snap, s);
    final sim = simulator;
    state = s.copyWith(
      snapshot: snap,
      elapsed: now.difference(s.startedAt),
      selfPosition: sim?.selfPosition,
      selfPositionAt: sim == null ? null : now,
      distanceKm: sim == null ? null : sim.selfProgress * s.route.lengthMetres / 1000,
    );
  }

  int _alertedEvents = 0;
  bool _wasIsolated = false;

  void _raiseAlerts(RopeEngine engine, RopeSnapshot snap, RopeSessionState s) {
    final events = engine.events;
    for (var i = _alertedEvents; i < events.length; i++) {
      final e = events[i];
      final name = s.member(e.memberId)?.displayName ?? 'A member';
      debugPrint('[ROPE] state $name ${e.from.name} -> ${e.to.name}');
      if (e.to.isAlerting || e.from.isAlerting) RopeAlerts.instance.memberChanged(name, e.to);
    }
    _alertedEvents = events.length;
    if (snap.selfIsolated != _wasIsolated) {
      _wasIsolated = snap.selfIsolated;
      debugPrint('[ROPE] self isolated=${snap.selfIsolated}');
      RopeAlerts.instance.selfIsolated(snap.selfIsolated);
    }
  }

  Future<void> sendAction(RopeMessageType type) async {
    final s = state;
    final link = _link;
    if (s == null || link == null) return;
    await link.send(RopeMessage(type: type, fromMemberId: s.self?.id ?? '', at: DateTime.now(), position: s.selfPosition));
  }

  // --- simulator controls (dev / demo) ---
  void simulate(String memberId, SimBehaviour behaviour) => simulator?.setBehaviour(memberId, behaviour);
  void simulateShoelace(String memberId) => simulator?.runShoelaceScenario(memberId, stoppedFor: config.separatedAfter + const Duration(seconds: 10));
  void simulateAllTogether() {
    final s = state;
    if (s == null) return;
    for (final m in s.others) {
      simulator?.setBehaviour(m.id, SimBehaviour.connected);
    }
  }

  /// Ends the session, persists a summary and returns it.
  /// Organizer: tell every phone the trek is over, give the heartbeats a few
  /// seconds to carry it, then end here too.
  Future<SessionSummary> endForAll() async {
    if (_link case final BlePeerLink l) {
      l.ending = true;
      await l.beatNow();
      await Future<void>.delayed(const Duration(seconds: 5));
    }
    return end();
  }

  Future<SessionSummary> end() async {
    final s = state;
    if (s == null) throw StateError('No active session');
    final engine = _engine;
    final summary = SessionSummary(
      sessionId: s.session.id,
      adventureId: s.adventure.id,
      adventureName: s.adventure.name,
      endedAt: DateTime.now(),
      durationSeconds: s.elapsed.inSeconds,
      memberCount: s.session.members.length,
      distanceKm: double.parse(s.distanceKm.toStringAsFixed(2)),
      maxElevationM: s.simulated ? s.adventure.elevationM : (_ownTrack.maxAltitudeM?.round() ?? 0),
      elevationGainM: s.simulated ? s.adventure.elevationGainM : _ownTrack.gainM,
      separationEvents: engine?.events.where((e) => e.to == RopeState.separated).length ?? 0,
      fallingBehindEvents: engine?.events.where((e) => e.to == RopeState.fallingBehind).length ?? 0,
      simulated: s.simulated,
    );
    await ref.read(historyProvider.notifier).record(summary);
    // Beta metrics: keep the full event log for export (Settings → Digital Rope logs).
    await RopeLogStore(ref.read(localStoreProvider)).save(RopeSessionLog.capture(
      sessionId: s.session.id,
      groupName: s.session.name,
      adventureName: s.adventure.name,
      startedAt: s.startedAt,
      endedAt: summary.endedAt,
      memberCount: s.session.members.length,
      simulated: s.simulated,
      events: engine?.events ?? const [],
      messages: s.log,
      memberNames: {for (final m in s.session.members) m.id: m.displayName},
    ));
    // Track for the summary map: real GPS in BLE mode, the synthetic route walked so far in demo mode.
    final sim = simulator;
    final points = sim != null
        ? [
            for (var i = 0; i <= 40; i++)
              TrackPoint(
                lat: s.route.at(i / 40 * sim.selfProgress).lat,
                lng: s.route.at(i / 40 * sim.selfProgress).lng,
                at: s.startedAt.add(s.elapsed * (i / 40)),
                altitudeM: (s.adventure.elevationM - s.adventure.elevationGainM + s.adventure.elevationGainM * (i / 40) * sim.selfProgress).toDouble(),
              ),
          ]
        : List<TrackPoint>.of(_ownTrack.points);
    await ref.read(trackStoreProvider).save(
      'session-${s.session.id}',
      TrackData(points: points, movingTime: sim != null ? s.elapsed : _ownTrack.movingTime, accuracyRatio: sim != null ? 0 : _ownTrack.accuracyRatio),
    );
    await ref.read(activitiesProvider.notifier).add(ActivityRecord.fromSessionSummary(
      summary,
      type: ActivityType.values.firstWhere((t) => t.name == s.adventure.primaryCategory.name, orElse: () => ActivityType.trekking),
      district: s.adventure.district,
    ));
    await ref.read(groupProvider.notifier).setStatus(s.session.id, SessionStatus.completed, endedAt: summary.endedAt);
    await _teardown();
    await RopeAlerts.instance.clearAll();
    state = null;
    return summary;
  }

  Future<void> _teardown() async {
    _ticker?.cancel();
    _ticker = null;
    _gpsWatch?.cancel();
    _gpsWatch = null;
    await _gpsSub?.cancel();
    _gpsSub = null;
    _lastFixAt = null;
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    final link = _link;
    _link = null;
    if (link != null) {
      try {
        await link.stop();
      } catch (_) {}
      if (link is SimulatedPeerLink) link.dispose();
      if (link is BlePeerLink) link.dispose();
    }
    _engine?.dispose();
    _engine = null;
    _ownTrack = TrackRecorder();
    _alertedEvents = 0;
    _wasIsolated = false;
  }
}

final ropeProvider = NotifierProvider<RopeController, RopeSessionState?>(RopeController.new);
