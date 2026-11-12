import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'recorded_route_arrows.dart';

/// Direction of past movement, not live navigation or instructions to walk.
/// All symbols are decorative and pointer-transparent. Do not add to Digital
/// Rope live safety maps where alerts and member positions must take priority.
class RecordedRouteArrowLayer extends StatefulWidget {
  const RecordedRouteArrowLayer({
    super.key,
    required this.points,
  });

  final List<LatLng> points;

  @override
  State<RecordedRouteArrowLayer> createState() =>
      _RecordedRouteArrowLayerState();
}

class _RecordedRouteArrowLayerState extends State<RecordedRouteArrowLayer> {
  late List<RecordedRouteArrow> _arrows;

  @override
  void initState() {
    super.initState();
    _arrows = sampleRecordedRouteArrows(widget.points);
  }

  @override
  void didUpdateWidget(covariant RecordedRouteArrowLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Solo Tracking ticks once a second; only rebuild geometry when the
    // accepted route *list reference* changes, not every elapsed-time tick.
    if (!identical(oldWidget.points, widget.points)) {
      _arrows = sampleRecordedRouteArrows(widget.points);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_arrows.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: MarkerLayer(
        markers: [
          for (final arrow in _arrows)
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
