import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/activity_category.dart';
import '../../data/models/activity_record.dart';
import '../rope/engine/geo.dart';

/// 1080×1350 (4:5) card rendered off-screen and shared as a PNG.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.activity, required this.route, required this.initials, this.xp});
  final ActivityRecord activity;
  final List<GeoPoint> route;
  final String initials;
  final int? xp;

  static const width = 1080.0;
  static const height = 1350.0;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final cat = ActivityCategory.fromKey(a.type.name) ?? ActivityCategory.trekking;
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Container(
        width: width,
        height: height,
        color: TsColors.bg,
        child: Stack(
          children: [
            Positioned.fill(child: CoverArt(hue: 140 + a.type.index * 9.0, icon: cat.icon)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [TsColors.bg.withValues(alpha: 0.2), TsColors.bg.withValues(alpha: 0.75), TsColors.bg],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 80,
              right: 80,
              top: 90,
              child: Row(
                children: [
                  AvatarRing(initials: initials, size: 110, ringWidth: 5),
                  const SizedBox(width: 28),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title, style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w900, height: 1.05), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Text(DateFormat('d MMMM yyyy').format(a.startedAt), style: const TextStyle(fontSize: 28, color: TsColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 80,
              right: 80,
              top: 330,
              height: 560,
              child: CustomPaint(painter: _RoutePainter(route)),
            ),
            Positioned(
              left: 80,
              right: 80,
              bottom: 170,
              child: Row(
                children: [
                  _Big('${a.distanceKm.toStringAsFixed(1)} km', 'Distance'),
                  _Big('${a.elevationGainM} m', 'Elevation'),
                  _Big('${a.duration.inHours}h ${(a.duration.inMinutes % 60).toString().padLeft(2, '0')}m', 'Time'),
                  if (xp != null && xp! > 0) _Big('+$xp', 'XP', neon: true),
                ],
              ),
            ),
            Positioned(
              left: 80,
              right: 80,
              bottom: 80,
              child: Row(
                children: [
                  if (a.verified) ...[
                    const Icon(Icons.verified, color: TsColors.neon, size: 34),
                    const SizedBox(width: 10),
                    const Text('GPS-verified', style: TextStyle(fontSize: 26, color: TsColors.textPrimary, fontWeight: FontWeight.w700)),
                  ],
                  const Spacer(),
                  const Text('TRAIL SEEK', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 4, color: TsColors.neon)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big(this.value, this.label, {this.neon = false});
  final String value;
  final String label;
  final bool neon;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 58, fontWeight: FontWeight.w900, color: neon ? TsColors.neon : TsColors.textPrimary)),
          Text(label, style: const TextStyle(fontSize: 24, color: TsColors.textMuted)),
        ],
      ),
    );
  }
}

/// Draws the route fitted into the box, with start/end dots.
class _RoutePainter extends CustomPainter {
  _RoutePainter(this.route);
  final List<GeoPoint> route;

  @override
  void paint(Canvas canvas, Size size) {
    if (route.length < 2) {
      final p = Paint()
        ..color = TsColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(32)), p);
      return;
    }
    var minLat = route.first.lat, maxLat = route.first.lat, minLng = route.first.lng, maxLng = route.first.lng;
    for (final p in route) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }
    final latSpan = (maxLat - minLat).abs() < 1e-6 ? 1e-4 : maxLat - minLat;
    final lngSpan = (maxLng - minLng).abs() < 1e-6 ? 1e-4 : maxLng - minLng;
    const pad = 60.0;
    final scale = ((size.width - pad * 2) / lngSpan).clamp(0, double.infinity) < ((size.height - pad * 2) / latSpan)
        ? (size.width - pad * 2) / lngSpan
        : (size.height - pad * 2) / latSpan;
    final w = lngSpan * scale, h = latSpan * scale;
    final ox = (size.width - w) / 2, oy = (size.height - h) / 2;
    Offset at(GeoPoint p) => Offset(ox + (p.lng - minLng) * scale, oy + (maxLat - p.lat) * scale);

    final path = Path()..moveTo(at(route.first).dx, at(route.first).dy);
    for (final p in route.skip(1)) {
      final o = at(p);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = TsColors.neon.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = TsColors.neon
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(at(route.first), 16, Paint()..color = TsColors.textPrimary);
    canvas.drawCircle(at(route.last), 16, Paint()..color = TsColors.neon);
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.route != route;
}

/// Renders [card] off-screen to PNG bytes.
Future<ui.Image> renderShareCard(ShareCard card, {double pixelRatio = 1}) async {
  final repaint = RenderRepaintBoundary();
  final view = ui.PlatformDispatcher.instance.views.first;
  final pipelineOwner = PipelineOwner();
  final buildOwner = BuildOwner(focusManager: FocusManager());
  final root = RenderView(
    view: view,
    child: RenderPositionedBox(alignment: Alignment.center, child: repaint),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(const Size(ShareCard.width, ShareCard.height)),
      devicePixelRatio: pixelRatio,
    ),
  );
  pipelineOwner.rootNode = root;
  root.prepareInitialFrame();
  final element = RenderObjectToWidgetAdapter<RenderBox>(
    container: repaint,
    child: MediaQuery(data: const MediaQueryData(size: Size(ShareCard.width, ShareCard.height)), child: card),
  ).attachToRenderTree(buildOwner);
  buildOwner.buildScope(element);
  buildOwner.finalizeTree();
  pipelineOwner.flushLayout();
  pipelineOwner.flushCompositingBits();
  pipelineOwner.flushPaint();
  return repaint.toImage(pixelRatio: pixelRatio);
}

/// Renders and hands the PNG to the system share sheet.
Future<void> shareActivityCard(ShareCard card, {required String fileName}) async {
  final image = await renderShareCard(card);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return;
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'image/png')], text: 'Tracked with Trail Seek'));
}
