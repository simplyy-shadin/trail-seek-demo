import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models/adventure.dart';
import '../../data/models/destination.dart';
import 'widgets.dart';

/// Italic screen title used across the redesigned tabs ("Explore", "Athirappilly").
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key, this.size = 30});
  final String text;
  final double size;
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 1.1, letterSpacing: -0.3));
}

/// Rounded photo card with a title strip, the wireframe's main block.
class OutlinedPhotoCard extends StatelessWidget {
  const OutlinedPhotoCard({super.key, required this.image, required this.title, this.subtitle, this.badge, this.trailing, this.onTap, this.height = 190});
  final String? image;
  final String title;
  final String? subtitle;
  final Widget? badge;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: AdventureCover(
          image: image,
          hue: 140,
          icon: Icons.forest,
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)], stops: const [0.35, 1])),
                ),
              ),
              if (badge != null) Positioned(top: 10, left: 10, child: badge!),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, height: 1.15)),
                          if (subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DestinationBigCard extends StatelessWidget {
  const DestinationBigCard({super.key, required this.d, required this.onTap});
  final Destination d;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedPhotoCard(
        image: d.coverImage,
        title: d.shortName,
        subtitle: '${d.programCount} programmes · ${d.tagline}',
        trailing: const Icon(Icons.arrow_circle_right_outlined, color: Colors.white, size: 30),
        onTap: onTap,
      );
}

class ProgrammeBigCard extends StatelessWidget {
  const ProgrammeBigCard({super.key, required this.a, required this.onTap});
  final Adventure a;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final status = TrekCard.statusLabel(a);
    return OutlinedPhotoCard(
      image: a.coverImage,
      title: a.name,
      subtitle: '${a.programType == ProgramType.coracle ? '' : '${a.distanceLabel} · '}${a.durationLabel}${status == null ? '' : ' · ${status.$1}'}',
      badge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: TsColors.neon, borderRadius: BorderRadius.circular(999)),
        child: Text(a.pricing.shortLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: TsColors.onNeon)),
      ),
      onTap: onTap,
    );
  }
}

/// White rounded pill search field from the wireframe (State / District).
class PillField extends StatelessWidget {
  const PillField({super.key, required this.hint, this.value, required this.onTap});
  final String hint;
  final String? value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
        child: Row(
          children: [
            const Icon(Icons.search, size: 18, color: Colors.black87),
            const SizedBox(width: 8),
            Expanded(
              child: Text(value ?? hint, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: value == null ? TextAlign.center : TextAlign.start,
                  style: TextStyle(color: value == null ? Colors.black38 : Colors.black, fontStyle: value == null ? FontStyle.italic : FontStyle.normal, fontWeight: value == null ? FontWeight.w400 : FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
