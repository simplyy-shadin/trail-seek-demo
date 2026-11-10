import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/features/tracking/track_recorder.dart';
import 'package:trailseek/features/rope/engine/geo.dart';

/// Straight-line walk north at [speed] m/s with [climb] m total gain.
List<TrackPoint> walk({int seconds = 600, double speed = 1.2, double climb = 120, double accuracy = 8}) {
  final start = DateTime(2026, 4, 12, 6);
  const lat0 = 11.50;
  return [
    for (var i = 0; i <= seconds; i++)
      TrackPoint(
        lat: lat0 + (speed * i) / 111320,
        lng: 76.09,
        at: start.add(Duration(seconds: i)),
        altitudeM: 900 + climb * i / seconds + math.sin(i / 3) * 0.8,
        accuracyM: accuracy,
        speedMps: speed,
      ),
  ];
}

void main() {
  test('distance and gain match a clean synthetic walk', () {
    final r = TrackRecorder();
    for (final p in walk()) {
      r.add(p);
    }
    expect(r.distanceM, closeTo(720, 720 * 0.02));
    expect(r.gainM, closeTo(120, 12));
    expect(r.movingTime.inSeconds, closeTo(600, 5));
    expect(r.maxAltitudeM, closeTo(1020, 3));
    expect(r.verified, isTrue);
    expect(r.rejected, 0);
  });

  test('poor-accuracy fixes and teleports are rejected', () {
    final r = TrackRecorder();
    final pts = walk(seconds: 300);
    for (var i = 0; i < pts.length; i++) {
      var p = pts[i];
      if (i % 50 == 25) p = TrackPoint(lat: p.lat, lng: p.lng, at: p.at, altitudeM: p.altitudeM, accuracyM: 60);
      if (i == 150) p = TrackPoint(lat: p.lat + 0.01, lng: p.lng, at: p.at, altitudeM: p.altitudeM, accuracyM: 5);
      r.add(p);
    }
    expect(r.rejected, 7);
    expect(r.distanceM, closeTo(360, 360 * 0.05));
    expect(r.accuracyRatio, greaterThan(0.95));
  });

  test('altitude jitter does not inflate gain', () {
    final r = TrackRecorder();
    final start = DateTime(2026, 4, 12, 6);
    for (var i = 0; i < 300; i++) {
      r.add(TrackPoint(lat: 11.5 + i * 1e-5, lng: 76.09, at: start.add(Duration(seconds: i)), altitudeM: 900 + math.sin(i.toDouble()) * 2, accuracyM: 6));
    }
    expect(r.gainM, lessThanOrEqualTo(4));
  });

  test('a short stroll is not verified', () {
    final r = TrackRecorder();
    for (final p in walk(seconds: 200)) {
      r.add(p);
    }
    expect(r.distanceM, lessThan(500));
    expect(r.verified, isFalse);
  });

  test('snapshot round-trips and keeps counting', () {
    final r = TrackRecorder();
    final pts = walk(seconds: 400);
    for (final p in pts.take(200)) {
      r.add(p);
    }
    final restored = TrackRecorder.fromJson(r.toJson());
    expect(restored.distanceM, r.distanceM);
    expect(restored.points.length, r.points.length);
    expect(restored.points.length, lessThan(200));
    for (final p in pts.skip(200)) {
      restored.add(p);
    }
    final straight = TrackRecorder();
    for (final p in pts) {
      straight.add(p);
    }
    // Coordinates are stored to 6 decimals (~0.1 m), so allow sub-metre drift.
    expect(restored.distanceM, closeTo(straight.distanceM, 0.5));
    expect(restored.gainM, straight.gainM);
  });

  test('stationary indoor jitter does not create distance or route', () {
    final r = TrackRecorder();
    final start = DateTime.utc(2026, 11, 4, 10);
    for (var i = 0; i < 120; i++) {
      final jitterLat = math.sin(i * 1.7) * 0.00010;
      final jitterLng = math.cos(i * 1.1) * 0.00009;
      r.add(TrackPoint(
        lat: 10.28 + jitterLat,
        lng: 76.57 + jitterLng,
        at: start.add(Duration(seconds: i)),
        altitudeM: 240 + math.sin(i * 0.4) * 4,
        accuracyM: 20,
        speedMps: 0,
      ));
    }
    expect(r.distanceM, 0);
    expect(r.gainM, 0);
    expect(r.points.length, 1);
    expect(r.accuracyRatio, greaterThan(0.98));
    expect(r.ignored, greaterThan(0));
  });

  test('movement resumes after indoor stationary fixes', () {
    final r = TrackRecorder();
    final start = DateTime.utc(2026, 11, 4, 10);
    for (var i = 0; i < 60; i++) {
      r.add(TrackPoint(
        lat: 10.28 + math.sin(i.toDouble()) * 0.00005,
        lng: 76.57,
        at: start.add(Duration(seconds: i)),
        accuracyM: 15,
        speedMps: 0,
      ));
    }
    for (var i = 1; i <= 200; i++) {
      r.add(TrackPoint(
        lat: 10.28 + i * 1.2 / 111320,
        lng: 76.57,
        at: start.add(Duration(seconds: 59 + i)),
        accuracyM: 6,
        speedMps: 1.2,
      ));
    }
    expect(r.distanceM, greaterThan(210));
    expect(r.distanceM, lessThan(270));
  });

  test('downsample keeps first and last points', () {
    final r = TrackRecorder();
    for (final p in walk(seconds: 100)) {
      r.add(p);
    }
    final d = r.downsample(4);
    expect(d.first.at, r.points.first.at);
    expect(d.last.at, r.points.last.at);
    expect(d.length, lessThanOrEqualTo(r.points.length / 3 + 1));
  });

  test('small turns stay in the line while walking under poor sky (FitzTrack spacing)', () {
    // A switchback trail: 8 legs of 12 m, alternating east and north-west,
    // walked at 1.2 m/s with 15 m GPS accuracy (typical under trees).
    final r = TrackRecorder();
    final start = DateTime.utc(2026, 11, 8, 6);
    var lat = 10.3, lng = 76.5;
    var t = 0;
    final corners = <({double lat, double lng})>[];
    for (var leg = 0; leg < 8; leg++) {
      final (dLat, dLng) = leg.isEven ? (0.0, 0.000011) : (0.000008, -0.000008); // ~1.2 m per second
      for (var s = 0; s < 10; s++) {
        lat += dLat;
        lng += dLng;
        r.add(TrackPoint(lat: lat, lng: lng, at: start.add(Duration(seconds: t++)), accuracyM: 15, speedMps: 1.2));
      }
      corners.add((lat: lat, lng: lng));
    }
    // Every corner has a recorded point within 6 m: the zigzag is kept.
    for (final c in corners.take(7)) {
      final nearest = r.points.map((p) => haversineMetres(p.geo, GeoPoint(c.lat, c.lng))).reduce((a, b) => math.min(a, b));
      expect(nearest, lessThan(6));
    }
    expect(r.points.length, greaterThanOrEqualTo(8));
  });

  test('a bad anchor is dropped after five impossible jumps in a row', () {
    final r = TrackRecorder();
    final start = DateTime.utc(2026, 11, 8, 6);
    // First fix is a cell-tower guess 2 km away; the real walk starts after.
    r.add(TrackPoint(lat: 10.32, lng: 76.5, at: start, accuracyM: 25));
    for (var i = 1; i < 60; i++) {
      r.add(TrackPoint(lat: 10.3 + i * 0.00005, lng: 76.5, at: start.add(Duration(seconds: i * 4)), accuracyM: 6, speedMps: 1.4));
    }
    expect(r.points.last.lat, closeTo(10.3 + 59 * 0.00005, 1e-9));
    expect(r.distanceM, lessThan(400)); // the 2 km jump is not walked distance
    expect(r.distanceM, greaterThan(250));
  });
  test('good fixes preserve small C-turn corners without extra GPS polling', () {
    final r = TrackRecorder();
    final at = DateTime.utc(2026, 11, 10, 12);
    // 2.7m east then 2.7m north, repeated. A fixed 5m floor can skip
    // the bend; a quality-aware floor keeps both legs if accuracy is good.
    final coords = [
      const GeoPoint(10.30, 76.50),
      const GeoPoint(10.30, 76.500025),
      const GeoPoint(10.300025, 76.500025),
      const GeoPoint(10.300025, 76.500050),
      const GeoPoint(10.300050, 76.500050),
    ];
    for (var i = 0; i < coords.length; i++) {
      r.add(TrackPoint(lat: coords[i].lat, lng: coords[i].lng,
          at: at.add(Duration(seconds: i * 3)), accuracyM: 3, speedMps: 1));
    }
    expect(r.points.length, coords.length);
    expect(r.distanceM, greaterThan(10));
  });

  test('no extra tiny steps under poor canopy accuracy', () {
    final r = TrackRecorder();
    final at = DateTime.utc(2026, 11, 10, 12);
    expect(r.add(TrackPoint(lat: 10.3, lng: 76.5, at: at,
        accuracyM: 15, speedMps: 1)), isTrue);
    expect(r.add(TrackPoint(lat: 10.3, lng: 76.500025,
        at: at.add(const Duration(seconds: 3)),
        accuracyM: 15, speedMps: 1)), isFalse);
    expect(r.points.length, 1);
  });

}
