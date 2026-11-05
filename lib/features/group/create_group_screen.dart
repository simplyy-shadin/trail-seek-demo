import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/adventure.dart';
import '../discovery/adventure_picker.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key, this.adventureId});
  final String? adventureId;
  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _name = TextEditingController();
  Adventure? _adventure;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _start = const TimeOfDay(hour: 6, minute: 0);
  int _size = 6;
  bool _simulated = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.adventureId != null) {
      ref.read(adventureRepositoryProvider).byId(widget.adventureId!).then((a) {
        if (mounted) setState(() => _adventure = a);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickAdventure() async {
    final picked = await showAdventurePicker(context, title: 'Which adventure?');
    if (picked != null && mounted) setState(() => _adventure = picked);
  }

  Future<void> _create() async {
    final a = _adventure;
    if (a == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose an adventure first.')));
      return;
    }
    setState(() => _busy = true);
    try {
      final start = DateTime(_date.year, _date.month, _date.day, _start.hour, _start.minute);
      final session = await ref.read(groupProvider.notifier).create(
            name: _name.text,
            adventure: a,
            date: _date,
            expectedStart: start,
            plannedSize: _size,
            simulated: _simulated,
          );
      if (!mounted) return;
      context.pushReplacement('/group/${session.id}/lobby');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not securely create group: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create a Group')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Group name', hintText: 'E.g. Weekend Hikers', prefixIcon: Icon(Icons.group_outlined)),
          ),
          const SizedBox(height: 12),
          _Field(
            icon: Icons.terrain,
            label: 'Adventure',
            value: _adventure?.name ?? 'Choose adventure',
            trailing: _adventure == null
                ? null
                : SizedBox(width: 44, height: 44, child: AdventureCover.of(_adventure!, borderRadius: BorderRadius.circular(10))),
            onTap: _pickAdventure,
          ),
          const SizedBox(height: 12),
          _Field(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: DateFormat('d MMM yyyy').format(_date),
            onTap: () async {
              final d = await showDatePicker(
                  context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (d != null) setState(() => _date = d);
            },
          ),
          const SizedBox(height: 12),
          _Field(
            icon: Icons.schedule,
            label: 'Expected start time',
            value: _start.format(context),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _start);
              if (t != null) setState(() => _start = t);
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: TsColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: TsColors.outline)),
            child: Row(
              children: [
                const Icon(Icons.people_outline, color: TsColors.muted),
                const SizedBox(width: 12),
                const Expanded(child: Text('Number of members')),
                IconButton(onPressed: _size > 2 ? () => setState(() => _size--) : null, icon: const Icon(Icons.remove_circle_outline)),
                Text('$_size', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                IconButton(onPressed: _size < 16 ? () => setState(() => _size++) : null, icon: const Icon(Icons.add_circle_outline)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _simulated,
            onChanged: (v) => setState(() => _simulated = v),
            activeThumbColor: TsColors.primary,
            tileColor: TsColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: TsColors.outline)),
            title: const Text('Try a demo instead (no other phones)'),
            subtitle: Text(
              _simulated
                  ? 'Pretend members walk with you. Nobody real can join this group.'
                  : 'Off = real group over Bluetooth. Every member needs the app and Bluetooth on.',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: _busy ? null : _create,
              child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create Group'),
            ),
            const SizedBox(height: 8),
            const Text('OR', style: TextStyle(color: TsColors.muted, fontSize: 12)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.pushReplacement('/group/join${widget.adventureId == null ? '' : '?adventure=${widget.adventureId}'}'),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Join with Code / QR'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.icon, required this.label, required this.value, required this.onTap, this.trailing});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: TsColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: TsColors.outline)),
        child: Row(
          children: [
            Icon(icon, color: TsColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: TsColors.muted)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right, color: TsColors.muted),
          ],
        ),
      ),
    );
  }
}
