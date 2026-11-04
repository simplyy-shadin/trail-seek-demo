import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/activity_category.dart';
import '../../data/models/adventure.dart';

/// Searchable trail picker used wherever a flow needs "which adventure?":
/// group creation, Start Trek, attaching an activity. Scales to hundreds of
/// trails: search by name/district/town, filter by activity, lazy list.
Future<Adventure?> showAdventurePicker(BuildContext context, {String title = 'Choose adventure', bool allowNone = false, String noneLabel = 'No trail'}) {
  return showModalBottomSheet<Adventure?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AdventurePickerSheet(title: title, allowNone: allowNone, noneLabel: noneLabel),
  );
}

class _AdventurePickerSheet extends ConsumerStatefulWidget {
  const _AdventurePickerSheet({required this.title, required this.allowNone, required this.noneLabel});
  final String title;
  final bool allowNone;
  final String noneLabel;
  @override
  ConsumerState<_AdventurePickerSheet> createState() => _AdventurePickerSheetState();
}

class _AdventurePickerSheetState extends ConsumerState<_AdventurePickerSheet> {
  String _query = '';
  ActivityCategory? _category;
  Difficulty? _difficulty;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(adventuresProvider).value ?? const <Adventure>[];
    final q = _query.trim().toLowerCase();
    final list = all.where((a) {
      if (_category != null && !a.categories.contains(_category)) return false;
      if (_difficulty != null && a.difficulty != _difficulty) return false;
      if (q.isEmpty) return true;
      return a.name.toLowerCase().contains(q) || (a.destinationName ?? '').toLowerCase().contains(q) || a.nearestTown.toLowerCase().contains(q) || a.programType.label.toLowerCase().contains(q);
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (ctx, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text(widget.title, style: TsText.h2)),
                    Text('${list.length} of ${all.length}', style: TsText.caption),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  autofocus: false,
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 150), () => setState(() => _query = v));
                  },
                  decoration: const InputDecoration(hintText: 'Search programmes or destinations', prefixIcon: Icon(Icons.search), isDense: true),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      IconPillButton(icon: Icons.all_inclusive, label: 'All', selected: _category == null, onTap: () => setState(() => _category = null)),
                      for (final c in ActivityCategory.values.where((c) => all.any((a) => a.categories.contains(c)))) ...[
                        const SizedBox(width: 6),
                        IconPillButton(icon: c.icon, label: c.label, selected: _category == c, onTap: () => setState(() => _category = _category == c ? null : c)),
                      ],
                      const SizedBox(width: 12),
                      for (final d in Difficulty.values) ...[
                        const SizedBox(width: 6),
                        IconPillButton(icon: Icons.flag_outlined, label: d.label, selected: _difficulty == d, onTap: () => setState(() => _difficulty = _difficulty == d ? null : d)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: list.length + (widget.allowNone ? 1 : 0),
              itemBuilder: (_, i) {
                if (widget.allowNone && i == 0) {
                  return ListTile(
                    leading: const Icon(Icons.explore_off_outlined, color: TsColors.textMuted),
                    title: Text(widget.noneLabel),
                    onTap: () => Navigator.pop(ctx, null),
                  );
                }
                final a = list[i - (widget.allowNone ? 1 : 0)];
                return ListTile(
                  leading: SizedBox(width: 44, height: 44, child: AdventureCover.of(a, borderRadius: BorderRadius.circular(10))),
                  title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${a.destinationName ?? a.district} · ${a.distanceLabel} · ${a.durationLabel} · ${a.pricing.shortLabel}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: DifficultyChip(a.difficulty, dense: true),
                  onTap: () => Navigator.pop(ctx, a),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
