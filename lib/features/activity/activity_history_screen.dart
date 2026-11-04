import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/activity_category.dart';
import '../../data/models/activity_record.dart';
import '../settings/settings_controller.dart';
import 'track_store.dart';

/// Frame 13: "My Activities" with type filters, month groups and totals.
class ActivityHistoryScreen extends ConsumerStatefulWidget {
  const ActivityHistoryScreen({super.key, this.embedded = false, this.limit});

  /// Embedded inside the Profile History segment: no app bar, optional cap.
  final bool embedded;
  final int? limit;

  @override
  ConsumerState<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends ConsumerState<ActivityHistoryScreen> {
  ActivityType? _filter;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(activitiesProvider);
    final types = {for (final a in all) a.type}.toList()..sort((a, b) => a.index.compareTo(b.index));
    var list = _filter == null ? all : all.where((a) => a.type == _filter).toList();
    if (widget.limit != null && list.length > widget.limit!) list = list.sublist(0, widget.limit!);
    final rows = _group(list);

    final body = CustomScrollView(
      slivers: [
        if (types.length > 1)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _chip('All', _filter == null, () => setState(() => _filter = null)),
                  for (final t in types)
                    _chip(_label(t), _filter == t, () => setState(() => _filter = t), icon: _icon(t)),
                ],
              ),
            ),
          ),
        if (rows.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_walk, size: 48, color: TsColors.textMuted),
                    const SizedBox(height: 12),
                    Text(_filter == null ? 'No activities yet' : 'No ${_label(_filter!).toLowerCase()} activities yet', style: TsText.h3),
                    const SizedBox(height: 6),
                    const Text('Record a trek and it will show up here with XP.', style: TsText.caption, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    GhostButton(label: 'Start Trek', icon: Icons.hiking, expanded: false, onPressed: () => context.push('/track/start')),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            sliver: SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final row = rows[i];
                if (row is _MonthHeader) return _MonthTile(row);
                final a = (row as _ActivityRow).record;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Dismissible(
                    key: ValueKey(a.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(color: TsColors.danger.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(TsSpace.radiusLg)),
                      child: const Icon(Icons.delete_outline, color: TsColors.danger),
                    ),
                    confirmDismiss: (_) => _confirm(context),
                    onDismissed: (_) => _delete(context, a),
                    child: _ActivityTile(a),
                  ),
                );
              },
            ),
          ),
      ],
    );

    if (widget.embedded) {
      final shown = list.take(widget.limit ?? 5).toList();
      if (shown.isEmpty) {
        return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No activities yet. Record a trek and it will show up here with XP.', style: TsText.caption));
      }
      return Column(children: [for (final a in shown) Padding(padding: const EdgeInsets.only(bottom: 10), child: _ActivityTile(a))]);
    }
    return Scaffold(appBar: AppBar(title: const Text('My Activities')), body: body);
  }

  Future<bool> _confirm(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete this activity?'),
            content: const Text('XP and badges will be recalculated without it. You can undo for a few seconds.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: TsColors.danger, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _delete(BuildContext context, ActivityRecord a) async {
    final track = ref.read(trackStoreProvider).load(a.id);
    final activities = ref.read(activitiesProvider.notifier);
    final tracks = ref.read(trackStoreProvider);
    await tracks.delete(a.id);
    await activities.remove(a.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('Deleted "${a.title}"'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          textColor: TsColors.neon,
          onPressed: () async {
            await activities.restore(a);
            if (track != null) await tracks.save(a.id, track);
          },
        ),
      ));
  }

  List<Object> _group(List<ActivityRecord> list) {
    final out = <Object>[];
    String? month;
    for (final a in list) {
      final m = DateFormat('MMMM yyyy').format(a.endedAt);
      if (m != month) {
        month = m;
        final inMonth = list.where((r) => DateFormat('MMMM yyyy').format(r.endedAt) == m);
        out.add(_MonthHeader(m, inMonth.length, inMonth.fold<double>(0, (s, r) => s + r.distanceKm)));
      }
      out.add(_ActivityRow(a));
    }
    return out;
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {IconData? icon}) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: icon == null ? IconPillButton(icon: Icons.all_inclusive, label: label, selected: selected, onTap: onTap) : IconPillButton(icon: icon, label: label, selected: selected, onTap: onTap),
      );

  static String _label(ActivityType t) => ActivityCategory.fromKey(t.name)?.label ?? 'Other';
  static IconData _icon(ActivityType t) => ActivityCategory.fromKey(t.name)?.icon ?? Icons.explore;
}

class _MonthHeader {
  _MonthHeader(this.label, this.count, this.km);
  final String label;
  final int count;
  final double km;
}

class _ActivityRow {
  _ActivityRow(this.record);
  final ActivityRecord record;
}

class _MonthTile extends StatelessWidget {
  const _MonthTile(this.h);
  final _MonthHeader h;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(h.label, style: TsText.h3)),
          Text('${h.count} ${h.count == 1 ? 'activity' : 'activities'} · ${h.km.toStringAsFixed(1)} km', style: TsText.caption),
        ],
      ),
    );
  }
}

class _ActivityTile extends ConsumerWidget {
  const _ActivityTile(this.a);
  final ActivityRecord a;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitsProvider);
    final cat = ActivityCategory.fromKey(a.type.name) ?? ActivityCategory.trekking;
    final d = a.duration;
    return TsCard(
      padding: const EdgeInsets.all(10),
      onTap: () => context.push('/activity/${a.id}'),
      child: Row(
        children: [
          SizedBox(width: 60, height: 60, child: CoverArt(hue: 140 + a.type.index * 9.0, icon: cat.icon, borderRadius: BorderRadius.circular(12))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, style: TsText.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  '${DateFormat('d MMM yyyy').format(a.endedAt)} · ${units.distanceKm(a.distanceKm)} · ${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m',
                  style: TsText.caption,
                ),
              ],
            ),
          ),
          if (a.verified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: TsColors.neon.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999), border: Border.all(color: TsColors.neon.withValues(alpha: 0.6))),
              child: const Text('Verified', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: TsColors.neon)),
            )
          else
            const Icon(Icons.gps_off, size: 16, color: TsColors.textMuted),
        ],
      ),
    );
  }
}
