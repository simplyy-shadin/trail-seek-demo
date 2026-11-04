import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/models/adventure.dart';
import '../../features/settings/settings_controller.dart';
import 'widgets.dart';

/// Programme card for the Home list: photo, name, destination, price, status.
class TrekCard extends ConsumerWidget {
  const TrekCard({
    super.key,
    required this.adventure,
    required this.saved,
    required this.onTap,
    required this.onToggleSaved,
  });

  final Adventure adventure;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitsProvider);
    final a = adventure;
    final status = statusLabel(a);
    return TsCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            height: 136,
            child: AdventureCover.of(
              a,
              borderRadius: BorderRadius.circular(TsSpace.radiusMd),
              child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(a.programType.icon, size: 11, color: TsColors.neon),
                      const SizedBox(width: 3),
                      Flexible(child: Text(a.programType.label.split(' ').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white))),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TsText.h3.copyWith(height: 1.15)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 12, color: TsColors.textMuted),
                    const SizedBox(width: 3),
                    Expanded(child: Text(a.destinationName ?? '${a.district}, Kerala', style: TsText.caption, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(a.summary, style: TsText.caption.copyWith(color: TsColors.textPrimary.withValues(alpha: 0.8), height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Price(a.pricing.shortLabel),
                    if (a.programType != ProgramType.coracle && a.programType != ProgramType.entry) DifficultyChip(a.difficulty, dense: true),
                    if (a.programType != ProgramType.coracle) _Meta(Icons.straighten, units.distanceKm(a.distanceKm)),
                    _Meta(Icons.schedule, a.durationLabel),
                    if (status != null) _Status(status.$1, status.$2),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: onToggleSaved,
                icon: Icon(saved ? Icons.favorite : Icons.favorite_border, color: saved ? TsColors.danger : TsColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Short booking status for cards: closed, not started, or ask the office.
  static (String, Color)? statusLabel(Adventure a) {
    final b = a.booking;
    if (b == null) return null;
    return switch (b.availability) {
      Availability.closed => ('Not available now', TsColors.danger),
      Availability.soon => ('Opening soon', TsColors.amber),
      Availability.onRequest => ('On request', TsColors.amber),
      Availability.open => null,
    };
  }
}

class _Price extends StatelessWidget {
  const _Price(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: TsColors.neon.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: TsColors.neon)),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color));
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: TsColors.textMuted),
        const SizedBox(width: 4),
        Text(text, style: TsText.caption.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
