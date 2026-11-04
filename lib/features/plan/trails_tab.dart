import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/group_session.dart';
import '../../data/models/session_summary.dart';

class TrailsTab extends ConsumerWidget {
  const TrailsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final sessions = ref.watch(groupProvider);
    final active = ref.watch(activeSessionProvider);
    final upcoming = sessions.where((s) => s.status == SessionStatus.lobby || s.status == SessionStatus.checklist).toList();
    final current = Milestone.current(history.completed);
    final next = Milestone.next(history.completed);

    return Scaffold(
      appBar: AppBar(title: const Text('My Trails')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          if (active != null)
            Card(
              color: TsColors.primary,
              child: ListTile(
                leading: const Icon(Icons.sensors),
                title: Text(active.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('Digital Rope running · ${active.members.length} members'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/group/${active.id}/live'),
              ),
            ),
          const SectionTitle('Milestones'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: TsColors.surface, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.military_tech, color: TsColors.amber, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(current?.title ?? 'First steps', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text(
                            next == null
                                ? '${history.completed} group sessions completed'
                                : '${history.completed} of ${next.sessions} sessions toward ${next.title}',
                            style: const TextStyle(color: TsColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: next == null ? 1 : history.completed / next.sessions,
                    minHeight: 8,
                    color: TsColors.amber,
                    backgroundColor: TsColors.surfaceHigh,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  history.freeSessionsRemaining > 0
                      ? '${history.freeSessionsRemaining} free Digital Rope sessions remaining'
                      : 'Free sessions used. Session passes arrive after beta.',
                  style: const TextStyle(fontSize: 12, color: TsColors.muted),
                ),
              ],
            ),
          ),
          if (upcoming.isNotEmpty) ...[
            const SectionTitle('Upcoming groups'),
            for (final s in upcoming)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.groups, color: TsColors.green),
                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${s.adventureName} · ${DateFormat('d MMM').format(s.date)} · code ${s.code}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/group/${s.id}/lobby'),
                ),
              ),
          ],
          const SectionTitle('History'),
          if (history.summaries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Completed group adventures will show up here.',
                  textAlign: TextAlign.center, style: TextStyle(color: TsColors.muted)),
            ),
          for (final h in history.summaries) _HistoryTile(h),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile(this.h);
  final SessionSummary h;
  @override
  Widget build(BuildContext context) {
    final d = Duration(seconds: h.durationSeconds);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(h.separationEvents == 0 ? Icons.check_circle : Icons.link_off,
            color: h.separationEvents == 0 ? TsColors.green : TsColors.amber),
        title: Text(h.adventureName, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${DateFormat('d MMM yyyy').format(h.endedAt)} · ${h.memberCount} members · '
          '${h.distanceKm} km · ${d.inHours}h ${d.inMinutes % 60}m'
          '${h.simulated ? ' · demo' : ''}',
        ),
        trailing: Text('${h.separationEvents}', style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}
