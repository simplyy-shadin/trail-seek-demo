import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/features/tracking/track_recorder.dart';

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
    expect(r.distanceM, closeTo(360, 360 * 0.03));
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
    expect(restored.points.length, 200);
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

  test('downsample keeps first and last points', () {
    final r = TrackRecorder();
    for (final p in walk(seconds: 100)) {
      r.add(p);
    }
    final d = r.downsample(4);
    expect(d.first.at, r.points.first.at);
    expect(d.last.at, r.points.last.at);
    expect(d.length, lessThan(r.points.length / 3));
  });
}
