import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// A small, decorative direction indicator along an *already recorded* route.
/// This never represents live turn-by-turn guidance or an authorised trail.
class RecordedRouteArrow {
  const RecordedRouteArrow({
    required this.position,
    required this.bearingDegrees,
  });

  final LatLng position;
  final double bearingDegrees;
}

class _RecordedSegment {
  const _RecordedSegment(this.from, this.to, this.metres, this.bearingDegrees);

  final LatLng from, to;
  final double metres, bearingDegrees;
}

bool _validLocation(LatLng value) =>
    value.latitude.isFinite &&
    value.longitude.isFinite &&
    value.latitude.abs() <= 85 &&
    value.longitude.abs() <= 180;

double _radians(double value) => value * math.pi / 180;

double _segmentMetres(LatLng from, LatLng to) {
  final latDelta = _radians(to.latitude - from.latitude);
  final lngDelta = _radians(to.longitude - from.longitude);
  final x = math.sin(latDelta / 2) * math.sin(latDelta / 2) +
      math.cos(_radians(from.latitude)) *
          math.cos(_radians(to.latitude)) *
          math.sin(lngDelta / 2) *
          math.sin(lngDelta / 2);
  return 2 * 6371000.0 * math.asin(math.min(1.0, math.sqrt(x)));
}

/// Compass degrees clockwise from north, not from screen/map rotation.
double recordedRouteBearingDegrees(LatLng from, LatLng to) {
  final phi1 = _radians(from.latitude);
  final phi2 = _radians(to.latitude);
  final dl = _radians(to.longitude - from.longitude);
  final y = math.sin(dl) * math.cos(phi2);
  final x = math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(dl);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// Samples arrows at roughly even travelled distances. For very long routes,
/// spacing automatically increases so widget and memory costs stay bounded.
/// Ignores missing/invalid points, duplicates and implausibly long *single*
/// segments instead of inventing direction across gaps/teleports.
List<RecordedRouteArrow> sampleRecordedRouteArrows(
  List<LatLng> route, {
  double preferredSpacingMetres = 150,
  int maxArrows = 24,
  double maxSegmentMetres = 2000,
}) {
  if (route.length < 2 ||
      maxArrows <= 0 ||
      !preferredSpacingMetres.isFinite ||
      preferredSpacingMetres <= 0 ||
      !maxSegmentMetres.isFinite ||
      maxSegmentMetres <= 0) {
    return const [];
  }

  final segments = <_RecordedSegment>[];
  var totalMetres = 0.0;
  for (var i = 1; i < route.length; i++) {
    final from = route[i - 1];
    final to = route[i];
    if (!_validLocation(from) || !_validLocation(to) ||
        (to.longitude - from.longitude).abs() > 180) continue;
    final metres = _segmentMetres(from, to);
    if (!metres.isFinite || metres < 1 || metres > maxSegmentMetres) continue;
    segments.add(_RecordedSegment(
      from,
      to,
      metres,
      recordedRouteBearingDegrees(from, to),
    ));
    totalMetres += metres;
  }
  if (segments.isEmpty) return const [];

  final interval = math.max(preferredSpacingMetres, totalMetres / (maxArrows + 1));
  var nextDistance = interval;
  var distanceWalked = 0.0;
  final result = <RecordedRouteArrow>[];
  for (final segment in segments) {
    while (nextDistance <= distanceWalked + segment.metres &&
        result.length < maxArrows) {
      final fraction =
          ((nextDistance - distanceWalked) / segment.metres).clamp(0.0, 1.0);
      result.add(RecordedRouteArrow(
        position: LatLng(
          segment.from.latitude +
              (segment.to.latitude - segment.from.latitude) * fraction,
          segment.from.longitude +
              (segment.to.longitude - segment.from.longitude) * fraction,
        ),
        bearingDegrees: segment.bearingDegrees,
      ));
      nextDistance += interval;
    }
    if (result.length >= maxArrows) break;
    distanceWalked += segment.metres;
  }
  return result;
}
