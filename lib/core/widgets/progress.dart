import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Level label on the left, "520 / 1,000 XP" on the right, thin neon bar below.
class XpBar extends StatelessWidget {
  const XpBar({
    super.key,
    required this.level,
    required this.xpInLevel,
    required this.xpForLevel,
    this.showLabels = true,
    this.height = 8,
  });

  final int level;
  final int xpInLevel;
  final int xpForLevel;
  final bool showLabels;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fraction = xpForLevel <= 0 ? 1.0 : (xpInLevel / xpForLevel).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLabels)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Text('Level $level', style: TsText.bodyStrong),
                const Spacer(),
                Text('${_fmt(xpInLevel)} / ${_fmt(xpForLevel)} XP', style: TsText.caption),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: Stack(
            children: [
              Container(height: height, color: TsColors.surfaceHigh),
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                widthFactor: fraction,
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [TsColors.neonDeep, TsColors.neon]),
                    borderRadius: BorderRadius.circular(height),
                    boxShadow: [BoxShadow(color: TsColors.neon.withValues(alpha: 0.45), blurRadius: 8)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _fmt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      b.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) b.write(',');
    }
    return b.toString();
  }
}

/// Shield icon + "Level 3" pill.
class LevelChip extends StatelessWidget {
  const LevelChip({super.key, required this.level, this.compact = false});
  final int level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 4 : 7),
      decoration: BoxDecoration(
        color: TsColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TsColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield, size: 14, color: TsColors.neon),
          const SizedBox(width: 6),
          Text(compact ? 'Lv $level' : 'Level $level', style: TsText.label.copyWith(color: TsColors.textPrimary)),
        ],
      ),
    );
  }
}

/// Hexagonal badge tile: neon outline when unlocked, dim with a lock when locked.
class HexBadge extends StatelessWidget {
  const HexBadge({
    super.key,
    required this.icon,
    required this.label,
    this.unlocked = true,
    this.size = 64,
    this.onTap,
    this.accent,
  });

  final IconData icon;
  final String label;
  final bool unlocked;
  final double size;
  final VoidCallback? onTap;

  /// Optional per-badge colour; falls back to neon.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? (accent ?? TsColors.neon) : TsColors.outline;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            painter: _HexPainter(stroke: color, fill: unlocked ? color.withValues(alpha: 0.12) : TsColors.surface),
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: Icon(unlocked ? icon : Icons.lock_outline, size: size * 0.4, color: unlocked ? color : TsColors.textMuted),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: size + 24,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, height: 1.2, color: unlocked ? TsColors.textPrimary : TsColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  _HexPainter({required this.stroke, required this.fill});
  final Color stroke;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final path = hexagonPath(size, inset: 1.5);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(path, Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_HexPainter old) => old.stroke != stroke || old.fill != fill;
}

/// Pointy-top hexagon inscribed in [size].
Path hexagonPath(Size size, {double inset = 0}) {
  final w = size.width - inset * 2;
  final h = size.height - inset * 2;
  final cx = size.width / 2;
  final cy = size.height / 2;
  final r = (w < h ? w : h) / 2;
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final angle = (60 * i - 90) * 3.141592653589793 / 180;
    final x = cx + r * _cos(angle);
    final y = cy + r * _sin(angle);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  return path;
}

double _cos(double a) => _series(a, true);
double _sin(double a) => _series(a, false);

// Tiny Taylor approximations keep this file free of dart:math for const-ness elsewhere.
double _series(double a, bool cos) {
  // Normalise to [-pi, pi].
  const pi = 3.141592653589793;
  a = a % (2 * pi);
  if (a > pi) a -= 2 * pi;
  if (a < -pi) a += 2 * pi;
  double term = cos ? 1 : a;
  double sum = term;
  final a2 = a * a;
  for (var n = 1; n < 10; n++) {
    final k = cos ? (2 * n - 1) * (2 * n) : (2 * n) * (2 * n + 1);
    term *= -a2 / k;
    sum += term;
  }
  return sum;
}
