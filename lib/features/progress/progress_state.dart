import '../../data/models/activity_record.dart';

/// Aggregates the engine derives from the activity list. Badge and
/// achievement rules read only from here, so rules stay declarative.
class ProgressStats {
  ProgressStats();

  int activityCount = 0;
  int verifiedCount = 0;
  final Map<ActivityType, int> byType = {};
  double totalDistanceM = 0;
  int totalGainM = 0;
  int peaksAbove1500 = 0;
  final Set<String> districts = {};
  final Set<String> trailIds = {};
  int groupSessions = 0;
  int ropeSessionsNoSeparation = 0;
  int separationsCaught = 0;
  int earlyStarts = 0; // started before 06:00
  int lateFinishes = 0; // finished after 19:00
  double longestDistanceM = 0;
  int highestAltitudeM = 0;

  int count(ActivityType t) => byType[t] ?? 0;
  double get totalDistanceKm => totalDistanceM / 1000;

  void add(ActivityRecord r) {
    activityCount++;
    if (r.verified) verifiedCount++;
    byType[r.type] = count(r.type) + 1;
    totalDistanceM += r.distanceM;
    totalGainM += r.elevationGainM;
    if (r.maxAltitudeM >= 1500) peaksAbove1500++;
    if (r.district != null && r.district!.isNotEmpty) districts.add(r.district!);
    if (r.trailId != null) trailIds.add(r.trailId!);
    if (r.isGroup) {
      groupSessions++;
      if (r.separations == 0) ropeSessionsNoSeparation++;
      separationsCaught += r.separations;
    }
    if (r.startedAt.hour < 6) earlyStarts++;
    if (r.endedAt.hour >= 19) lateFinishes++;
    if (r.distanceM > longestDistanceM) longestDistanceM = r.distanceM;
    if (r.maxAltitudeM > highestAltitudeM) highestAltitudeM = r.maxAltitudeM;
  }
}

class ProgressState {
  const ProgressState({
    required this.totalXp,
    required this.level,
    required this.xpInLevel,
    required this.xpForLevel,
    required this.title,
    required this.badges,
    required this.achievements,
    required this.appliedActivityIds,
    required this.stats,
    required this.xpByActivity,
  });

  factory ProgressState.empty() => ProgressState(
        totalXp: 0,
        level: 1,
        xpInLevel: 0,
        xpForLevel: 500,
        title: 'Trail Rookie',
        badges: const {},
        achievements: const {},
        appliedActivityIds: const {},
        stats: ProgressStats(),
        xpByActivity: const {},
      );

  final int totalXp;
  final int level;
  final int xpInLevel;
  final int xpForLevel;
  final String title;

  /// badgeId -> activity id that unlocked it.
  final Map<String, String> badges;

  /// achievementId -> activity id that completed it.
  final Map<String, String> achievements;
  final Set<String> appliedActivityIds;
  final ProgressStats stats;
  final Map<String, int> xpByActivity;

  bool hasBadge(String id) => badges.containsKey(id);
  int get badgeCount => badges.length;
  int get achievementCount => achievements.length;
}

/// What changed when one activity was applied. Drives the reward moments (task 14).
class ProgressDelta {
  const ProgressDelta({
    required this.activityId,
    required this.xpGained,
    required this.previousLevel,
    required this.newLevel,
    required this.newBadges,
    required this.achievementsCompleted,
  });

  final String activityId;
  final int xpGained;
  final int previousLevel;
  final int newLevel;
  final List<String> newBadges;
  final List<String> achievementsCompleted;

  bool get leveledUp => newLevel > previousLevel;
  bool get isEmpty => xpGained == 0 && !leveledUp && newBadges.isEmpty && achievementsCompleted.isEmpty;
}
