import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/adventure.dart';
import 'booking_controller.dart';
import 'booking_models.dart';

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(bookingProvider);
    final ctrl = ref.read(bookingProvider.notifier);
    final upcoming = ctrl.upcoming;
    final past = ctrl.past;
    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: upcoming.isEmpty && past.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.confirmation_number_outlined, size: 48, color: TsColors.textMuted),
                    const SizedBox(height: 12),
                    const Text('No bookings yet', style: TsText.h3),
                    const SizedBox(height: 6),
                    const Text('Pick a programme on Home and tap Book.', style: TsText.caption, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    GhostButton(label: 'Browse programmes', expanded: false, onPressed: () => context.go('/home')),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                if (upcoming.isNotEmpty) const SectionHeader('Upcoming', top: 4),
                for (final b in upcoming) _BookingCard(b),
                if (past.isNotEmpty) const SectionHeader('Past & cancelled'),
                for (final b in past) _BookingCard(b),
              ],
            ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard(this.b);
  final Booking b;
  @override
  Widget build(BuildContext context) {
    final cancelled = b.status == BookingStatus.cancelled;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TsCard(
        onTap: () => context.push('/booking/${b.id}'),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            SizedBox(width: 72, height: 72, child: AdventureCover(image: b.coverImage, hue: 140, icon: Icons.forest, borderRadius: BorderRadius.circular(12))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.programName, style: TsText.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${DateFormat('EEE, d MMM').format(b.date)} · ${b.slot} · ${b.party.total} ${b.party.total == 1 ? 'person' : 'people'}', style: TsText.caption),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(b.code, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
                      const SizedBox(width: 10),
                      Text(cancelled ? 'Cancelled' : b.isUpcoming ? ProgramPricing.rupees(b.total) : 'Completed', style: TextStyle(fontWeight: FontWeight.w700, color: cancelled ? TsColors.danger : TsColors.neon)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: TsColors.textMuted),
          ],
        ),
      ),
    );
  }
}
