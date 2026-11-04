import 'dart:async';
import 'dart:math' as math;

import 'geo.dart';
import 'rope_config.dart';
import 'rope_models.dart';

/// Pure-Dart Digital Rope state machine.
///
/// Feed it [PeerObservation]s as heartbeats arrive, call [tick] on a timer,
/// and read [RopeSnapshot]s. It never talks to Bluetooth, GPS or the UI,
/// so the whole safety logic is unit-testable with a fake clock.
class RopeEngine {
  RopeEngine({
    required this.selfId,
    required Iterable<String> memberIds,
    required DateTime startedAt,
    this.config = const RopeConfig(),
  }) : _startedAt = startedAt {
    for (final id in memberIds) {
      if (id != selfId) _tracked[id] = _Tracked(id, startedAt);
    }
  }

  final String selfId;
  final RopeConfig config;
  final DateTime _startedAt;
  final Map<String, _Tracked> _tracked = {};
  final List<RopeEvent> events = [];
  final _snapshots = StreamController<RopeSnapshot>.broadcast();

  Stream<RopeSnapshot> get snapshots => _snapshots.stream;
  RopeSnapshot? latest;
  DateTime get startedAt => _startedAt;

  Iterable<String> get memberIds => _tracked.keys;

  /// Members added after start (late joiners) are judged from the moment they
  /// were added, not from the session start, so they do not appear separated
  /// the instant they join.
  void addMember(String id, {DateTime? at}) {
    if (id != selfId) _tracked.putIfAbsent(id, () => _Tracked(id, at ?? DateTime.now()));
  }

  void observe(PeerObservation o) {
    final t = _tracked[o.memberId];
    if (t == null) return;
    if (o.viaChain) {
      if (t.lastChain == null || o.at.isAfter(t.lastChain!)) t.lastChain = o.at;
    } else {
      if (t.lastDirect == null || o.at.isAfter(t.lastDirect!)) t.lastDirect = o.at;
      if (o.rssi != null) {
        t.rssi.add(_Sample(o.at, o.rssi!));
        t.lastRssi = o.rssi;
        final cutoff = o.at.subtract(config.rssiWindow);
        t.rssi.removeWhere((s) => s.at.isBefore(cutoff));
      }
    }
    if (o.position != null) {
      t.lastKnownPosition = o.position;
      t.lastPositionAt = o.at;
    }
    t.heardSinceDegraded++;
  }

  /// Record our own last-known position for a member we can no longer hear
  /// (e.g. from a neighbour's relayed GPS message).
  void updatePosition(String memberId, GeoPoint position, DateTime at) {
    final t = _tracked[memberId];
    if (t == null) return;
    t.lastKnownPosition = position;
    t.lastPositionAt = at;
  }

