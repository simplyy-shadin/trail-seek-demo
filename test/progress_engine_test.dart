import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/features/progress/progress.dart';

ActivityRecord rec(
  String id, {
  ActivityType type = ActivityType.trekking,
  double km = 5,
  int gain = 300,
  int maxAlt = 900,
  bool verified = true,
  String? trail,
  String? district,
  bool group = false,
  int members = 1,
  int separations = 0,
  DateTime? start,
  Duration duration = const Duration(hours: 3),
}) {
  final s = start ?? DateTime(2026, 4, 12, 7);
  return ActivityRecord(
    id: id,
    type: type,
    title: trail ?? id,
    startedAt: s,
    endedAt: s.add(duration),
    distanceM: km * 1000,
    elevationGainM: gain,
    maxAltitudeM: maxAlt,
    verified: verified,
    trailId: trail,
    district: district,
    groupSessionId: group ? 'g-$id' : null,
    memberCount: group ? members : 1,
    separations: separations,
  );
}

void main() {
  const engine = ProgressEngine();
  const rules = XpRules();
  const levels = LevelTable();

  group('XpRules', () {
    test('worked example from the task: 8.6 km / 720 m group trek, first time on trail', () {
      final r = rec('a', km: 8.6, gain: 720, group: true, members: 8, trail: 'meesapulimala');
      expect(rules.xpFor(r, firstTimeOnTrail: true), 100 + 86 + 35 + 50 + 25);
      expect(rules.xpFor(r, firstTimeOnTrail: false), 100 + 86 + 35 + 50);
    });

    test('unverified activities earn a quarter and XP is capped', () {
      final r = rec('a', km: 8, gain: 400, verified: false);
      expect(rules.xpFor(r, firstTimeOnTrail: false), ((100 + 80 + 20) * 0.25).round());
      final huge = rec('b', km: 500, gain: 20000);
      expect(rules.xpFor(huge, firstTimeOnTrail: false), 1500);
    });
  });

  group('LevelTable', () {
    test('thresholds grow by 250 and titles follow level bands', () {
      expect(levels.xpToNext(1), 500);
      expect(levels.xpToNext(2), 750);
      expect(levels.xpToNext(3), 1000);
      expect(levels.xpToReach(4), 2250);
      expect(LevelTable.titleFor(1), 'Trail Rookie');
      expect(LevelTable.titleFor(3), 'Adventure Seeker');
      expect(LevelTable.titleFor(10), 'Ridge Walker');
      expect(LevelTable.titleFor(25), 'Mountain Legend');
    });

    test('position inside a level, including multi-level jumps', () {
      final p = levels.positionFor(1770); // 500 + 750 = 1250 reached level 3, 520 into it
      expect(p.level, 3);
      expect(p.xpInLevel, 520);
      expect(p.xpForLevel, 1000);
      expect(levels.positionFor(0).level, 1);
      expect(levels.positionFor(10000000).level, 50);
    });
  });

  group('ProgressEngine', () {
    test('empty history is level 1 with nothing unlocked', () {
      final s = engine.rebuild(const []);
      expect(s.level, 1);
      expect(s.badges, isEmpty);
      expect(s.totalXp, 0);
    });

    test('first verified activity unlocks First Trek and reports a delta', () {
      final before = engine.rebuild(const []);
      final (after, delta) = engine.apply(before, const [], rec('a', km: 8.6, gain: 720, trail: 't1'));
      expect(delta.xpGained, 100 + 86 + 35 + 25);
      expect(delta.newBadges, ['first_trek']);
      expect(after.hasBadge('first_trek'), isTrue);
      expect(delta.leveledUp, isFalse);
    });

    test('applying the same activity twice awards nothing', () {
      final a = rec('a');
      final s1 = engine.rebuild([a]);
      final (s2, delta) = engine.apply(s1, [a], a);
      expect(delta.isEmpty, isTrue);
      expect(s2.totalXp, s1.totalXp);
    });

    test('revoking an activity recomputes everything', () {
      final a = rec('a', type: ActivityType.forestWalk);
      final b = rec('b', type: ActivityType.forestWalk);
      final c = rec('c', type: ActivityType.forestWalk);
      final full = engine.rebuild([a, b, c]);
      expect(full.hasBadge('forest_walker'), isTrue);
      final less = engine.revoke([a, b, c], 'c');
      expect(less.hasBadge('forest_walker'), isFalse);
      expect(less.totalXp, full.totalXp - full.xpByActivity['c']!);
    });

    test('level up is detected across several levels at once', () {
      final before = engine.rebuild(const []);
      final big = rec('x', km: 60, gain: 4000, group: true, members: 4, trail: 'long');
      final (after, delta) = engine.apply(before, const [], big);
      expect(delta.xpGained, 100 + 600 + 200 + 50 + 25);
      expect(after.level, 2);
      expect(delta.leveledUp, isTrue);
    });

    test('each badge rule fires on its condition', () {
      final s = engine.rebuild([
        rec('p1', maxAlt: 1600), rec('p2', maxAlt: 1700), rec('p3', maxAlt: 2100),
        rec('c1', type: ActivityType.cycling), rec('c2', type: ActivityType.mountainBiking), rec('c3', type: ActivityType.cycling),
        rec('k1', type: ActivityType.kayaking),
        rec('e1', start: DateTime(2026, 4, 1, 5, 30)),
        rec('n1', start: DateTime(2026, 4, 2, 16), duration: const Duration(hours: 4)),
        for (var i = 0; i < 10; i++) rec('g$i', group: true, members: 5),
      ]);
      for (final id in ['first_trek', 'mountain_explorer', 'cycling_enthusiast', 'kayaking_beginner', 'early_bird', 'night_owl', 'trail_keeper', 'rope_guardian']) {
        expect(s.hasBadge(id), isTrue, reason: id);
      }
      expect(s.hasBadge('forest_walker'), isFalse);
      expect(s.achievements.keys, containsAll(['rope_explorer', 'rope_trail_keeper', 'rope_guardian', 'treks_12']));
      expect(s.achievements.containsKey('rope_summit'), isFalse);
    });

    test('a separation breaks the Rope Guardian streak count', () {
      final s = engine.rebuild([for (var i = 0; i < 10; i++) rec('g$i', group: true, members: 5, separations: i == 3 ? 1 : 0)]);
      expect(s.hasBadge('rope_guardian'), isFalse);
      expect(s.stats.separationsCaught, 1);
    });

    test('badge locked progress reads from stats', () {
      final s = engine.rebuild([rec('f1', type: ActivityType.forestWalk)]);
      final (cur, target) = BadgeCatalog.byId('forest_walker')!.progress!(s.stats);
      expect((cur, target), (1, 3));
    });
  });
}
