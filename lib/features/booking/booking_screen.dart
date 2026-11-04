import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/adventure.dart';
import 'booking_controller.dart';
import 'booking_models.dart';

/// Pick a date, a slot and who is coming; see the price; go to payment.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.adventureId});
  final String adventureId;
  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  late DateTime _date = _today.add(const Duration(days: 1));
  String? _slot;
  Party _party = const Party();
  String? _vehicle;
  bool _camera = false;

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(adventureByIdProvider(widget.adventureId)).value;
    if (a == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    final booking = a.booking ?? const BookingInfo();
    final slots = slotsFor(a);
    _slot ??= slots.first;
    final quote = Quote.compute(a, _party, vehicle: _vehicle, camera: _camera);
    final ctrl = ref.watch(bookingProvider.notifier);
    ref.watch(bookingProvider);
    final taken = ctrl.booked(a.id, _date, _slot!);
    final cap = booking.capacityPerDay;
    final left = cap == null ? null : (cap - taken).clamp(0, cap);
    final maxParty = a.maxPersons == null ? 20 : (a.pricing.additionalPerPerson != null ? 20 : a.maxPersons!);
    final tooMany = _party.total > maxParty;
    final tooFew = a.minPersons != null && _party.total < a.minPersons!;
    final full = left != null && _party.total > left;
    final canContinue = !tooMany && !tooFew && !full && booking.bookable && _party.total > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Check slots')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
        children: [
          Row(
            children: [
              SizedBox(width: 72, height: 72, child: AdventureCover.of(a, borderRadius: BorderRadius.circular(12))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name, style: TsText.h3, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(a.destinationName ?? a.district, style: TsText.caption),
                    const SizedBox(height: 2),
                    Text(a.timing.label, style: TsText.caption),
                  ],
                ),
              ),
            ],
          ),
          const SectionHeader('Pick a date'),
          MonthCalendar(
            start: _today.add(const Duration(days: 1)),
            days: booking.bookingWindowDays.clamp(7, 90),
            selected: _date,
            onSelect: (d) => setState(() => _date = d),
          ),
          const SectionHeader('Time'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in slots) ChoiceChip(label: Text(s), selected: _slot == s, onSelected: (_) => setState(() => _slot = s)),
            ],
          ),
          if (a.timing.note != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(a.timing.note!, style: TsText.caption)),
          if (left != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(left == 0 ? 'No seats left on this slot' : '$left of $cap seats left on ${DateFormat('d MMM').format(_date)}', style: TsText.caption.copyWith(color: left == 0 ? TsColors.danger : TsColors.neon))),
          const SectionHeader('Who is coming'),
          _Stepper('Adults', _party.adults, min: 0, onChanged: (v) => setState(() => _party = _party.copyWith(adults: v))),
          _Stepper('Children (under 15)', _party.children, min: 0, onChanged: (v) => setState(() => _party = _party.copyWith(children: v))),
          _Stepper('Students (with ID)', _party.students, min: 0, onChanged: (v) => setState(() => _party = _party.copyWith(students: v))),
          _Stepper('Foreign nationals', _party.foreigners, min: 0, onChanged: (v) => setState(() => _party = _party.copyWith(foreigners: v))),
          if (a.minPersons != null || a.maxPersons != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [
                  if (a.minPersons != null && a.minPersons! > 1) 'Minimum ${a.minPersons}',
                  if (a.maxPersons != null) a.pricing.additionalPerPerson != null ? 'Ticket covers ${a.maxPersons}; extra people added per head' : 'Maximum ${a.maxPersons} per ticket',
                ].join(' · '),
                style: TsText.caption,
              ),
            ),
          if (a.pricing.vehicleFees.isNotEmpty) ...[
            const SectionHeader('Parking'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(label: const Text('No vehicle'), selected: _vehicle == null, onSelected: (_) => setState(() => _vehicle = null)),
                for (final e in a.pricing.vehicleFees.entries)
                  ChoiceChip(label: Text('${e.key} · ${ProgramPricing.rupees(e.value)}'), selected: _vehicle == e.key, onSelected: (_) => setState(() => _vehicle = e.key)),
              ],
            ),
          ],
          if (a.pricing.cameraFees.isNotEmpty)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _camera,
              onChanged: (v) => setState(() => _camera = v),
              title: const Text('Camera permit'),
              subtitle: Text('${ProgramPricing.rupees(a.pricing.cameraFees.values.first)} · phones do not need one'),
            ),
          const SectionHeader('Price'),
          TsCard(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Column(
              children: [
                for (final l in quote.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [Expanded(child: Text(l.label, style: TsText.caption.copyWith(color: TsColors.textPrimary))), Text(ProgramPricing.rupees(l.amount), style: TsText.bodyStrong)]),
                  ),
                if (quote.lines.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Price confirmed with your booking', style: TsText.caption)),
                const Divider(height: 16),
                Row(children: [const Expanded(child: Text('Total', style: TsText.h3)), Text(ProgramPricing.rupees(quote.total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: TsColors.neon))]),
              ],
            ),
          ),
          if (tooMany) _warn('This programme takes up to $maxParty people per booking. Make a second booking for the rest of the group.'),
          if (tooFew) _warn('This programme needs at least ${a.minPersons} people.'),
          if (full && !tooMany) _warn('Not enough seats left on this slot. Pick another time or date.'),
          if (!booking.bookable) _warn(booking.availability == Availability.closed ? 'This programme is paused for the season. Save it and we will tell you when dates open.' : 'Opening soon. Save it to be told when booking starts.'),
          const SizedBox(height: 8),
          const Text('Free cancellation up to 48 hours before the start. Carry a government photo ID for everyone; the ticket QR is checked at the gate.', style: TsText.caption),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: NeonButton(
          label: 'Continue · ${ProgramPricing.rupees(quote.total)}',
          icon: Icons.arrow_forward,
          onPressed: canContinue
              ? () => context.push('/book/${a.id}/pay', extra: BookingDraft(adventure: a, date: _date, slot: _slot!, party: _party, quote: quote, vehicle: _vehicle, camera: _camera))
              : null,
        ),
      ),
    );
  }

  Widget _warn(String text) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 18, color: TsColors.amber),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(color: TsColors.amber, height: 1.35))),
          ],
        ),
      );
}

