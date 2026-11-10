import '../../data/models/activity_record.dart';
import 'achievements.dart';
import 'badges.dart';
import 'level_table.dart';
import 'progress_state.dart';
import 'xp_rules.dart';

/// Deterministic: progress is always a pure function of the activity list.
/// `apply` = rebuild with one more record, `revoke` = rebuild without it.
/// That makes idempotency and deletion trivial and keeps the server (task 16)
/// able to recompute the same numbers.
class ProgressEngine {
  const ProgressEngine({this.rules = const XpRules(), this.levels = const LevelTable()});

  final XpRules rules;
  final LevelTable levels;

  ProgressState rebuild(Iterable<ActivityRecord> records) {
    final seen = <String>{};
    final ordered = records.where((r) => seen.add(r.id)).toList()..sort((a, b) => a.endedAt.compareTo(b.endedAt));

    final stats = ProgressStats();
    final badges = <String, String>{};
    final achievements = <String, String>{};
    final xpBy = <String, int>{};
    final trailsSeen = <String>{};
    var totalXp = 0;

    for (final r in ordered) {
      // Demo treks (pretend members) and two-minute strolls earn nothing.
      if (r.isTrivial || r.simulated) {
        xpBy[r.id] = 0;
        continue;
      }
      final first = r.trailId != null && trailsSeen.add(r.trailId!);
      final xp = rules.xpFor(r, firstTimeOnTrail: first);
      xpBy[r.id] = xp;
      totalXp += xp;
      stats.add(r);
      for (final b in BadgeCatalog.all) {
        if (!badges.containsKey(b.id) && b.rule(stats)) badges[b.id] = r.id;
      }
      for (final a in AchievementCatalog.all) {
        if (!achievements.containsKey(a.id) && a.isComplete(stats)) achievements[a.id] = r.id;
      }
    }

    final pos = levels.positionFor(totalXp);
    return ProgressState(
      totalXp: totalXp,
      level: pos.level,
      xpInLevel: pos.xpInLevel,
      xpForLevel: pos.xpForLevel,
      title: pos.title,
      badges: badges,
      achievements: achievements,
      appliedActivityIds: ordered.map((r) => r.id).toSet(),
      stats: stats,
      xpByActivity: xpBy,
    );
  }

  /// Returns the new state and what changed. Applying an id that is already
  /// present changes nothing.
  (ProgressState, ProgressDelta) apply(ProgressState current, List<ActivityRecord> history, ActivityRecord record) {
    if (current.appliedActivityIds.contains(record.id)) {
      return (current, ProgressDelta(activityId: record.id, xpGained: 0, previousLevel: current.level, newLevel: current.level, newBadges: const [], achievementsCompleted: const []));
    }
    final next = rebuild([...history, record]);
    return (
      next,
      ProgressDelta(
        activityId: record.id,
        xpGained: next.totalXp - current.totalXp,
        previousLevel: current.level,
        newLevel: next.level,
        newBadges: next.badges.keys.where((id) => !current.badges.containsKey(id)).toList(),
        achievementsCompleted: next.achievements.keys.where((id) => !current.achievements.containsKey(id)).toList(),
      ),
    );
  }

  ProgressState revoke(List<ActivityRecord> history, String activityId) =>
      rebuild(history.where((r) => r.id != activityId));
}
