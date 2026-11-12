import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'recorded_route_arrows.dart';

/// Direction of past movement, not live navigation or instructions to walk.
/// All symbols are decorative and pointer-transparent. Do not add to Digital
/// Rope live safety maps where alerts and member positions must take priority.
class RecordedRouteArrowLayer extends StatelessWidget {
  const RecordedRouteArrowLayer({
    super.key,
    required this.points,
  });

  final List<LatLng> points;

  @override
  Widget build(BuildContext context) {
    final arrows = sampleRecordedRouteArrows(points);
    if (arrows.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: MarkerLayer(
        markers: [
          for (final arrow in arrows)
            Marker(
              point: arrow.position,
              width: 24,
              height: 24,
              child: ExcludeSemantics(
                child: Transform.rotate(
                  angle: arrow.bearingDegrees * math.pi / 180,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xDE203D43),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD9F2E6),
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.navigation_rounded,
                        size: 14,
                        color: Color(0xFFBAF7D5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
