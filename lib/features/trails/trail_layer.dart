import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'trail_store.dart';

/// The crowd-learned trail as a dashed white line under everything else.
/// Draws nothing at all when nobody has walked this adventure enough yet.
class LearnedTrailLayer extends ConsumerWidget {
  const LearnedTrailLayer({super.key, required this.adventureId});
  final String adventureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trail = ref.watch(learnedTrailProvider(adventureId));
    if (trail.isEmpty) return const SizedBox.shrink();
    return PolylineLayer(
      polylines: [
        for (final s in trail.segments)
          Polyline(
            points: [for (final p in s) LatLng(p.lat, p.lng)],
            strokeWidth: 4,
            color: Colors.white.withValues(alpha: 0.9),
            borderStrokeWidth: 2,
            borderColor: Colors.black.withValues(alpha: 0.45),
            pattern: StrokePattern.dashed(segments: const [14, 9]),
            strokeCap: StrokeCap.round,
          ),
      ],
    );
  }
}
