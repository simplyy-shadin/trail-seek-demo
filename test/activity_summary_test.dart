import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/data/models/activity_record.dart';
import 'package:trailseek/features/activity/elevation_chart.dart';
import 'package:trailseek/features/activity/share_card.dart';
import 'package:trailseek/features/activity/track_store.dart';
import 'package:trailseek/features/rope/engine/geo.dart';
import 'package:trailseek/features/tracking/track_recorder.dart';

void main() {
  final start = DateTime(2026, 4, 12, 6, 32);
  final points = [
    for (var i = 0; i <= 50; i++)
      TrackPoint(lat: 10.13 + i * 0.0005, lng: 77.23 + i * 0.0003, at: start.add(Duration(minutes: i * 4)), altitudeM: 1900 + i * 14.0, accuracyM: 6),
  ];
  final record = ActivityRecord(
    id: 'a1',
    type: ActivityType.trekking,
    title: 'Meesapulimala Trek',
    startedAt: start,
    endedAt: start.add(const Duration(hours: 3, minutes: 25)),
    distanceM: 8600,
    elevationGainM: 720,
    maxAltitudeM: 2640,
    verified: true,
  );

  test('TrackData distance matches the engine haversine', () {
    final data = TrackData(points: points, movingTime: const Duration(hours: 3), accuracyRatio: 1);
    final profile = data.elevationProfile();
    var expected = 0.0;
    for (var i = 1; i < points.length; i++) {
      expected += haversineMetres(points[i - 1].geo, points[i].geo);
    }
    expect(profile.length, points.length);
    expect(profile.last.$1, closeTo(expected, expected * 0.001));
    expect(profile.first.$2, 1900);
    expect(profile.last.$2, 2600);
    expect(data.hasRoute, isTrue);
    expect(data.hasElevation, isTrue);
  });

  test('TrackData round-trips through JSON', () {
    final data = TrackData(points: points, movingTime: const Duration(minutes: 90), accuracyRatio: 0.93);
    final back = TrackData.fromJson(data.toJson());
    expect(back.points.length, 51);
    expect(back.movingTime, const Duration(minutes: 90));
    expect(back.accuracyRatio, 0.93);
  });

  testWidgets('elevation chart copes with flat and tiny profiles', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevationChart(profile: [(0, 900), (500, 900), (1000, 900)]),
            ElevationChart(profile: [(0, 900)]),
            ElevationChart(profile: []),
          ],
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('Not enough altitude data for a profile'), findsNWidgets(2));
  });

  testWidgets('share card renders to a 1080×1350 image', (tester) async {
    ui.Image? image;
    await tester.runAsync(() async {
      image = await renderShareCard(ShareCard(activity: record, route: points.map((p) => p.geo).toList(), initials: 'FF', xp: 272));
    });
    expect(image, isNotNull);
    expect(image!.width, 1080);
    expect(image!.height, 1350);
  });

  testWidgets('share card with no route still renders', (tester) async {
    ui.Image? image;
    await tester.runAsync(() async {
      image = await renderShareCard(ShareCard(activity: record, route: const [], initials: 'FF'));
    });
    expect(image?.width, 1080);
  });
}
