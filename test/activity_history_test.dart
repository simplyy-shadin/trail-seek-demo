import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trailseek/app/providers.dart';
import 'package:trailseek/app/theme.dart';
import 'package:trailseek/data/models/activity_record.dart';
import 'package:trailseek/data/repositories/local_store.dart';
import 'package:trailseek/features/activity/activity_history_screen.dart';

List<ActivityRecord> synthetic(int n) => [
      for (var i = 0; i < n; i++)
        ActivityRecord(
          id: 'a$i',
          type: ActivityType.values[i % 4],
          title: 'Activity $i',
          startedAt: DateTime(2026, 1, 1).add(Duration(days: i, hours: 6)),
          endedAt: DateTime(2026, 1, 1).add(Duration(days: i, hours: 9)),
          distanceM: 4000 + i * 10,
          elevationGainM: 200,
          maxAltitudeM: 900,
          verified: i.isEven,
        ),
    ];

void main() {
  Future<ProviderContainer> pumpHistory(WidgetTester tester, List<ActivityRecord> records) async {
    SharedPreferences.setMockInitialValues({'activities': jsonEncode(records.map((e) => e.toJson()).toList())});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [localStoreProvider.overrideWithValue(LocalStore(prefs))]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildTheme(), home: const ActivityHistoryScreen()),
    ));
    await tester.pump();
    return container;
  }

  testWidgets('200 activities render lazily with month headers and filters', (tester) async {
    await pumpHistory(tester, synthetic(200));
    expect(find.text('My Activities'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Trekking'), findsOneWidget);
    // Only a screenful is built, not all 200 tiles.
    expect(find.textContaining('Activity '), findsAtLeast(3));
    expect(tester.widgetList(find.textContaining('Activity ')).length, lessThan(40));
    expect(find.textContaining('activities ·'), findsAtLeast(1));
  });

  testWidgets('type filter narrows the list', (tester) async {
    await pumpHistory(tester, synthetic(8));
    await tester.tap(find.text('Hiking'));
    await tester.pump();
    for (final w in tester.widgetList<Text>(find.textContaining('Activity '))) {
      final idx = int.parse(w.data!.split(' ').last);
      expect(ActivityType.values[idx % 4], ActivityType.hiking);
    }
  });

  testWidgets('deleting an activity recomputes XP, undo restores it', (tester) async {
    final container = await pumpHistory(tester, synthetic(3));
    final before = container.read(progressProvider).totalXp;
    expect(before, greaterThan(0));

    await container.read(activitiesProvider.notifier).remove('a0');
    final after = container.read(progressProvider).totalXp;
    expect(after, lessThan(before));
    expect(container.read(activitiesProvider).length, 2);

    final removed = synthetic(3).first;
    await container.read(activitiesProvider.notifier).restore(removed);
    expect(container.read(progressProvider).totalXp, before);
    expect(container.read(activitiesProvider).length, 3);
  });

  testWidgets('empty state offers to start a trek', (tester) async {
    await pumpHistory(tester, const []);
    expect(find.text('No activities yet'), findsOneWidget);
    expect(find.text('Start Trek'), findsOneWidget);
  });
}
