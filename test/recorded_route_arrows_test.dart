import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trailseek/features/maps/recorded_route_arrows.dart';

void main() {
  test('sampled arrows follow the bearing of a recorded northbound walk', () {
    final result = sampleRecordedRouteArrows(
      const [LatLng(10.0, 76.0), LatLng(10.005, 76.0)],
      preferredSpacingMetres: 150,
    );
    expect(result.length, 3);
    for (final arrow in result) {
      expect(arrow.bearingDegrees, closeTo(0, 1));
      expect(arrow.position.longitude, closeTo(76, 0.000001));
      expect(arrow.position.latitude, inInclusiveRange(10, 10.005));
    }
  });

  test('eastbound path produces approximately 90-degree compass bearings', () {
    final result = sampleRecordedRouteArrows(
      const [LatLng(10.0, 76.0), LatLng(10.0, 76.005)],
      preferredSpacingMetres: 150,
    );
    expect(result, isNotEmpty);
    expect(result.first.bearingDegrees, closeTo(90, 1));
  });

  test('tiny routes, duplicates and invalid coordinates create no arrows', () {
    expect(sampleRecordedRouteArrows(const []), isEmpty);
    expect(sampleRecordedRouteArrows(const [LatLng(10.0, 76.0)]), isEmpty);
    expect(sampleRecordedRouteArrows(const [
      LatLng(10.0, 76.0),
      LatLng(10.0, 76.0),
      LatLng(10.0001, 76.0001),
    ]), isEmpty);
    expect(sampleRecordedRouteArrows(const [
      LatLng(91, 76),
      LatLng(10, 76),
    ]), isEmpty);
  });

  test('large GPS gaps and longitude dateline jumps do not create guidance', () {
    expect(sampleRecordedRouteArrows(const [
      LatLng(10, 76),
      LatLng(11, 76),
    ]), isEmpty);
    expect(sampleRecordedRouteArrows(const [
      LatLng(10, 179.9),
      LatLng(10, -179.9),
    ]), isEmpty);
  });

  test('long routes auto-space arrows and strictly cap marker count', () {
    final route = <LatLng>[
      for (var i = 0; i <= 150; i++) LatLng(10 + i * 0.0009, 76),
    ];
    final result = sampleRecordedRouteArrows(
      route,
      preferredSpacingMetres: 75,
      maxArrows: 12,
    );
    expect(result, hasLength(12));
    expect(result.last.position.latitude, greaterThan(10.11));
  });

  test('bad sampling parameters safely produce no arrows', () {
    final path = [const LatLng(10, 76), const LatLng(10.01, 76)];
    expect(sampleRecordedRouteArrows(path, maxArrows: 0), isEmpty);
    expect(sampleRecordedRouteArrows(path, preferredSpacingMetres: -1), isEmpty);
    expect(sampleRecordedRouteArrows(path, maxSegmentMetres: -1), isEmpty);
  });
}
