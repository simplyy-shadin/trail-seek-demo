import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/activity_category.dart';
import '../../data/models/activity_record.dart';
import '../../data/models/adventure.dart';
import '../discovery/adventure_picker.dart';
import 'tracking_controller.dart';

/// Pick an activity type and (optionally) a trail, then start recording.
class StartTrekScreen extends ConsumerStatefulWidget {
  const StartTrekScreen({super.key, this.adventureId});
  final String? adventureId;
  @override
  ConsumerState<StartTrekScreen> createState() => _StartTrekScreenState();
}

class _StartTrekScreenState extends ConsumerState<StartTrekScreen> {
  static const _types = [
    (ActivityType.trekking, ActivityCategory.trekking),
    (ActivityType.hiking, ActivityCategory.hiking),
    (ActivityType.forestWalk, ActivityCategory.forestWalk),
    (ActivityType.cycling, ActivityCategory.cycling),
    (ActivityType.kayaking, ActivityCategory.kayaking),
    (ActivityType.trailRunning, ActivityCategory.trailRunning),
  ];

  ActivityType _type = ActivityType.trekking;
  Adventure? _adventure;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.adventureId != null) {
      ref.read(adventureRepositoryProvider).byId(widget.adventureId!).then((a) {
        if (!mounted || a == null) return;
        setState(() {
          _adventure = a;
          _type = ActivityType.values.firstWhere((t) => t.name == a.primaryCategory.name, orElse: () => ActivityType.trekking);
        });
      });
    }
  }

  Future<void> _pickTrail() async {
    final picked = await showAdventurePicker(context, title: 'Link a trail', allowNone: true, noneLabel: 'Free trek (no trail)');
    if (!mounted) return;
    setState(() => _adventure = picked);
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    final error = await ref.read(trackingProvider.notifier).start(type: _type, adventure: _adventure);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    context.pushReplacement('/track');
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(trackingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Start Trek')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          if (tracking.isActive)
            TsCard(
              highlighted: true,
              onTap: () => context.pushReplacement('/track'),
              child: const Row(
                children: [
                  Icon(Icons.fiber_manual_record, color: TsColors.danger, size: 16),
                  SizedBox(width: 10),
                  Expanded(child: Text('A recording is already in progress. Tap to continue it.', style: TsText.bodyStrong)),
                  Icon(Icons.chevron_right, color: TsColors.textMuted),
                ],
              ),
            ),
          const SectionHeader('Activity', top: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: [
              for (final (type, cat) in _types)
                TsCard(
                  highlighted: _type == type,
                  onTap: () => setState(() => _type = type),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(cat.icon, color: _type == type ? TsColors.neon : TsColors.textMuted, size: 28),
                      const SizedBox(height: 8),
                      Text(cat.label, style: TsText.caption.copyWith(color: TsColors.textPrimary), textAlign: TextAlign.center),
                    ],
                  ),
                ),
            ],
          ),
          const SectionHeader('Trail'),
          TsCard(
            onTap: _pickTrail,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (_adventure != null)
                  SizedBox(width: 48, height: 48, child: AdventureCover.of(_adventure!, borderRadius: BorderRadius.circular(10)))
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: TsColors.surfaceHigh, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.explore_outlined, color: TsColors.textMuted),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_adventure?.name ?? 'Free trek', style: TsText.h3),
                      Text(_adventure == null ? 'No trail linked. Tap to choose one.' : '${_adventure!.district} · ${_adventure!.distanceLabel}', style: TsText.caption),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: TsColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Recording uses GPS continuously. Keep the phone where it can see the sky, and expect about 6–8 % battery per hour.',
            style: TsText.caption,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: NeonButton(label: 'Start Recording', icon: Icons.fiber_manual_record, loading: _busy, onPressed: _start),
      ),
    );
  }
}
