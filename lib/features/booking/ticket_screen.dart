import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/adventure.dart';
import 'booking_controller.dart';
import 'booking_models.dart';

/// The ticket: QR + code for the gate, what was booked, what was paid.
class TicketScreen extends ConsumerWidget {
  const TicketScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(bookingProvider);
    final b = ref.read(bookingProvider.notifier).byId(bookingId);
    if (b == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Booking not found')));
    final a = ref.watch(adventureByIdProvider(b.programId)).value;
    final isNew = GoRouterState.of(context).uri.queryParameters['new'] == '1';
    final cancelled = b.status == BookingStatus.cancelled;
    final qr = 'TRAILSEEK|${b.code}|${b.programId}|${DateFormat('yyyy-MM-dd').format(b.date)}|${b.party.total}';
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Booked!' : 'Your ticket'),
        actions: [
          IconButton(
            tooltip: 'Share',
            onPressed: () => SharePlus.instance.share(ShareParams(text: 'Trail Seek ticket ${b.code}: ${b.programName}, ${DateFormat('d MMM yyyy').format(b.date)} at ${b.slot}, ${b.party.label}.')),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          if (isNew)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: TsColors.neon, size: 28),
                  const SizedBox(width: 10),
                  Expanded(child: Text('You are going to ${b.programName}. Show this QR at the gate.', style: TsText.bodyStrong)),
                ],
              ),
            ),
          TsCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SizedBox(height: 150, width: double.infinity, child: AdventureCover(image: b.coverImage, hue: 140, icon: Icons.forest, borderRadius: const BorderRadius.vertical(top: Radius.circular(TsSpace.radiusLg)))),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(b.programName, style: TsText.h2, textAlign: TextAlign.center),
                      const SizedBox(height: 2),
                      Text(b.destinationName, style: TsText.caption),
                      const SizedBox(height: 14),
                      Opacity(
                        opacity: cancelled ? 0.3 : 1,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                          child: QrImageView(data: qr, version: QrVersions.auto, size: 190, backgroundColor: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(b.code, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 6)),
                      Text(cancelled ? 'CANCELLED' : 'Booking code', style: TsText.caption.copyWith(color: cancelled ? TsColors.danger : null, fontWeight: FontWeight.w700)),
                      const Divider(height: 28),
                      _row(Icons.event, DateFormat('EEEE, d MMMM yyyy').format(b.date)),
                      _row(Icons.schedule, b.slot),
                      _row(Icons.groups_outlined, b.party.label),
                      if (b.vehicle != null) _row(Icons.local_parking, 'Parking · ${b.vehicle}'),
                      if (b.camera) _row(Icons.photo_camera_outlined, 'Camera permit'),
                      _row(Icons.person_outline, b.userName),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('Payment'),
          TsCard(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Column(
              children: [
                for (final l in b.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [Expanded(child: Text(l.label, style: TsText.caption.copyWith(color: TsColors.textPrimary))), Text(ProgramPricing.rupees(l.amount))]),
                  ),
                const Divider(height: 14),
                Row(children: [const Expanded(child: Text('Paid', style: TsText.bodyStrong)), Text(ProgramPricing.rupees(b.total), style: TsText.h3.copyWith(color: TsColors.neon))]),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [Expanded(child: Text('${b.paymentMethod} · ref ${b.paymentRef}', style: TsText.caption)), Text(DateFormat('d MMM, h:mm a').format(b.createdAt), style: TsText.caption)]),
                ),
              ],
            ),
          ),
          const SectionHeader('Before you go'),
          const BulletList([
            'Reach the gate 15 minutes before your time; treks leave on time.',
            'Government photo ID for everyone on the ticket.',
            'The QR works offline. A screenshot is fine.',
            'Free cancellation up to 48 hours before the start, from this screen.',
          ], icon: Icons.check_circle_outline, iconColor: TsColors.green, iconSize: 18),
          if (a != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: GhostButton(label: 'Directions', icon: Icons.directions, onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${a.lat},${a.lng}&travelmode=driving'), mode: LaunchMode.externalApplication))),
                const SizedBox(width: 10),
                Expanded(child: GhostButton(label: 'Programme', icon: Icons.info_outline, onPressed: () => context.push('/adventure/${a.id}'))),
              ],
            ),
          ],
          if (!cancelled && b.isUpcoming) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => _cancel(context, ref, b),
              icon: const Icon(Icons.cancel_outlined, color: TsColors.danger),
              label: const Text('Cancel booking', style: TextStyle(color: TsColors.danger)),
            ),
          ],
        ],
      ),
      bottomNavigationBar: a != null && a.isWalkable && !cancelled
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(flex: 2, child: GhostButton(label: 'Group', icon: Icons.groups, onPressed: () => context.push('/group/create?adventure=${a.id}'))),
                  const SizedBox(width: 10),
                  Expanded(flex: 3, child: NeonButton(label: 'Start Trek', icon: Icons.hiking, onPressed: () => context.push('/track/start?adventure=${a.id}'))),
                ],
              ),
            )
          : null,
    );
  }

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Icon(icon, size: 18, color: TsColors.textMuted), const SizedBox(width: 10), Expanded(child: Text(text))]),
      );

  Future<void> _cancel(BuildContext context, WidgetRef ref, Booking b) async {
    final hoursLeft = b.date.difference(DateTime.now()).inHours;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: Text(hoursLeft >= 48 ? 'You will get a full refund of ${ProgramPricing.rupees(b.total)} to the same payment method within 5–7 days.' : 'Less than 48 hours to the start, so this booking is not refundable. Cancel anyway?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel booking')),
        ],
      ),
    );
    if (ok == true) await ref.read(bookingProvider.notifier).cancel(b.id);
  }
}
