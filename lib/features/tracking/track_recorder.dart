import 'dart:math' as math;

import '../rope/engine/geo.dart';

/// One GPS fix as the recorder sees it (platform-agnostic).
class TrackPoint {
  const TrackPoint({
    required this.lat,
    required this.lng,
    required this.at,
    this.altitudeM,
    this.accuracyM = 0,
    this.speedMps,
  });

  factory TrackPoint.fromJson(Map<String, dynamic> j) => TrackPoint(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        at: DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
        altitudeM: (j['alt'] as num?)?.toDouble(),
        accuracyM: (j['acc'] as num?)?.toDouble() ?? 0,
        speedMps: (j['v'] as num?)?.toDouble(),
      );

  final double lat;
  final double lng;
  final DateTime at;
  final double? altitudeM;
  final double accuracyM;
  final double? speedMps;

  GeoPoint get geo => GeoPoint(lat, lng);

  Map<String, dynamic> toJson() => {
        'lat': double.parse(lat.toStringAsFixed(6)),
        'lng': double.parse(lng.toStringAsFixed(6)),
        't': at.millisecondsSinceEpoch,
        if (altitudeM != null) 'alt': double.parse(altitudeM!.toStringAsFixed(1)),
        'acc': double.parse(accuracyM.toStringAsFixed(1)),
        if (speedMps != null) 'v': double.parse(speedMps!.toStringAsFixed(2)),
      };
}

/// Turns raw fixes into distance, elevation gain, altitude and moving time.
///
/// Filters: poor accuracy, impossible speed (teleports), non-monotonic time.
/// Altitude is smoothed with a rolling median and gain only counts climbs
/// above a threshold so GPS jitter does not inflate it.
class TrackRecorder {
  TrackRecorder({
    this.maxAccuracyM = 25,
    this.maxSpeedMps = 8,
    this.gainThresholdM = 3,
    this.altitudeWindow = 5,
    this.movingSpeedMps = 0.5,
    this.minMovementM = 5,
    this.accuracyMovementFactor = 1.4,
  });

  final double maxAccuracyM;
  final double maxSpeedMps;
  final double gainThresholdM;
  final int altitudeWindow;
  final double movingSpeedMps;

  /// Suppress GPS wandering while a phone is stationary. Movement must
  /// exceed both this floor and the uncertainty of the two fixes.
  final double minMovementM;
  final double accuracyMovementFactor;

  final List<TrackPoint> points = [];
  final List<double> _altBuffer = [];
  double? _gainBase;

  double distanceM = 0;
  int gainM = 0;
  double? maxAltitudeM;
  double? currentAltitudeM;
  Duration movingTime = Duration.zero;
  int received = 0;
  int rejected = 0;
  int ignored = 0;

  DateTime? get startedAt => points.isEmpty ? null : points.first.at;
  TrackPoint? get last => points.isEmpty ? null : points.last;
  double get distanceKm => distanceM / 1000;

  /// Share of fixes that were accurate enough; part of the "verified" rule.
  double get accuracyRatio => received == 0 ? 0 : (received - rejected) / received;

  /// GPS-verified: mostly good fixes and a real distance. See tasks/09.
  bool get verified => accuracyRatio >= 0.8 && distanceM >= 500;

  /// Returns true when the point was accepted.
  bool add(TrackPoint p) {
    received++;
    if (!p.lat.isFinite || !p.lng.isFinite ||
        p.lat.abs() > 90 || p.lng.abs() > 180 ||
        !p.accuracyM.isFinite || p.accuracyM < 0 ||
        p.accuracyM > maxAccuracyM) {
      rejected++;
      return false;
    }
    final prev = last;
    if (prev != null) {
      final dt = p.at.difference(prev.at).inMilliseconds / 1000;
      if (dt <= 0) {
        rejected++;
        return false;
      }
      final d = haversineMetres(prev.geo, p.geo);
      final v = d / dt;
      if (v > maxSpeedMps) {
        rejected++;
        return false;
      }
      // Indoors a stationary phone can wander many metres between fixes.
      // Wait until the displacement exceeds the reported GPS uncertainty,
      // then only count movement when it is also plausible over time.
      final noiseFloor = math.max(
        minMovementM,
        accuracyMovementFactor * math.max(prev.accuracyM, p.accuracyM),
      );
      final reportedStationary = p.speedMps != null &&
          p.speedMps!.isFinite && p.speedMps! >= 0 &&
          p.speedMps! < movingSpeedMps;
      if (d < noiseFloor ||
          (reportedStationary &&
              d < math.max(noiseFloor, 2 * math.max(prev.accuracyM, p.accuracyM)))) {
        // A stationary or too-small change is not a bad GPS fix; it just
        // must not count toward distance or a drawn route.
        ignored++;
        return false;
      }
      distanceM += d;
      if (v >= movingSpeedMps) {
        movingTime += Duration(milliseconds: (dt * 1000).round());
      }
    }
    points.add(p);
    _updateAltitude(p.altitudeM);
    return true;
  }

  void _updateAltitude(double? alt) {
    if (alt == null) return;
    _altBuffer.add(alt);
    if (_altBuffer.length > altitudeWindow) _altBuffer.removeAt(0);
    final sorted = [..._altBuffer]..sort();
    final smoothed = sorted[sorted.length ~/ 2];
    currentAltitudeM = smoothed;
    maxAltitudeM = maxAltitudeM == null ? smoothed : math.max(maxAltitudeM!, smoothed);
    final base = _gainBase;
    if (base == null) {
      _gainBase = smoothed;
    } else if (smoothed - base >= gainThresholdM) {
      gainM += (smoothed - base).round();
      _gainBase = smoothed;
    } else if (smoothed < base) {
      _gainBase = smoothed;
    }
  }

  /// Every [n]th point plus the last, for storage and maps.
  List<TrackPoint> downsample([int n = 3]) {
    if (points.length <= 2) return List.of(points);
    return [for (var i = 0; i < points.length; i++) if (i % n == 0 || i == points.length - 1) points[i]];
  }

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => p.toJson()).toList(),
        'distanceM': distanceM,
        'gainM': gainM,
        'maxAlt': maxAltitudeM,
        'curAlt': currentAltitudeM,
        'movingMs': movingTime.inMilliseconds,
        'received': received,
        'rejected': rejected,
        'ignored': ignored,
        'gainBase': _gainBase,
        'altBuf': _altBuffer,
      };

  static TrackRecorder fromJson(Map<String, dynamic> j) {
    final r = TrackRecorder();
    r.points.addAll((j['points'] as List).map((e) => TrackPoint.fromJson(e as Map<String, dynamic>)));
    r.distanceM = (j['distanceM'] as num).toDouble();
    r.gainM = (j['gainM'] as num).toInt();
    r.maxAltitudeM = (j['maxAlt'] as num?)?.toDouble();
    r.currentAltitudeM = (j['curAlt'] as num?)?.toDouble();
    r.movingTime = Duration(milliseconds: (j['movingMs'] as num).toInt());
    r.received = j['received'] as int;
    r.rejected = j['rejected'] as int;
    r.ignored = (j['ignored'] as num?)?.toInt() ?? 0;
    r._gainBase = (j['gainBase'] as num?)?.toDouble();
    r._altBuffer.addAll(((j['altBuf'] as List?) ?? const []).map((e) => (e as num).toDouble()));
    return r;
  }
}
