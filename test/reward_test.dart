import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trailseek/app/providers.dart';
import 'package:trailseek/app/theme.dart';
import 'package:trailseek/data/repositories/local_store.dart';
import 'package:trailseek/features/progress/progress.dart';
import 'package:trailseek/features/progress/reward_host.dart';

ActivityRecord big(String id) => ActivityRecord(
      id: id,
      type: ActivityType.trekking,
      title: 'Big one',
      startedAt: DateTime(2026, 4, 12, 5, 30),
      endedAt: DateTime(2026, 4, 12, 12),
      distanceM: 30000,
      elevationGainM: 2000,
      maxAltitudeM: 2100,
      verified: true,
      trailId: 'x',
    );

void main() {
  test('events fire in order: XP, level up, badges', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [localStoreProvider.overrideWithValue(LocalStore(prefs))]);
    addTearDown(c.dispose);
    final seen = <String>[];
    final sub = c.read(activitiesProvider.notifier).events.listen((e) => seen.add(e.runtimeType.toString()));
    final delta = await c.read(activitiesProvider.notifier).add(big('a'));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(delta.xpGained, 100 + 300 + 100 + 25);
    expect(delta.leveledUp, isTrue);
    expect(seen.take(2), ['XpGainedEvent', 'LevelUpEvent']);
    expect(seen.where((s) => s == 'BadgeUnlockedEvent').length, 2); // first_trek + early_bird
  });

  testWidgets('Level Up screen renders the delta and continues', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const delta = ProgressDelta(activityId: 'a', xpGained: 525, previousLevel: 1, newLevel: 2, newBadges: ['first_trek'], achievementsCompleted: []);
    await tester.pumpWidget(ProviderScope(
      overrides: [localStoreProvider.overrideWithValue(LocalStore(prefs))],
      child: MaterialApp(
        theme: buildTheme(),
        home: const MediaQuery(data: MediaQueryData(disableAnimations: true), child: LevelUpScreen(delta: delta)),
      ),
    ));
    await tester.pump();
    expect(find.text('Level Up!'), findsOneWidget);
    expect(find.text("You've reached Level 2"), findsOneWidget);
    expect(find.text('+525 XP'), findsOneWidget);
    expect(find.text('First Trek Completed'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
