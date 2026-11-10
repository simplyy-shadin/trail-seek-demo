import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/features/rope/engine/geo.dart';
import 'package:trailseek/features/trails/trail_learner.dart';

/// The true trail: 600 m with a few bends, starting at Athirappilly.
GeoPoint truth(double s) {
  final y = s; // metres north
  final x = 40 * math.sin(s / 60); // bends of ±40 m
  return GeoPoint(10.2850 + y / 111320, 76.5700 + x / (111320 * math.cos(10.285 * math.pi / 180)));
}

/// Someone walking it with GPS error up to [noiseM] (smooth, like real GPS).
Walk walker(String id, {double noiseM = 6, int seed = 1, double from = 0, double to = 600, GeoPoint Function(double s)? path}) {
  final rnd = math.Random(seed);
  final phase = rnd.nextDouble() * 6;
  final pts = <GeoPoint>[];
  for (var s = from; s <= to; s += 4) {
    final p = (path ?? truth)(s);
    final ex = noiseM * math.sin(s / 35 + phase), ey = noiseM * math.cos(s / 50 + phase * 2);
    pts.add(GeoPoint(p.lat + ey / 111320, p.lng + ex / (111320 * math.cos(p.lat * math.pi / 180))));
  }
  return Walk(walkerId: id, points: pts);
}

double distanceToTrue(GeoPoint p) {
  var best = double.infinity;
  for (var s = 0.0; s <= 600; s += 1) {
    best = math.min(best, haversineMetres(p, truth(s)));
  }
  return best;
}

void main() {
  const learner = TrailLearner();

  test('no trail until three different people walked it', () {
    expect(learner.learn([walker('a'), walker('b', seed: 2)]).isEmpty, isTrue);
    // The same person three times is still one walker.
    expect(learner.learn([walker('a'), walker('a', seed: 2), walker('a', seed: 3)]).isEmpty, isTrue);
    expect(learner.learn([walker('a'), walker('b', seed: 2), walker('c', seed: 3)]).isEmpty, isFalse);
  });

  test('the learned line follows the real bends closer than any one GPS track', () {
    final walks = [for (var i = 0; i < 6; i++) walker('w$i', seed: i + 1, noiseM: 8)];
    final trail = learner.learn(walks);
    expect(trail.walkers, 6);
    expect(trail.segments, hasLength(1));
    expect(trail.lengthM, greaterThan(520)); // nearly the whole 600 m (+ bends)
    final errors = [for (final s in trail.segments) for (final p in s) distanceToTrue(p)];
    final mean = errors.reduce((a, b) => a + b) / errors.length;
    expect(mean, lessThan(4)); // single tracks are up to 8 m off
    expect(errors.reduce(math.max), lessThan(8));
  });

  test('one person\'s detour does not become trail', () {
    GeoPoint detour(double s) {
      final p = truth(s);
      final off = s > 250 && s < 400 ? 70.0 : 0.0; // 70 m off to the east
      return GeoPoint(p.lat, p.lng + off / (111320 * math.cos(p.lat * math.pi / 180)));
    }

    final walks = [
      walker('a', seed: 1),
      walker('b', seed: 2),
      walker('c', seed: 3),
      walker('lost', seed: 4, path: detour),
    ];
    final trail = learner.learn(walks);
    for (final s in trail.segments) {
      for (final p in s) {
        expect(distanceToTrue(p), lessThan(10), reason: 'no point on the detour');
      }
    }
  });

  test('only the stretch three people shared is drawn; nothing where only one went', () {
    final walks = [
      walker('a', seed: 1, to: 600),
      walker('b', seed: 2, to: 300),
      walker('c', seed: 3, to: 300),
    ];
    final trail = learner.learn(walks);
    expect(trail.isEmpty, isFalse);
    final ends = [for (final s in trail.segments) ...[s.first, s.last]];
    final northMost = ends.map((p) => (p.lat - 10.2850) * 111320).reduce(math.max);
    expect(northMost, lessThan(320)); // stops where b and c turned back
  });

  test('a branch that three people took is kept as its own piece', () {
    GeoPoint branch(double s) {
      if (s < 300) return truth(s);
      final start = truth(300);
      final along = s - 300;
      return GeoPoint(start.lat, start.lng + along / (111320 * math.cos(start.lat * math.pi / 180))); // heads east
    }

    final walks = [
      for (var i = 0; i < 3; i++) walker('main$i', seed: i + 1),
      for (var i = 0; i < 3; i++) walker('east$i', seed: i + 10, path: branch, to: 550),
    ];
    final trail = learner.learn(walks);
    expect(trail.segments.length, greaterThanOrEqualTo(2));
    final eastMost = [for (final s in trail.segments) ...s].map((p) => p.lng).reduce(math.max);
    expect((eastMost - truth(300).lng) * 111320 * math.cos(10.29 * math.pi / 180), greaterThan(150));
  });

  test('walks and trails survive a JSON round trip', () {
    final w = walker('a');
    final back = Walk.fromJson(w.toJson());
    expect(back.walkerId, 'a');
    expect(back.points.length, w.points.length);
    final t = learner.learn([walker('a'), walker('b', seed: 2), walker('c', seed: 3)]);
    final t2 = LearnedTrail.fromJson(t.toJson());
    expect(t2.walkers, 3);
    expect(t2.segments.length, t.segments.length);
  });
}