/// Month calendar for picking a visit date; only [start]..[start + days) is selectable.
class MonthCalendar extends StatefulWidget {
  const MonthCalendar({super.key, required this.start, required this.days, required this.selected, required this.onSelect});
  final DateTime start;
  final int days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _month = DateTime(widget.selected.year, widget.selected.month);

  DateTime get _last => widget.start.add(Duration(days: widget.days - 1));
  bool _enabled(DateTime d) => !d.isBefore(widget.start) && !d.isAfter(_last);

  @override
  Widget build(BuildContext context) {
    final first = DateTime(_month.year, _month.month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday % 7; // Sunday first
    final canPrev = DateTime(_month.year, _month.month).isAfter(DateTime(widget.start.year, widget.start.month));
    final canNext = DateTime(_month.year, _month.month + 1).isBefore(DateTime(_last.year, _last.month + 1));
    return TsCard(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(onPressed: canPrev ? () => setState(() => _month = DateTime(_month.year, _month.month - 1)) : null, icon: const Icon(Icons.chevron_left)),
              Expanded(child: Text(DateFormat('MMMM yyyy').format(_month), textAlign: TextAlign.center, style: TsText.h3)),
              IconButton(onPressed: canNext ? () => setState(() => _month = DateTime(_month.year, _month.month + 1)) : null, icon: const Icon(Icons.chevron_right)),
            ],
          ),
          Row(children: [for (final w in const ['S', 'M', 'T', 'W', 'T', 'F', 'S']) Expanded(child: Text(w, textAlign: TextAlign.center, style: TsText.caption))]),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (var i = 0; i < lead; i++) const SizedBox.shrink(),
              for (var day = 1; day <= daysInMonth; day++)
                Builder(builder: (_) {
                  final d = DateTime(_month.year, _month.month, day);
                  final on = _enabled(d);
                  final sel = d.year == widget.selected.year && d.month == widget.selected.month && d.day == widget.selected.day;
                  return GestureDetector(
                    onTap: on ? () => widget.onSelect(d) : null,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: sel ? TsColors.neon : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sel ? TsColors.neon : (on ? Colors.white.withValues(alpha: 0.7) : TsColors.outline)),
                      ),
                      child: Text('$day', style: TextStyle(fontWeight: FontWeight.w800, color: sel ? TsColors.onNeon : (on ? TsColors.textPrimary : TsColors.textMuted.withValues(alpha: 0.5)))),
                    ),
                  );
                }),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper(this.label, this.value, {required this.onChanged, this.min = 0});
  static const max = 30;
  final String label;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(onPressed: value > min ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove_circle_outline)),
          SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.center, style: TsText.h3)),
          IconButton(onPressed: value < max ? () => onChanged(value + 1) : null, icon: const Icon(Icons.add_circle_outline, color: TsColors.neon)),
        ],
      ),
    );
  }
}
