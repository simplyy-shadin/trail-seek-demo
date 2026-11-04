import 'dart:math' as math;


import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models/avatar.dart';
import '../../features/avatar/avatar_files.dart';

/// Procedural layered avatar. Same layer API an illustrated set will use
/// (body → outfit → hair → accessory), drawn with paths for now so the
/// app ships without art assets. Renders crisply from 24 px to 300 px.
class AvatarView extends StatelessWidget {
  const AvatarView({super.key, required this.avatar, this.size = 96, this.background, this.avatarId});
  final Avatar avatar;
  final double size;
  final Color? background;

  /// When this is an `img:` id with a file on disk, the generated portrait is
  /// shown instead of the procedural drawing.
  final String? avatarId;

  /// Convenience: build from an id string (procedural or image).
  factory AvatarView.fromId(String? id, {Key? key, double size = 96, Color? background}) =>
      AvatarView(key: key, avatar: Avatar.decode(id), avatarId: id, size: size, background: background);

  static const skinTones = [
    Color(0xFFF1C9A5), Color(0xFFE0AC7E), Color(0xFFC68B59), Color(0xFFA86B3C),
    Color(0xFF8D5524), Color(0xFF6B3F1E), Color(0xFFD9A98C), Color(0xFFB07A55),
  ];
  static const hairColors = [
    Color(0xFF1B1B1B), Color(0xFF4A2C17), Color(0xFF7A4B2A), Color(0xFFB98A5B),
    Color(0xFF8A8A8A), Color(0xFFC94F2E),
  ];
  static const outfitColors = [
    (Color(0xFF2F6F3E), Color(0xFF9DFF1E)), // Trail Jacket: green + neon trims
    (Color(0xFF1E3A5F), Color(0xFFFF8A3D)), // Summit Shell: navy + orange
    (Color(0xFF3B3B3B), Color(0xFF9DFF1E)), // Forest Tee: charcoal + neon
    (Color(0xFF6B3F1E), Color(0xFFFFC53D)), // River Vest: brown + amber
  ];

  @override
  Widget build(BuildContext context) {
    // Old drawn avatars (v1:… codes) are shown as the matching 3D face.
    // Old drawn avatars (v1:…) and old cartoon renders (img:<uuid>.png from the
    // removed cartoon generator) show as a realistic character instead.
    // Real photos are saved as .jpg and are left alone.
    final raw = avatarId;
    final legacy = raw == null || raw.startsWith('v1:') || (raw.startsWith('img:') && raw.endsWith('.png'));
    var id = legacy ? _characterFor(avatar, raw) : raw;
    // Character avatars (char:<who>) show the portrait cropped from the render.
    if (id.startsWith('char:')) {
      final p = id.split(':');
      if (p.length >= 2) id = 'asset:assets/images/characters/${p[1]}_face.jpg';
    }
    // Photo and 3D avatars: bundled assets (asset:) and uploaded photos (https:).
    if (id.startsWith('asset:') || id.startsWith('http')) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: id.startsWith('asset:')
              ? Image.asset(id.substring(6), fit: BoxFit.cover, width: size, height: size, errorBuilder: (_, _, _) => CustomPaint(painter: _AvatarPainter(avatar)))
              : Image.network(id, fit: BoxFit.cover, width: size, height: size, errorBuilder: (_, _, _) => CustomPaint(painter: _AvatarPainter(avatar))),
        ),
      );
    }
    final file = AvatarFiles.fileFor(avatarId);
    final hasImage = file != null && file.existsSync();
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: background ?? TsColors.surfaceHigh,
        child: hasImage
            ? Image.file(file, fit: BoxFit.cover, width: size, height: size, gaplessPlayback: true, errorBuilder: (_, _, _) => CustomPaint(painter: _AvatarPainter(avatar)))
            : CustomPaint(painter: _AvatarPainter(avatar)),
      ),
    );
  }
}