  RopeSnapshot tick(DateTime now) {
    final members = <String, RopeMemberState>{};
    for (final t in _tracked.values) {
      final lastSeen = t.lastSeen ?? t.addedAt;
      final since = now.difference(lastSeen);
      final missed = since.inMilliseconds ~/ config.heartbeatInterval.inMilliseconds;
      final drop = _rssiDrop(t, now);

      RopeState candidate;
      if (since >= config.separatedAfter) {
        t.separatedSince ??= lastSeen.add(config.separatedAfter);
        candidate = now.difference(t.separatedSince!) >= config.criticalAfter
            ? RopeState.critical
            : RopeState.separated;
      } else {
        t.separatedSince = null;
        if (since >= config.fallingBehindAfter) {
          candidate = RopeState.fallingBehind;
        } else if (missed >= config.weakMissedHeartbeats ||
            (drop != null && drop >= _effectiveWeakDropDb(t, now))) {
          t.weakSince ??= now;
          candidate = now.difference(t.weakSince!) >= config.weakSustainedForFallingBehind
              ? RopeState.fallingBehind
              : RopeState.weak;
        } else {
          t.weakSince = null;
          candidate = RopeState.connected;
        }
      }

      // Hysteresis: leaving an alerting state needs a few clean heartbeats.
      if (candidate.severity < t.state.severity &&
          (t.state.isAlerting || t.state == RopeState.weak) &&
          t.heardSinceDegraded < config.recoveryHeartbeats) {
        candidate = t.state;
      }

      if (candidate != t.state) {
        events.add(RopeEvent(at: now, memberId: t.id, from: t.state, to: candidate));
        t.state = candidate;
        t.stateSince = now;
        if (candidate.isAlerting || candidate == RopeState.weak) t.heardSinceDegraded = 0;
      }

      members[t.id] = RopeMemberState(
        memberId: t.id,
        state: t.state,
        stateSince: t.stateSince,
        lastDirectSeen: t.lastDirect,
        lastChainSeen: t.lastChain,
        missedHeartbeats: missed,
        rssiTrendDb: drop,
        lastRssi: t.lastRssi,
        lastKnownPosition: t.lastKnownPosition,
        lastPositionAt: t.lastPositionAt,
      );
    }

    // "I am the one who fell behind" needs a strict majority of the others to be
    // quiet at once; otherwise one stale or separated member would trigger it.
    final others = members.length;
    final quiet = members.values.where((m) => m.state.isAlerting).length;
    final selfIsolated = others >= 2 && quiet * 2 > others;

    final snap = RopeSnapshot(at: now, members: members, selfIsolated: selfIsolated);
    latest = snap;
    _snapshots.add(snap);
    return snap;
  }

  /// Median RSSI of the older half of the window minus the newer half.
  double? _rssiDrop(_Tracked t, DateTime now) {
    if (t.rssi.length < 4) return null;
    final mid = now.subtract(config.rssiWindow ~/ 2);
    final older = t.rssi.where((s) => s.at.isBefore(mid)).map((s) => s.rssi).toList();
    final newer = t.rssi.where((s) => !s.at.isBefore(mid)).map((s) => s.rssi).toList();
    if (older.length < 2 || newer.length < 2) return null;
    return _median(older) - _median(newer);
  }

  double _effectiveWeakDropDb(_Tracked t, DateTime now) {
    final mid = now.subtract(config.rssiWindow ~/ 2);
    final older = t.rssi.where((s) => s.at.isBefore(mid)).map((s) => s.rssi).toList();
    final newer = t.rssi.where((s) => !s.at.isBefore(mid)).map((s) => s.rssi).toList();
    if (older.length < 2 || newer.length < 2) return config.weakRssiDropDb.toDouble();
    // Median absolute deviation is robust against isolated BLE reflections.
    double mad(List<int> xs) {
      final middle = _median(xs);
      return _median(xs.map((v) => (v - middle).abs().round()).toList());
    }
    final jitter = math.max(mad(older), mad(newer));
    return math.max(config.weakRssiDropDb.toDouble(), jitter * config.rssiJitterMultiplier);
  }

  double _median(List<int> xs) {
    final s = [...xs]..sort();
    final n = s.length;
    return n.isOdd ? s[n ~/ 2].toDouble() : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
  }

  void dispose() => _snapshots.close();
}

class _Sample {
  _Sample(this.at, this.rssi);
  final DateTime at;
  final int rssi;
}

class _Tracked {
  _Tracked(this.id, DateTime start)
      : stateSince = start,
        addedAt = start;
  final String id;
  final DateTime addedAt;
  RopeState state = RopeState.connected;
  DateTime stateSince;
  DateTime? lastDirect;
  DateTime? lastChain;
  DateTime? weakSince;
  DateTime? separatedSince;
  int heardSinceDegraded = 0;
  int? lastRssi;
  final List<_Sample> rssi = [];
  GeoPoint? lastKnownPosition;
  DateTime? lastPositionAt;

  DateTime? get lastSeen {
    if (lastDirect == null) return lastChain;
    if (lastChain == null) return lastDirect;
    return lastDirect!.isAfter(lastChain!) ? lastDirect : lastChain;
  }
}
