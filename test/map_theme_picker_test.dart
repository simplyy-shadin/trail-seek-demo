import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trailseek/app/providers.dart';
import 'package:trailseek/data/repositories/local_store.dart';
import 'package:trailseek/features/maps/explore_game_map.dart';
import 'package:trailseek/features/maps/map_theme_picker.dart';
import 'package:trailseek/features/maps/map_tiles.dart';

Future<(ProviderContainer, LocalStore)> _pumpPicker(
  WidgetTester tester,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = LocalStore(prefs);
  final container = ProviderContainer(
    overrides: [localStoreProvider.overrideWithValue(store)],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMapWorldPicker(context),
              child: const Text('Open map worlds'),
            ),
          ),
        ),
      ),
    ),
  );
  return (container, store);
}

void main() {
  testWidgets('the shared picker persists the selected game map',
      (tester) async {
    final (container, store) = await _pumpPicker(tester);
    addTearDown(container.dispose);
    await tester.tap(find.text('Open map worlds'));
    await tester.pumpAndSettle();
    expect(find.text('Adventure RPG'), findsOneWidget);
    expect(find.text('Night Trek'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('map-world-nightTrek')));
    await tester.pumpAndSettle();
    expect(container.read(exploreMapThemeProvider), ExploreMapTheme.nightTrek);
    expect(
      store.rawString(ExploreMapThemeController.storageKey),
      ExploreMapTheme.nightTrek.name,
    );
  });

  testWidgets('choosing a Classic raster layer restores the Classic world',
      (tester) async {
    final (container, _) = await _pumpPicker(tester);
    addTearDown(container.dispose);
    await container
        .read(exploreMapThemeProvider.notifier)
        .select(ExploreMapTheme.adventureRpg);
    await tester.tap(find.text('Open map worlds'));
    await tester.pumpAndSettle();
    final terrain = find.byKey(const ValueKey('classic-layer-terrain'));
    await tester.ensureVisible(terrain);
    await tester.pumpAndSettle();
    await tester.tap(terrain);
    await tester.pumpAndSettle();

    expect(container.read(exploreMapThemeProvider), ExploreMapTheme.classic);
    expect(container.read(mapStyleProvider), MapStyle.terrain);
  });
}