const _characters = ['arav', 'kiran', 'rohan', 'faisal', 'joseph', 'dev', 'ananya', 'meera', 'sara', 'ayesha', 'lakshmi', 'nila'];

/// Deterministic character for a legacy procedural avatar code.
String _characterFor(Avatar a, String? raw) {
  final n = raw != null && raw.startsWith('img:') ? raw.codeUnits.fold(0, (s, c) => s + c) : a.hairStyle * 5 + a.hairColor + a.outfit * 3 + a.accessory + a.base;
  return 'char:${_characters[n % _characters.length]}';
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.a);
  final Avatar a;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2;
    final skin = AvatarView.skinTones[a.base % AvatarView.skinTones.length];
    final hair = AvatarView.hairColors[a.hairColor % AvatarView.hairColors.length];
    final (outfit, trim) = AvatarView.outfitColors[a.outfit % AvatarView.outfitColors.length];
    final broad = a.base.isOdd; // alternate builds

    // Backpack straps/bag sit behind the body.
    if (a.accessory == 3) {
      final bag = Paint()..color = const Color(0xFF3A2A1A);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - s * 0.30, s * 0.56, s * 0.60, s * 0.36), Radius.circular(s * 0.12)), bag);
    }

    // Body / outfit
    final bodyTop = s * 0.62;
    final body = Path()
      ..moveTo(cx - s * (broad ? 0.34 : 0.28), s)
      ..quadraticBezierTo(cx - s * (broad ? 0.36 : 0.30), bodyTop + s * 0.05, cx - s * 0.16, bodyTop)
      ..lineTo(cx + s * 0.16, bodyTop)
      ..quadraticBezierTo(cx + s * (broad ? 0.36 : 0.30), bodyTop + s * 0.05, cx + s * (broad ? 0.34 : 0.28), s)
      ..close();
    canvas.drawPath(body, Paint()..color = outfit);
    // Trim: zipper / collar line
    canvas.drawLine(Offset(cx, bodyTop + s * 0.04), Offset(cx, s), Paint()
      ..color = trim
      ..strokeWidth = s * 0.02);
    if (a.outfit == 3) {
      // vest: lighter panels
      canvas.drawRect(Rect.fromLTWH(cx - s * 0.14, bodyTop + s * 0.08, s * 0.10, s * 0.3), Paint()..color = trim.withValues(alpha: 0.35));
      canvas.drawRect(Rect.fromLTWH(cx + s * 0.04, bodyTop + s * 0.08, s * 0.10, s * 0.3), Paint()..color = trim.withValues(alpha: 0.35));
    }
    if (a.accessory == 3) {
      final strap = Paint()
        ..color = const Color(0xFF3A2A1A)
        ..strokeWidth = s * 0.05
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx - s * 0.12, bodyTop), Offset(cx - s * 0.20, s), strap);
      canvas.drawLine(Offset(cx + s * 0.12, bodyTop), Offset(cx + s * 0.20, s), strap);
    }

    // Neck
    canvas.drawRect(Rect.fromLTWH(cx - s * 0.07, s * 0.52, s * 0.14, s * 0.13), Paint()..color = Color.lerp(skin, Colors.black, 0.12)!);

    // Head
    final headR = s * 0.21;
    final headC = Offset(cx, s * 0.36);
    canvas.drawCircle(headC, headR, Paint()..color = skin);
    // Ears
    canvas.drawCircle(Offset(cx - headR * 0.98, headC.dy + headR * 0.05), headR * 0.18, Paint()..color = skin);
    canvas.drawCircle(Offset(cx + headR * 0.98, headC.dy + headR * 0.05), headR * 0.18, Paint()..color = skin);

    // Hair (behind-face part for long hair)
    final hairPaint = Paint()..color = hair;
    switch (a.hairStyle) {
      case 4: // long
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, headC.dy + headR * 0.55), width: headR * 2.3, height: headR * 2.4), Radius.circular(headR * 0.7)), hairPaint);
        canvas.drawCircle(headC, headR, Paint()..color = skin);
      default:
        break;
    }

    // Face: eyes and mouth
    final eyeY = headC.dy + headR * 0.05;
    final eye = Paint()..color = const Color(0xFF1B1B1B);
    canvas.drawCircle(Offset(cx - headR * 0.36, eyeY), headR * 0.08, eye);
    canvas.drawCircle(Offset(cx + headR * 0.36, eyeY), headR * 0.08, eye);
    canvas.drawArc(Rect.fromCenter(center: Offset(cx, headC.dy + headR * 0.42), width: headR * 0.6, height: headR * 0.4), 0.15 * math.pi, 0.7 * math.pi, false, Paint()
      ..color = const Color(0xFF7A3B2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.015
      ..strokeCap = StrokeCap.round);

    // Hair (top)
    switch (a.hairStyle) {
      case 0: // short
        canvas.drawArc(Rect.fromCircle(center: headC, radius: headR * 1.04), math.pi, math.pi, true, hairPaint);
      case 1: // crop (tight)
        canvas.drawArc(Rect.fromCircle(center: headC, radius: headR * 1.0), math.pi * 1.05, math.pi * 0.9, true, hairPaint);
      case 2: // wavy
        final p = Path()..moveTo(cx - headR * 1.08, headC.dy + headR * 0.1);
        for (var i = 0; i <= 6; i++) {
          final t = i / 6;
          final x = cx - headR * 1.08 + t * headR * 2.16;
          final y = headC.dy - headR * (0.85 + 0.25 * math.sin(t * math.pi * 3));
          p.lineTo(x, y);
        }
        p.lineTo(cx + headR * 1.08, headC.dy + headR * 0.1);
        p.close();
        canvas.drawPath(p, hairPaint);
        canvas.drawCircle(Offset(cx, headC.dy + headR * 0.08), headR * 0.96, Paint()..color = skin);
        canvas.drawArc(Rect.fromCircle(center: headC, radius: headR * 1.02), math.pi * 1.1, math.pi * 0.8, true, hairPaint);
      case 3: // bun
        canvas.drawArc(Rect.fromCircle(center: headC, radius: headR * 1.02), math.pi, math.pi, true, hairPaint);
        canvas.drawCircle(Offset(cx, headC.dy - headR * 1.15), headR * 0.32, hairPaint);
      case 4: // long: fringe
        canvas.drawArc(Rect.fromCircle(center: headC, radius: headR * 1.04), math.pi * 1.08, math.pi * 0.84, true, hairPaint);
      case 5: // shaved: faint shadow
        canvas.drawArc(Rect.fromCircle(center: headC, radius: headR * 1.0), math.pi, math.pi, true, Paint()..color = hair.withValues(alpha: 0.35));
    }

    // Accessories on top
    switch (a.accessory) {
      case 1: // cap
        final capColor = trim;
        canvas.drawArc(Rect.fromCircle(center: Offset(cx, headC.dy - headR * 0.05), radius: headR * 1.08), math.pi, math.pi, true, Paint()..color = capColor);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - headR * 1.15, headC.dy - headR * 0.12, headR * 1.7, headR * 0.16), Radius.circular(headR * 0.08)), Paint()..color = Color.lerp(capColor, Colors.black, 0.25)!);
      case 2: // sunglasses
        final g = Paint()..color = const Color(0xFF111111);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx - headR * 0.36, eyeY), width: headR * 0.5, height: headR * 0.32), Radius.circular(headR * 0.1)), g);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + headR * 0.36, eyeY), width: headR * 0.5, height: headR * 0.32), Radius.circular(headR * 0.1)), g);
        canvas.drawLine(Offset(cx - headR * 0.11, eyeY), Offset(cx + headR * 0.11, eyeY), g..strokeWidth = s * 0.012);
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(_AvatarPainter old) => old.a != a;
}
