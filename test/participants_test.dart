import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/features/rope/engine/geo.dart';
import 'package:trailseek/features/rope/engine/rope_models.dart';
import 'package:trailseek/features/rope/participant_distance.dart';
import 'package:trailseek/features/rope/participants_sheet.dart';

void main() {
  final now = DateTime(2026, 4, 12, 8);
  const guide = GeoPoint(11.5000, 76.0900);
  const near = GeoPoint(11.5020, 76.0900); // ~220 m
  const far = GeoPoint(11.5300, 76.0900); // ~3.3 km

  test('distance shows only when both GPS fixes are fresh', () {
    expect(coarseDistance(a: guide, aAt: now, b: near, bAt: now, now: now), '< 500 m');
    expect(coarseDistance(a: guide, aAt: now, b: far, bAt: now, now: now), '~3 km');
    expect(coarseDistance(a: guide, aAt: now.subtract(const Duration(minutes: 2)), b: near, bAt: now, now: now), isNull);
    expect(coarseDistance(a: guide, aAt: now, b: null, bAt: null, now: now), isNull);
  });

  test('imperial formatting', () {
    expect(coarseDistance(a: guide, aAt: now, b: near, bAt: now, now: now, metric: false), '< 0.3 mi');
    expect(coarseDistance(a: guide, aAt: now, b: far, bAt: now, now: now, metric: false), '~2 mi');
  });

  test('Online covers connected and weak; everything alerting is Offline', () {
    expect(isOnline(RopeState.connected), isTrue);
    expect(isOnline(RopeState.weak), isTrue);
    expect(isOnline(RopeState.fallingBehind), isFalse);
    expect(isOnline(RopeState.separated), isFalse);
    expect(isOnline(RopeState.critical), isFalse);
  });
}
