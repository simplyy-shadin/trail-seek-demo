import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../booking/booking_controller.dart';

/// Next trip and live Digital Rope shortcuts at the top of the first tab.
class HomeBanners extends ConsumerWidget {
  const HomeBanners({super.key, this.inset = 20});

  /// Side padding (0 inside a list that already pads its children).
  final double inset;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(bookingProvider);
    final next = ref.read(bookingProvider.notifier).upcoming.firstOrNull;
    final active = ref.watch(activeSessionProvider);
    Widget banner(IconData icon, String text, VoidCallback onTap, {bool neon = false}) => Padding(
          padding: EdgeInsets.fromLTRB(inset, 0, inset, 10),
          child: TsCard(
            color: neon ? TsColors.neon : null,
            highlighted: !neon,
            onTap: onTap,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(children: [
              Icon(icon, size: 18, color: neon ? TsColors.onNeon : TsColors.neon),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: TsText.bodyStrong.copyWith(color: neon ? TsColors.onNeon : null), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Icon(Icons.chevron_right, color: neon ? TsColors.onNeon : TsColors.textMuted),
            ]),
          ),
        );
    return Column(children: [
      if (active != null) banner(Icons.sensors, 'Digital Rope active · ${active.name}', () => context.push('/group/${active.id}/live'), neon: true),
      if (next != null) banner(Icons.confirmation_number_outlined, 'Next trip: ${next.programName} · ${DateFormat('d MMM').format(next.date)}', () => context.push('/booking/${next.id}')),
    ]);
  }
}
