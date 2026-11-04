import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/group_session.dart';
import '../rope/rope_controller.dart';

/// Groups tab root: live group, upcoming lobbies, past sessions, create/join.
/// Task 12 adds the guide view on top of this.
class GroupsTab extends ConsumerWidget {
  const GroupsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(groupProvider);
    final active = sessions.where((s) => s.status == SessionStatus.active).toList();
    final upcoming = sessions.where((s) => s.status == SessionStatus.lobby || s.status == SessionStatus.checklist).toList();
    final past = sessions.where((s) => s.status == SessionStatus.completed || s.status == SessionStatus.cancelled).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Groups'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          if (sessions.isEmpty)
            TsCard(
              child: Column(
                children: [
                  const Icon(Icons.link, size: 44, color: TsColors.neon),
                  const SizedBox(height: 10),
                  const Text('Go together, stay together', style: TsText.h2, textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  const Text(
                    'Create a group for your next trek. Digital Rope keeps every phone linked and warns you before someone is left behind.',
                    style: TsText.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          for (final s in active) _SessionTile(s, live: true),
          if (upcoming.isNotEmpty) const SectionHeader('Upcoming'),
          for (final s in upcoming) _SessionTile(s),
          if (past.isNotEmpty) const SectionHeader('Past'),
          for (final s in past) _SessionTile(s),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            Expanded(child: NeonButton(label: 'Create Group', icon: Icons.add, onPressed: () => context.push('/group/create'))),
            const SizedBox(width: 10),
            Expanded(child: GhostButton(label: 'Join', icon: Icons.qr_code_scanner, onPressed: () => context.push('/group/join'))),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile(this.s, {this.live = false});
  final GroupSession s;
  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = switch (s.status) {
      SessionStatus.active => '/group/${s.id}/live',
      SessionStatus.completed => '/group/${s.id}/summary',
      SessionStatus.checklist => '/group/${s.id}/checklist',
      _ => '/group/${s.id}/lobby',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TsCard(
        highlighted: live,
        onTap: () => context.push(route),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: (live ? TsColors.neon : TsColors.surfaceHigh).withValues(alpha: live ? 0.18 : 1),
              ),
              child: Icon(live ? Icons.sensors : Icons.groups, color: live ? TsColors.neon : TsColors.textMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(s.name, style: TsText.h3, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (live)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: TsColors.neon, borderRadius: BorderRadius.circular(999)),
                          child: const Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: TsColors.onNeon)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${s.adventureName} · ${DateFormat('d MMM').format(s.date)} · ${s.members.length} members · ${s.code}',
                    style: TsText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Delete group',
              icon: const Icon(Icons.delete_outline, color: TsColors.textMuted),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text('${s.name} will be removed from this phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: TsColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    if (ref.read(ropeProvider)?.session.id == s.id) await ref.read(ropeProvider.notifier).end();
    await ref.read(groupProvider.notifier).delete(s.id);
  }
}
