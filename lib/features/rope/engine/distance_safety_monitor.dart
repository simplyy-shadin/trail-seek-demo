import 'geo.dart';

/// An optional, GPS-only *spacing* estimate, not a Bluetooth distance meter.
/// Remote GPS accuracy is not currently included in BLE roster frames: use a
/// conservative uncertainty margin and never call this a proof of separation.
enum SpacingLevel { normal, warning, urgent }

class SpacingChange {
  const SpacingChange(this.memberId, this.level, this.metres);
  final String memberId;
  final SpacingLevel level;
  final double metres;
}

class DistanceSafetyMonitor {
  DistanceSafetyMonitor({
    this.warnMetres = 75,
    this.urgentMetres = 150,
    this.clearMetres = 50,
    this.maxFixAge = const Duration(seconds: 12),
    this.maxSelfAccuracyMetres = 20,
    this.remoteUncertaintyMetres = 30,
    this.confirmSamples = 2,
    this.repeatCooldown = const Duration(minutes: 1),
  });

  final double warnMetres;
  final double urgentMetres;
  final double clearMetres;
  final Duration maxFixAge;
  final double maxSelfAccuracyMetres;
  final double remoteUncertaintyMetres;
  final int confirmSamples;
  final Duration repeatCooldown;
  final Map<String, _SpacingState> _states = {};

  SpacingChange? observe({
    required String memberId,
    required GeoPoint? self,
    required DateTime? selfAt,
    required GeoPoint? peer,
    required DateTime? peerAt,
    required DateTime now,
    required double selfAccuracyMetres,
  }) {
    if (self == null || selfAt == null || peer == null || peerAt == null ||
        selfAccuracyMetres < 0 || selfAccuracyMetres > maxSelfAccuracyMetres ||
        now.difference(selfAt).isNegative || now.difference(peerAt).isNegative ||
        now.difference(selfAt) > maxFixAge || now.difference(peerAt) > maxFixAge) {
      return null; // Unknown is NOT an automatic missing-person alarm.
    }

    final distance = haversineMetres(self, peer);
    final conservative = distance - selfAccuracyMetres - remoteUncertaintyMetres;
    final desired = conservative >= urgentMetres
        ? SpacingLevel.urgent
        : conservative >= warnMetres
            ? SpacingLevel.warning
            : conservative < clearMetres
                ? SpacingLevel.normal
                : null; // Hysteresis dead zone.
    if (desired == null) return null;
    final state = _states.putIfAbsent(memberId, _SpacingState.new);
    // A 1-second UI tick is not a second independent GPS observation.
    if (state.lastSelfAt == selfAt && state.lastPeerAt == peerAt) return null;
    state.lastSelfAt = selfAt;
    state.lastPeerAt = peerAt;
    if (desired != state.candidate) {
      state.candidate = desired;
      state.samples = 1;
    } else {
      state.samples++;
    }
    if (state.samples < confirmSamples) return null;
    if (state.level == desired) return null;
    // Recovered only after the stricter clear-distance threshold.
    if (desired == SpacingLevel.normal ||
        state.lastChangeAt == null ||
        now.difference(state.lastChangeAt!) >= repeatCooldown ||
        desired.index > state.level.index) {
      state.level = desired;
      state.lastChangeAt = now;
      return SpacingChange(memberId, desired, distance);
    }
    return null;
  }

  void clear() => _states.clear();
}

class _SpacingState {
  SpacingLevel level = SpacingLevel.normal;
  SpacingLevel? candidate;
  int samples = 0;
  DateTime? lastSelfAt;
  DateTime? lastPeerAt;
  DateTime? lastChangeAt;
}
