import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trailseek/app/providers.dart';
import 'package:trailseek/data/repositories/local_store.dart';
import 'package:trailseek/features/rope/engine/geo.dart';
import 'package:trailseek/features/trails/trail_learner.dart';
import 'package:trailseek/features/trails/trail_store.dart';

Walk walk(String id, int seed) {
  final pts = <GeoPoint>[];
  for (var s = 0.0; s <= 400; s += 3) {
    final n = 5 * math.sin(s / 30 + seed);
    pts.add(GeoPoint(10.285 + s / 111320, 76.57 + (30 * math.sin(s / 50) + n) / 109500));
  }
  return Walk(walkerId: id, at: DateTime(2026, 11, seed), points: pts);
}

void main() {
  late ProviderContainer c;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    c = ProviderContainer(overrides: [localStoreProvider.overrideWithValue(LocalStore(prefs))]);
  });
  tearDown(() => c.dispose());

  test('no line until the third walker; then every screen sees the trail', () async {
    final store = c.read(trailStoreProvider.notifier);
    expect(c.read(learnedTrailProvider('adv-1')).isEmpty, isTrue);
    await store.addWalks('adv-1', [walk('a', 1), walk('b', 2)]);
    expect(c.read(learnedTrailProvider('adv-1')).isEmpty, isTrue, reason: 'two walkers are not a trail');
    await store.addWalks('adv-1', [walk('c', 3)]);
    final trail = c.read(learnedTrailProvider('adv-1'));
    expect(trail.walkers, 3);
    expect(trail.lengthM, greaterThan(300));
    expect(c.read(learnedTrailProvider('adv-2')).isEmpty, isTrue, reason: 'other adventures stay empty');
    // Saving the same walk again does not count twice.
    await store.addWalks('adv-1', [walk('c', 3)]);
    expect(store.walks('adv-1'), hasLength(3));
  });

  test('uploaded walks lose their first and last 50 m; walker keys hide who', () {
    final pts = [for (var i = 0; i <= 40; i++) GeoPoint(10.285 + i * 10 / 111320, 76.57)]; // 400 m north
    final cut = TrailStore.trimEnds(pts, 50);
    expect(haversineMetres(pts.first, cut.first), greaterThanOrEqualTo(50));
    expect(haversineMetres(pts.last, cut.last), greaterThanOrEqualTo(50));
    expect(TrailStore.trimEnds(pts.take(8).toList(), 50), isEmpty); // too short to share
    final key = TrailStore.walkerKey('user-123');
    expect(key, TrailStore.walkerKey('user-123'));
    expect(key, isNot(contains('user')));
    expect(key, hasLength(16));
  });
}
