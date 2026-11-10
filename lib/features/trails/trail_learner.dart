import 'dart:math' as math;

import '../rope/engine/geo.dart';

/// One person's recorded path on an adventure.
class Walk {
  const Walk({required this.walkerId, required this.points, this.at});
  final String walkerId;
  final List<GeoPoint> points;
  final DateTime? at;

  Map<String, dynamic> toJson() => {
        'w': walkerId,
        if (at != null) 't': at!.millisecondsSinceEpoch,
        'p': [for (final p in points) [double.parse(p.lat.toStringAsFixed(6)), double.parse(p.lng.toStringAsFixed(6))]],
      };

  factory Walk.fromJson(Map<String, dynamic> j) => Walk(
        walkerId: j['w'] as String,
        at: j['t'] == null ? null : DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt()),
        points: [for (final p in j['p'] as List) GeoPoint((p[0] as num).toDouble(), (p[1] as num).toDouble())],
      );
}

/// A trail the crowd has walked: one or more line pieces, and how many
/// different people back it up.
class LearnedTrail {
  const LearnedTrail({required this.segments, required this.walkers});
  final List<List<GeoPoint>> segments;
  final int walkers;

  bool get isEmpty => segments.isEmpty;

  double get lengthM {
    var total = 0.0;
    for (final s in segments) {
      for (var i = 1; i < s.length; i++) {
        total += haversineMetres(s[i - 1], s[i]);
      }
    }
    return total;
  }

  Map<String, dynamic> toJson() => {
        'n': walkers,
        's': [
          for (final s in segments) [for (final p in s) [double.parse(p.lat.toStringAsFixed(6)), double.parse(p.lng.toStringAsFixed(6))]],
        ],
      };

  factory LearnedTrail.fromJson(Map<String, dynamic> j) => LearnedTrail(
        walkers: (j['n'] as num).toInt(),
        segments: [
          for (final s in j['s'] as List) [for (final p in s as List) GeoPoint((p[0] as num).toDouble(), (p[1] as num).toDouble())],
        ],
      );

  static const none = LearnedTrail(segments: [], walkers: 0);
}

/// Learns a trail from many people's walks, with no map data at all.
///
/// Where at least [minWalkers] different people walked within [corridorM] of
/// each other, that stretch becomes trail. Its line is the average of those
/// people's positions (one nearest point each), so one phone's bad GPS is
/// pulled back by the others. Places only one or two people went (a detour,
/// a wrong turn, a drifting GPS) never show up.
class TrailLearner {
  const TrailLearner({this.minWalkers = 3, this.corridorM = 12, this.stepM = 5, this.minSegmentM = 40, this.maxBranches = 6});

  final int minWalkers;
  final double corridorM;
  final double stepM;
  final double minSegmentM;
  final int maxBranches;

