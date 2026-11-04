import 'progress_state.dart';

/// Long-running counters with a target. Includes the product plan's
/// 3 / 5 / 10 / 20 group-session milestone ladder.
class AchievementDef {
  const AchievementDef({required this.id, required this.title, required this.target, required this.current, this.reward});
  final String id;
  final String title;
  final int target;
  final int Function(ProgressStats s) current;
  final String? reward;

  bool isComplete(ProgressStats s) => current(s) >= target;
}

class AchievementCatalog {
  static final List<AchievementDef> all = [
    AchievementDef(id: 'treks_12', title: 'Complete 12 activities', target: 12, current: (s) => s.activityCount),
    AchievementDef(id: 'distance_100km', title: 'Walk 100 km', target: 100, current: (s) => s.totalDistanceKm.floor()),
    AchievementDef(id: 'gain_5000m', title: 'Climb 5,000 m', target: 5000, current: (s) => s.totalGainM),
    AchievementDef(id: 'districts_5', title: 'Explore 5 districts', target: 5, current: (s) => s.districts.length),
    AchievementDef(id: 'rope_explorer', title: 'Digital Rope Explorer', target: 3, current: (s) => s.groupSessions, reward: 'Digital badge and share card'),
    AchievementDef(id: 'rope_trail_keeper', title: 'Trail Keeper', target: 5, current: (s) => s.groupSessions, reward: 'Digital badge'),
    AchievementDef(id: 'rope_guardian', title: 'Rope Guardian', target: 10, current: (s) => s.groupSessions, reward: 'Sponsor coupon where available'),
    AchievementDef(id: 'rope_summit', title: 'Summit Circle', target: 20, current: (s) => s.groupSessions, reward: 'Limited sponsor-funded patch'),
  ];

  static AchievementDef? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
