import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'fog_of_war_controller.dart';

/// Optional visual game layer; drawn after the basemap but underneath routes,
/// markers and safety buttons. Does not intercept any taps.
class FogOfWarLayer extends ConsumerWidget {
  const FogOfWarLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fog = ref.watch(fogOfWarProvider);
    if (!fog.enabled) return const SizedBox.shrink();

    // MapCamera.of registers for camera movements to keep holes aligned
    // with geographic coordinates when panning, rotating and zooming.
    final camera = MapCamera.of(context);
    final visible = <LatLng>[];
    final bounds = camera.visibleBounds;
    for (final key in fog.revealed) {
      final cell = FogCell.fromKey(key);
      if (cell == null) continue;
      final latLng = LatLng(cell.latitude, cell.longitude);
      if (bounds.contains(latLng)) visible.add(latLng);
    }

    return IgnorePointer(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _FogPainter(camera: camera, visited: visible),
          isComplex: true,
          willChange: true,
        ),
      ),
    );
  }
}

class _FogPainter extends CustomPainter {
  const _FogPainter({required this.camera, required this.visited});

  final MapCamera camera;
  final List<LatLng> visited;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final fog = Path()..fillType = PathFillType.evenOdd;
    fog.addRect(Offset.zero & size);

    for (final location in visited) {
      final center = camera.latLngToScreenOffset(location);
      // Reveal approximately 100 m around an accepted walk point.
      // Screen-projected radius makes fog stay fixed to geography.
      final edge = camera.latLngToScreenOffset(
        LatLng(location.latitude + 0.0009, location.longitude),
      );
      final radius = (edge - center).distance;
      if (!radius.isFinite || radius <= 0 ||
          center.dx < -radius || center.dy < -radius ||
          center.dx > size.width + radius ||
          center.dy > size.height + radius) continue;
      fog.addOval(Rect.fromCircle(center: center, radius: radius));
    }

    canvas.drawPath(
      fog,
      Paint()..color = const Color(0xB9162234),
    );
  }

  @override
  bool shouldRepaint(covariant _FogPainter oldDelegate) =>
      oldDelegate.camera != camera || oldDelegate.visited != visited;
}
