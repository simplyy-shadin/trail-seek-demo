import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trailseek/app/providers.dart';
import 'package:trailseek/core/units.dart';
import 'package:trailseek/data/models/activity_record.dart';
import 'package:trailseek/data/repositories/local_store.dart';
import 'package:trailseek/features/settings/settings_controller.dart';

void main() {
  test('units formatter switches systems', () {
    const m = Units(metric: true);
    const i = Units(metric: false);
    expect(m.distanceKm(8.6), '8.6 km');
    expect(i.distanceKm(8.6), '5.3 mi');
    expect(m.elevationM(720), '720 m');
    expect(i.elevationM(720), '2362 ft');
    expect(m.pace(const Duration(minutes: 60), 5000), '12:00');
    expect(m.pace(const Duration(minutes: 60), 10), '—');
  });

  test('settings persist and units provider follows', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [localStoreProvider.overrideWithValue(LocalStore(prefs))]);
    addTearDown(c.dispose);
    expect(c.read(unitsProvider).metric, isTrue);
    await c.read(settingsProvider.notifier).update((s) => s.copyWith(metric: false, weeklySummary: true));
    expect(c.read(unitsProvider).metric, isFalse);

    final c2 = ProviderContainer(overrides: [localStoreProvider.overrideWithValue(LocalStore(prefs))]);
    addTearDown(c2.dispose);
    expect(c2.read(settingsProvider).metric, isFalse);
    expect(c2.read(settingsProvider).weeklySummary, isTrue);
  });

  test('CSV export has a header and one quoted row per activity', () {
    final csv = activitiesCsv([
      ActivityRecord(
        id: 'a1',
        type: ActivityType.trekking,
        title: 'Chembra "heart" lake',
        startedAt: DateTime(2026, 4, 12, 6),
        endedAt: DateTime(2026, 4, 12, 9),
        distanceM: 7000,
        elevationGainM: 600,
        maxAltitudeM: 2100,
        verified: true,
        district: 'Wayanad',
      ),
    ]);
    final lines = csv.trim().split('\n');
    expect(lines.length, 2);
    expect(lines.first.startsWith('id,type,title,'), isTrue);
    expect(lines[1], contains('"Chembra ""heart"" lake"'));
    expect(lines[1], contains('7000.0,600,2100,true'));
  });

  test('wipeUserData keeps onboarding and region only', () async {
    SharedPreferences.setMockInitialValues({'onboarded': true, 'region': 'kerala', 'user': '{}', 'activities': '[]', 'settings': '{}'});
    final store = LocalStore(await SharedPreferences.getInstance());
    await store.wipeUserData();
    expect(store.onboarded, isTrue);
    expect(store.regionId, 'kerala');
    expect(store.user, isNull);
    expect(store.activities, isEmpty);
  });
}
