import 'dart:math' as math;

/// Minimal geo types so the engine stays free of Flutter and map packages.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;

  @override
  String toString() => 'GeoPoint(${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
}

/// Great-circle distance in metres.
double haversineMetres(GeoPoint a, GeoPoint b) {
  const r = 6371000.0;
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

double _rad(double deg) => deg * math.pi / 180;

/// A polyline with cumulative distances, used to place simulated members.
class Route {
  Route(this.points) : cumulative = _cumulative(points);

  /// Synthetic trail: heads roughly north-east from [start] for [lengthKm]
  /// with a gentle sinusoidal wiggle. Good enough for the simulator.
  factory Route.synthetic(GeoPoint start, {double lengthKm = 4, int segments = 40}) {
    final pts = <GeoPoint>[];
    final totalDegLat = lengthKm / 111.0 * 0.7;
    final totalDegLng = lengthKm / (111.0 * math.cos(_rad(start.lat))) * 0.7;
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      final wiggle = math.sin(t * math.pi * 3) * 0.0012;
      pts.add(GeoPoint(start.lat + totalDegLat * t + wiggle, start.lng + totalDegLng * t - wiggle * 0.6));
    }
    return Route(pts);
  }

  final List<GeoPoint> points;
  final List<double> cumulative;

  double get lengthMetres => cumulative.isEmpty ? 0 : cumulative.last;

  /// Position at [fraction] (0..1) along the route.
  GeoPoint at(double fraction) {
    if (points.length < 2) return points.first;
    final target = fraction.clamp(0.0, 1.0) * lengthMetres;
    for (var i = 1; i < points.length; i++) {
      if (cumulative[i] >= target) {
        final segLen = cumulative[i] - cumulative[i - 1];
        final t = segLen == 0 ? 0.0 : (target - cumulative[i - 1]) / segLen;
        final a = points[i - 1];
        final b = points[i];
        return GeoPoint(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);
      }
    }
    return points.last;
  }

  static List<double> _cumulative(List<GeoPoint> pts) {
    final out = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      out.add(out[i - 1] + haversineMetres(pts[i - 1], pts[i]));
    }
    return out;
  }
}
