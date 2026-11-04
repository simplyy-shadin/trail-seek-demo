import '../../data/models/activity_record.dart';
import 'progress_state.dart';

/// A badge is a one-time unlock evaluated against [ProgressStats].
class BadgeDef {
  const BadgeDef({
    required this.id,
    required this.title,
    required this.description,
    required this.iconKey,
    required this.rule,
    this.progress,
  });

  final String id;
  final String title;
  final String description;

  /// Icon name resolved by the UI (keeps this file free of Flutter).
  final String iconKey;
  final bool Function(ProgressStats s) rule;

  /// Optional "x of y" progress for the locked state.
  final (int current, int target) Function(ProgressStats s)? progress;
}

class BadgeCatalog {
  static final List<BadgeDef> all = [
    BadgeDef(
      id: 'first_trek',
      title: 'First Trek Completed',
      description: 'Finish your first verified activity.',
      iconKey: 'flag',
      rule: (s) => s.verifiedCount >= 1,
      progress: (s) => (s.verifiedCount.clamp(0, 1), 1),
    ),
    BadgeDef(
      id: 'mountain_explorer',
      title: 'Mountain Explorer',
      description: 'Reach three peaks above 1,500 m.',
      iconKey: 'terrain',
      rule: (s) => s.peaksAbove1500 >= 3,
      progress: (s) => (s.peaksAbove1500.clamp(0, 3), 3),
    ),
    BadgeDef(
      id: 'forest_walker',
      title: 'Forest Walker',
      description: 'Complete three forest walks.',
      iconKey: 'forest',
      rule: (s) => s.count(ActivityType.forestWalk) >= 3,
      progress: (s) => (s.count(ActivityType.forestWalk).clamp(0, 3), 3),
    ),
    BadgeDef(
      id: 'cycling_enthusiast',
      title: 'Cycling Enthusiast',
      description: 'Complete three rides.',
      iconKey: 'pedal_bike',
      rule: (s) => s.count(ActivityType.cycling) + s.count(ActivityType.mountainBiking) >= 3,
      progress: (s) => ((s.count(ActivityType.cycling) + s.count(ActivityType.mountainBiking)).clamp(0, 3), 3),
    ),
    BadgeDef(
      id: 'kayaking_beginner',
      title: 'Kayaking Beginner',
      description: 'Finish your first paddle.',
      iconKey: 'kayaking',
      rule: (s) => s.count(ActivityType.kayaking) + s.count(ActivityType.rafting) >= 1,
      progress: (s) => ((s.count(ActivityType.kayaking) + s.count(ActivityType.rafting)).clamp(0, 1), 1),
    ),
    BadgeDef(
      id: 'early_bird',
      title: 'Early Bird',
      description: 'Start an activity before 6 AM.',
      iconKey: 'wb_twilight',
      rule: (s) => s.earlyStarts >= 1,
    ),
    BadgeDef(
      id: 'night_owl',
      title: 'Night Owl',
      description: 'Finish an activity after 7 PM.',
      iconKey: 'nightlight',
      rule: (s) => s.lateFinishes >= 1,
    ),
    BadgeDef(
      id: 'trail_keeper',
      title: 'Trail Keeper',
      description: 'Complete five group sessions.',
      iconKey: 'groups',
      rule: (s) => s.groupSessions >= 5,
      progress: (s) => (s.groupSessions.clamp(0, 5), 5),
    ),
    BadgeDef(
      id: 'rope_guardian',
      title: 'Rope Guardian',
      description: 'Ten Digital Rope sessions with nobody separated.',
      iconKey: 'link',
      rule: (s) => s.ropeSessionsNoSeparation >= 10,
      progress: (s) => (s.ropeSessionsNoSeparation.clamp(0, 10), 10),
    ),
  ];

  static BadgeDef? byId(String id) {
    for (final b in all) {
      if (b.id == id) return b;
    }
    return null;
  }
}