  LearnedTrail learn(List<Walk> walks) {
    // The same person walking twice counts once.
    final byWalker = <String, List<List<GeoPoint>>>{};
    for (final w in walks) {
      if (w.points.length < 2) continue;
      byWalker.putIfAbsent(w.walkerId, () => []).add(_resample(w.points));
    }
    if (byWalker.length < minWalkers) return LearnedTrail.none;

    final origin = byWalker.values.first.first.first;
    final proj = _Projection(origin);
    final cell = corridorM;
    // Grid of cell -> walkers who passed within the corridor.
    final support = <(int, int), Set<String>>{};
    // Cell -> (walker, local xy) samples for averaging.
    final samples = <(int, int), List<(String, double, double)>>{};
    for (final entry in byWalker.entries) {
      for (final line in entry.value) {
        for (final p in line) {
          final (x, y) = proj.xy(p);
          final cx = (x / cell).floor(), cy = (y / cell).floor();
          samples.putIfAbsent((cx, cy), () => []).add((entry.key, x, y));
          for (var dx = -1; dx <= 1; dx++) {
            for (var dy = -1; dy <= 1; dy++) {
              support.putIfAbsent((cx + dx, cy + dy), () => {}).add(entry.key);
            }
          }
        }
      }
    }

    bool backed(double x, double y) => (support[((x / cell).floor(), (y / cell).floor())]?.length ?? 0) >= minWalkers;

    /// The crowd's centre near (x, y): each walker's nearest sample within the
    /// corridor, averaged. Null when fewer than [minWalkers] are that close.
    (double, double)? centre(double x, double y) {
      final cx = (x / cell).floor(), cy = (y / cell).floor();
      final nearest = <String, (double, double, double)>{};
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          for (final (w, sx, sy) in samples[(cx + dx, cy + dy)] ?? const <(String, double, double)>[]) {
            final d = (sx - x) * (sx - x) + (sy - y) * (sy - y);
            if (d > corridorM * corridorM) continue;
            final best = nearest[w];
            if (best == null || d < best.$3) nearest[w] = (sx, sy, d);
          }
        }
      }
      if (nearest.length < minWalkers) return null;
      var mx = 0.0, my = 0.0;
      for (final v in nearest.values) {
        mx += v.$1;
        my += v.$2;
      }
      return (mx / nearest.length, my / nearest.length);
    }

    final segments = <List<GeoPoint>>[];
    final covered = <(int, int)>{};
    final lines = [for (final ls in byWalker.values) ...ls];
    for (var branch = 0; branch < maxBranches; branch++) {
      // Next guide line: the walk with the most crowd-backed, not yet drawn stretch.
      List<GeoPoint>? guide;
      var best = 0;
      for (final line in lines) {
        var n = 0;
        for (final p in line) {
          final (x, y) = proj.xy(p);
          if (backed(x, y) && !covered.contains(((x / cell).floor(), (y / cell).floor()))) n++;
        }
        if (n > best) {
          best = n;
          guide = line;
        }
      }
      if (guide == null || best * stepM < minSegmentM) break;

      var current = <GeoPoint>[];
      void close() {
        final smooth = _smooth(current);
        if (_length(smooth) >= minSegmentM) segments.add(_simplify(smooth, 1.5));
        current = <GeoPoint>[];
      }

      for (final p in guide) {
        final (x, y) = proj.xy(p);
        final key = ((x / cell).floor(), (y / cell).floor());
        final c = backed(x, y) && !covered.contains(key) ? centre(x, y) : null;
        if (c == null) {
          if (current.isNotEmpty) close();
          continue;
        }
        current.add(proj.geo(c.$1, c.$2));
      }
      if (current.isNotEmpty) close();
      // Mark this guide's corridor as drawn so the next branch is a new one.
      for (final p in guide) {
        final (x, y) = proj.xy(p);
        final cx = (x / cell).floor(), cy = (y / cell).floor();
        for (var dx = -1; dx <= 1; dx++) {
          for (var dy = -1; dy <= 1; dy++) {
            covered.add((cx + dx, cy + dy));
          }
        }
      }
    }
    return segments.isEmpty ? LearnedTrail.none : LearnedTrail(segments: segments, walkers: byWalker.length);
  }

  /// Even spacing so a fast or slow phone weighs the same.
  List<GeoPoint> _resample(List<GeoPoint> pts) {
    final out = <GeoPoint>[pts.first];
    var carry = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      final d = haversineMetres(a, b);
      if (d == 0) continue;
      var t = stepM - carry;
      while (t <= d) {
        final f = t / d;
        out.add(GeoPoint(a.lat + (b.lat - a.lat) * f, a.lng + (b.lng - a.lng) * f));
        t += stepM;
      }
      carry = d - (t - stepM);
    }
    if (haversineMetres(out.last, pts.last) > 0.5) out.add(pts.last);
    return out;
  }

  static List<GeoPoint> _smooth(List<GeoPoint> s) {
    if (s.length < 3) return s;
    return [
      s.first,
      for (var i = 1; i < s.length - 1; i++)
        GeoPoint((s[i - 1].lat + s[i].lat * 2 + s[i + 1].lat) / 4, (s[i - 1].lng + s[i].lng * 2 + s[i + 1].lng) / 4),
      s.last,
    ];
  }

  static double _length(List<GeoPoint> s) {
    var t = 0.0;
    for (var i = 1; i < s.length; i++) {
      t += haversineMetres(s[i - 1], s[i]);
    }
    return t;
  }

  /// Douglas–Peucker in metres.
  static List<GeoPoint> _simplify(List<GeoPoint> s, double tolM) {
    if (s.length < 3) return s;
    final proj = _Projection(s.first);
    final xy = [for (final p in s) proj.xy(p)];
    final keep = List<bool>.filled(s.length, false)..[0] = true..[s.length - 1] = true;
    void rec(int a, int b) {
      if (b <= a + 1) return;
      final (ax, ay) = xy[a];
      final (bx, by) = xy[b];
      final dx = bx - ax, dy = by - ay;
      final len = math.sqrt(dx * dx + dy * dy);
      var far = -1.0;
      var at = -1;
      for (var i = a + 1; i < b; i++) {
        final (px, py) = xy[i];
        final d = len == 0 ? math.sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay)) : ((px - ax) * dy - (py - ay) * dx).abs() / len;
        if (d > far) {
          far = d;
          at = i;
        }
      }
      if (far > tolM) {
        keep[at] = true;
        rec(a, at);
        rec(at, b);
      }
    }

    rec(0, s.length - 1);
    return [for (var i = 0; i < s.length; i++) if (keep[i]) s[i]];
  }
}

/// Flat metres around an origin; plenty for a trek a few km across.
class _Projection {
  _Projection(this.o) : _k = math.cos(o.lat * math.pi / 180);
  final GeoPoint o;
  final double _k;
  static const _m = 111320.0;

  (double, double) xy(GeoPoint p) => ((p.lng - o.lng) * _m * _k, (p.lat - o.lat) * _m);
  GeoPoint geo(double x, double y) => GeoPoint(o.lat + y / _m, o.lng + x / (_m * _k));
}
