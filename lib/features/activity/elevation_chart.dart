import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Distance on x, altitude on y, neon line with a soft fill. No chart package.
class ElevationChart extends StatelessWidget {
  const ElevationChart({super.key, required this.profile, this.height = 150});

  /// (cumulative metres, altitude metres)
  final List<(double, double)> profile;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (profile.length < 3) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('Not enough altitude data for a profile', style: TsText.caption)),
      );
    }
    final alts = profile.map((e) => e.$2);
    final minA = alts.reduce((a, b) => a < b ? a : b);
    final maxA = alts.reduce((a, b) => a > b ? a : b);
    final totalM = profile.last.$1;
    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${maxA.round()} m', style: TsText.caption.copyWith(fontSize: 10)),
                      Text('${((maxA + minA) / 2).round()} m', style: TsText.caption.copyWith(fontSize: 10)),
                      Text('${minA.round()} m', style: TsText.caption.copyWith(fontSize: 10)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomPaint(
                    painter: _ProfilePainter(profile, minA, maxA),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final f in [0.0, 0.25, 0.5, 0.75, 1.0])
                  Text('${(totalM * f / 1000).toStringAsFixed(totalM < 2000 ? 1 : 0)} km', style: TsText.caption.copyWith(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePainter extends CustomPainter {
  _ProfilePainter(this.profile, this.minA, this.maxA);
  final List<(double, double)> profile;
  final double minA;
  final double maxA;

  @override
  void paint(Canvas canvas, Size size) {
    final total = profile.last.$1 == 0 ? 1.0 : profile.last.$1;
    final span = (maxA - minA) < 10 ? 10.0 : (maxA - minA);
    final mid = (maxA + minA) / 2;
    Offset at((double, double) p) {
      final x = p.$1 / total * size.width;
      final y = size.height - ((p.$2 - (mid - span / 2)) / span) * (size.height - 6) - 3;
      return Offset(x, y);
    }

    final grid = Paint()
      ..color = TsColors.outline
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = 3 + (size.height - 6) * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final line = Path()..moveTo(at(profile.first).dx, at(profile.first).dy);
    for (final p in profile.skip(1)) {
      final o = at(p);
      line.lineTo(o.dx, o.dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [TsColors.neon.withValues(alpha: 0.35), TsColors.neon.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = TsColors.neon
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    final start = at(profile.first);
    final end = at(profile.last);
    canvas.drawCircle(start, 4, Paint()..color = TsColors.neon);
    canvas.drawCircle(end, 4, Paint()..color = TsColors.neon);
    canvas.drawCircle(end, 2, Paint()..color = TsColors.bg);
  }

  @override
  bool shouldRepaint(_ProfilePainter old) => old.profile != profile;
}
