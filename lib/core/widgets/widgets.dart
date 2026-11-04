import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models/activity_category.dart';
import '../../data/models/adventure.dart';

export 'avatar_view.dart';
export 'buttons.dart';
export 'cards.dart';
export 'identity.dart';
export 'progress.dart';
export 'trek_card.dart';
export 'ts_bottom_nav.dart';

/// Placeholder "photo": a hue-driven gradient with a terrain silhouette,
/// used until licensed photography is available for each location.
class CoverArt extends StatelessWidget {
  const CoverArt({super.key, required this.hue, this.icon, this.borderRadius, this.child});
  final double hue;
  final IconData? icon;
  final BorderRadius? borderRadius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    // Pull every hue toward the mockup's forest greens/teals and keep it dark.
    final h = 95 + ((hue % 360) / 360) * 95; // 95..190
    final top = HSLColor.fromAHSL(1, h, 0.42, 0.34).toColor();
    final bottom = HSLColor.fromAHSL(1, (h + 15) % 360, 0.45, 0.12).toColor();
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: 0.55,
              child: Image.asset('assets/images/mountain_silhouette.png', fit: BoxFit.cover, height: 90, alignment: Alignment.bottomCenter),
            ),
          ),
          if (icon != null)
            Positioned(
              right: -8,
              top: -6,
              child: Icon(icon, size: 72, color: Colors.white.withValues(alpha: 0.07)),
            ),
          ?child,
        ],
      ),
    );
  }
}

/// A real photo when the content has one, else the placeholder gradient.
class AdventureCover extends StatelessWidget {
  const AdventureCover({super.key, this.image, required this.hue, this.icon, this.borderRadius, this.child, this.alignment = Alignment.center});

  AdventureCover.of(Adventure a, {super.key, this.borderRadius, this.child, this.alignment = Alignment.center})
      : image = a.coverImage,
        hue = a.coverHue,
        icon = a.primaryCategory.icon;

  final String? image;
  final double hue;
  final IconData? icon;
  final BorderRadius? borderRadius;
  final Widget? child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final img = image;
    if (img == null) return CoverArt(hue: hue, icon: icon, borderRadius: borderRadius, child: child);
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(img, fit: BoxFit.cover, alignment: alignment, errorBuilder: (_, _, _) => CoverArt(hue: hue, icon: icon)),
          ?child,
        ],
      ),
    );
  }
}

/// Swipeable photo gallery with dots, used as the hero of detail screens.
class PhotoGallery extends StatefulWidget {
  const PhotoGallery({super.key, required this.images, required this.hue, this.icon, this.overlay});
  final List<String> images;
  final double hue;
  final IconData? icon;
  final Widget? overlay;
  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  int _page = 0;
  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return CoverArt(hue: widget.hue, icon: widget.icon, child: widget.overlay);
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: widget.images.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) => Image.asset(widget.images[i], fit: BoxFit.cover, errorBuilder: (_, _, _) => CoverArt(hue: widget.hue, icon: widget.icon)),
        ),
        if (widget.overlay != null) IgnorePointer(child: widget.overlay),
        if (widget.images.length > 1)
          Positioned(
            right: 16,
            top: MediaQuery.paddingOf(context).top + 60,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(12)),
              child: Text('${_page + 1} / ${widget.images.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
      ],
    );
  }
}

class DifficultyChip extends StatelessWidget {
  const DifficultyChip(this.difficulty, {super.key, this.dense = false});
  final Difficulty difficulty;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 10, vertical: dense ? 2 : 5),
      decoration: BoxDecoration(
        color: difficulty.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: difficulty.color.withValues(alpha: 0.6)),
      ),
      child: Text(difficulty.label,
          style: TextStyle(color: difficulty.color, fontSize: dense ? 11 : 12, fontWeight: FontWeight.w700, height: 1.2)),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.icon, required this.value, required this.label, this.color});
  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(color: TsColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color ?? TsColors.green, size: 22),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: TsColors.muted)),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          ?trailing,
        ],
      ),
    );
  }
}

class BulletList extends StatelessWidget {
  const BulletList(this.items, {super.key, this.icon = Icons.circle, this.iconColor, this.iconSize = 6});
  final List<String> items;
  final IconData icon;
  final Color? iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: iconSize <= 8 ? 7 : 2, right: 10),
                  child: Icon(icon, size: iconSize, color: iconColor ?? TsColors.muted),
                ),
                Expanded(child: Text(item, style: const TextStyle(height: 1.4))),
              ],
            ),
          ),
      ],
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.icon, required this.label, required this.value, this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: TsColors.surfaceHigh, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color ?? TsColors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: TsColors.muted)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FeatureRow extends StatelessWidget {
  const FeatureRow({super.key, required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TsColors.green.withValues(alpha: 0.12),
              border: Border.all(color: TsColors.green.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, color: TsColors.green),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: TsColors.muted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryIcon extends StatelessWidget {
  const CategoryIcon(this.category, {super.key, this.size = 20});
  final ActivityCategory category;
  final double size;
  @override
  Widget build(BuildContext context) => Icon(category.icon, size: size, color: TsColors.green);
}

class UnverifiedBanner extends StatelessWidget {
  const UnverifiedBanner({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TsColors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TsColors.amber.withValues(alpha: 0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: TsColors.amber, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Fees, permits and contacts are being verified with the forest office. Confirm before you travel.',
              style: TextStyle(fontSize: 12.5, color: TsColors.text, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
