import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../tracking/track_recorder.dart';

/// Stored GPS track for an activity (downsampled points + a few aggregates).
class TrackData {
  const TrackData({required this.points, required this.movingTime, required this.accuracyRatio});

  factory TrackData.fromJson(Map<String, dynamic> j) => TrackData(
        points: (j['points'] as List).map((e) => TrackPoint.fromJson(e as Map<String, dynamic>)).toList(),
        movingTime: Duration(milliseconds: (j['movingMs'] as num?)?.toInt() ?? 0),
        accuracyRatio: (j['accuracyRatio'] as num?)?.toDouble() ?? 0,
      );

  final List<TrackPoint> points;
  final Duration movingTime;
  final double accuracyRatio;

  bool get hasRoute => points.length >= 2;
  bool get hasElevation => points.where((p) => p.altitudeM != null).length >= 3;

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => p.toJson()).toList(),
        'movingMs': movingTime.inMilliseconds,
        'accuracyRatio': accuracyRatio,
      };

  /// (cumulative distance in m, altitude in m) pairs for the profile chart.
  List<(double, double)> elevationProfile() {
    final out = <(double, double)>[];
    double dist = 0;
    TrackPoint? prev;
    for (final p in points) {
      if (prev != null) dist += _haversine(prev, p);
      if (p.altitudeM != null) out.add((dist, p.altitudeM!));
      prev = p;
    }
    return out;
  }

  static double _haversine(TrackPoint a, TrackPoint b) {
    const r = 6371000.0;
    final dLat = (b.lat - a.lat) * 3.141592653589793 / 180;
    final dLng = (b.lng - a.lng) * 3.141592653589793 / 180;
    final la = a.lat * 3.141592653589793 / 180;
    final lb = b.lat * 3.141592653589793 / 180;
    final h = _sq(_sin(dLat / 2)) + _cos(la) * _cos(lb) * _sq(_sin(dLng / 2));
    return 2 * r * _asin(h < 0 ? 0 : (h > 1 ? 1 : _sqrt(h)));
  }

  static double _sq(double x) => x * x;
  static double _sin(double x) => _taylor(x, false);
  static double _cos(double x) => _taylor(x, true);
  static double _sqrt(double x) {
    if (x <= 0) return 0;
    var g = x;
    for (var i = 0; i < 30; i++) {
      g = 0.5 * (g + x / g);
    }
    return g;
  }

  static double _asin(double x) {
    // Newton on sin(y) = x; adequate for the small arguments haversine produces.
    var y = x;
    for (var i = 0; i < 12; i++) {
      y -= (_sin(y) - x) / _cos(y);
    }
    return y;
  }

  static double _taylor(double a, bool cos) {
    const pi = 3.141592653589793;
    a = a % (2 * pi);
    if (a > pi) a -= 2 * pi;
    if (a < -pi) a += 2 * pi;
    double term = cos ? 1 : a;
    double sum = term;
    final a2 = a * a;
    for (var n = 1; n < 12; n++) {
      final k = cos ? (2 * n - 1) * (2 * n) : (2 * n) * (2 * n + 1);
      term *= -a2 / k;
      sum += term;
    }
    return sum;
  }
}

class TrackStore {
  TrackStore(this._ref);
  final Ref _ref;

  TrackData? load(String activityId) {
    final raw = _ref.read(localStoreProvider).rawString('track_$activityId');
    if (raw == null) return null;
    try {
      return TrackData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String activityId, TrackData data) =>
      _ref.read(localStoreProvider).setRaw('track_$activityId', jsonEncode(data.toJson()));

  Future<void> delete(String activityId) => _ref.read(localStoreProvider).removeRaw('track_$activityId');
}

final trackStoreProvider = Provider<TrackStore>((ref) => TrackStore(ref));

final trackDataProvider = Provider.family<TrackData?, String>((ref, id) {
  ref.watch(activitiesProvider); // refresh when activities change
  return ref.read(trackStoreProvider).load(id);
});
