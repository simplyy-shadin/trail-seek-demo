import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models/avatar.dart';
import 'avatar_view.dart';

/// Circular avatar with a neon ring and optional edit pencil.
/// Until task 04 lands, the avatar is initials on a tinted disc.
class AvatarRing extends StatelessWidget {
  const AvatarRing({
    super.key,
    required this.initials,
    this.size = 88,
    this.image,
    this.ringColor = TsColors.neon,
    this.ringWidth = 3,
    this.onEdit,
    this.tint,
    this.avatar,
    this.avatarId,
  });

  final String initials;
  final double size;
  final ImageProvider? image;

  /// When set, the procedural avatar is drawn instead of initials.
  final Avatar? avatar;

  /// Full avatar id (`img:` or `v1:`); takes precedence over [avatar].
  final String? avatarId;
  final Color ringColor;
  final double ringWidth;
  final VoidCallback? onEdit;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tint ?? TsColors.surfaceHigh,
              border: Border.all(color: ringColor, width: ringWidth),
              image: image == null ? null : DecorationImage(image: image!, fit: BoxFit.cover),
              boxShadow: [BoxShadow(color: ringColor.withValues(alpha: 0.35), blurRadius: 14)],
            ),
            alignment: Alignment.center,
            child: avatarId != null || avatar != null
                ? AvatarView(avatar: avatar ?? Avatar.decode(avatarId), avatarId: avatarId, size: size - ringWidth * 2, background: tint ?? TsColors.surfaceHigh)
                : image == null
                    ? Text(initials, style: TextStyle(fontSize: size * 0.34, fontWeight: FontWeight.w800))
                    : null,
          ),
          if (onEdit != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: Material(
                color: TsColors.neon,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onEdit,
                  child: SizedBox(
                    width: size * 0.32,
                    height: size * 0.32,
                    child: Icon(Icons.edit, size: size * 0.17, color: TsColors.onNeon),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small avatar used in lists and on the map; ring colour conveys state.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.initials, this.size = 36, this.color, this.ring, this.avatar, this.avatarId});
  final String initials;
  final double size;
  final Color? color;
  final Color? ring;
  final Avatar? avatar;
  final String? avatarId;

  @override
  Widget build(BuildContext context) {
    final border = ring == null ? 1.0 : 2.5;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color ?? TsColors.surfaceHigh,
        border: Border.all(color: ring ?? TsColors.outline, width: border),
      ),
      alignment: Alignment.center,
      child: avatarId != null || avatar != null
          ? AvatarView(avatar: avatar ?? Avatar.decode(avatarId), avatarId: avatarId, size: size - border * 2, background: color ?? TsColors.surfaceHigh)
          : Text(initials, style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w800)),
    );
  }
}

/// Small coloured dot + text, e.g. "Online · 2.4 km".
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Text(text, style: TsText.caption),
      ],
    );
  }
}
