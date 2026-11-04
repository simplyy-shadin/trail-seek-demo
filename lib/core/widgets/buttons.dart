import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Primary call to action: neon fill, dark text, optional leading icon and loading state.
class NeonButton extends StatelessWidget {
  const NeonButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.danger = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;

  /// Red variant for destructive actions (End session, Stop group).
  final bool danger;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: TsColors.onNeon))
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (trailingIcon != null) ...[const SizedBox(width: 8), Icon(trailingIcon, size: 20)],
            ],
          );
    final button = FilledButton(
      onPressed: loading ? null : onPressed,
      style: danger
          ? FilledButton.styleFrom(backgroundColor: TsColors.danger, foregroundColor: Colors.white)
          : null,
      child: child,
    );
    return expanded ? button : IntrinsicWidth(child: button);
  }
}

/// Secondary action: outlined on surface.
class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, this.onPressed, this.icon, this.expanded = true});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    return expanded ? button : IntrinsicWidth(child: button);
  }
}

/// Small pill with an icon and short label (filters, quick toggles).
class IconPillButton extends StatelessWidget {
  const IconPillButton({super.key, required this.icon, required this.label, this.onTap, this.selected = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? TsColors.onNeon : TsColors.textPrimary;
    return Material(
      color: selected ? TsColors.neon : TsColors.surface,
      shape: StadiumBorder(side: BorderSide(color: selected ? TsColors.neon : TsColors.outline)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular icon button used over maps and headers.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, this.onTap, this.size = 44, this.neon = false, this.tooltip});
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool neon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final m = Material(
      color: neon ? TsColors.neon : TsColors.surface,
      shape: CircleBorder(side: BorderSide(color: neon ? TsColors.neon : TsColors.outline)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.5, color: neon ? TsColors.onNeon : TsColors.textPrimary),
        ),
      ),
    );
    return tooltip == null ? m : Tooltip(message: tooltip!, child: m);
  }
}
