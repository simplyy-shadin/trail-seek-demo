import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// The standard surface: dark card with hairline border and large radius.
class TsCard extends StatelessWidget {
  const TsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(TsSpace.lg),
    this.onTap,
    this.highlighted = false,
    this.color,
    this.radius = TsSpace.radiusLg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Neon border, used for the selected item in a list of choices.
  final bool highlighted;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: highlighted ? TsColors.neon : TsColors.outline, width: highlighted ? 1.5 : 1),
    );
    return Material(
      color: color ?? TsColors.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Icon on top, big value, small label. Used in rows of 2–4.
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.icon, required this.value, required this.label, this.color});
  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TsCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color ?? TsColors.neon, size: 22),
          const SizedBox(height: 6),
          FittedBox(child: Text(value, style: TsText.stat)),
          const SizedBox(height: 2),
          Text(label, style: TsText.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Inline stat with the icon to the left (used in dense panels).
class InlineStat extends StatelessWidget {
  const InlineStat({super.key, required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: TsColors.textMuted),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TsText.caption),
            Text(value, style: TsText.h3),
          ],
        ),
      ],
    );
  }
}

/// Title row with optional trailing action ("View All").
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction, this.top = TsSpace.xl});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: TsSpace.md),
      child: Row(
        children: [
          Expanded(child: Text(title, style: TsText.h3)),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Pill segmented control: Stats · Badges · Achievements · History.
class SegmentTabs extends StatelessWidget {
  const SegmentTabs({super.key, required this.labels, required this.selected, required this.onChanged, this.scrollable = false});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      for (var i = 0; i < labels.length; i++)
        Padding(
          padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 6),
          child: _Segment(label: labels[i], selected: i == selected, onTap: () => onChanged(i), expand: !scrollable),
        ),
    ];
    final row = scrollable
        ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: tabs))
        : Row(children: [for (final t in tabs) Expanded(child: t)]);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: TsColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TsColors.outline),
      ),
      child: row,
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, required this.onTap, required this.expand});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? TsColors.neon : Colors.transparent,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? TsColors.onNeon : TsColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
