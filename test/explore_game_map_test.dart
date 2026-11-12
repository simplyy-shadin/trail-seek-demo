import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trailseek/app/providers.dart';
import 'package:trailseek/data/repositories/local_store.dart';
import 'package:trailseek/features/maps/explore_game_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled game styles are genuine geographic vector styles', () async {
    final vectorWorlds = ExploreMapTheme.values
        .where((world) => world.styleUri != null)
        .toList(growable: false);
    expect(ExploreMapTheme.values.length, 7); // 6 game worlds + Classic.
    expect(vectorWorlds.length, 6);

    final backgroundColors = <String>{};
    final trailColors = <String>{};
    for (final theme in vectorWorlds) {
      final path = theme.styleUri!.replaceFirst('asset://', '');
      final data = jsonDecode(await rootBundle.loadString(path))
          as Map<String, dynamic>;
      expect(data['version'], 8);
      final sources = data['sources'] as Map<String, dynamic>;
      final source = sources['openmaptiles'] as Map<String, dynamic>;
      expect(source['type'], 'vector');
      expect(source['url'], 'https://tiles.openfreemap.org/planet/latest');
      final layers = data['layers'] as List<dynamic>;
      expect(layers.length, greaterThan(10));
      expect(
        layers.whereType<Map<String, dynamic>>().any(
          (layer) => layer['id'] == 'adventure-trails',
        ),
        isTrue,
      );
      final ground = layers.cast<Map<String, dynamic>>().firstWhere(
        (layer) => layer['id'] == 'ground',
      );
      final trail = layers.cast<Map<String, dynamic>>().firstWhere(
        (layer) => layer['id'] == 'adventure-trails',
      );
      backgroundColors.add((ground['paint'] as Map)['background-color'] as String);
      trailColors.add((trail['paint'] as Map)['line-color'] as String);

      // All game-world styles remain compatible with imported/offline MBTiles.
      expect(sources.keys, contains('openmaptiles'));
      expect(source['attribution'], contains('OpenStreetMap'));
      expect(
        layers.cast<Map<String, dynamic>>().where(
          (layer) => layer['type'] == 'symbol',
        ).length,
        greaterThanOrEqualTo(3),
      );
      expect(theme.accentColor, isNotNull);
    }
    expect(backgroundColors.length, 6); // Distinct map appearance.
    expect(trailColors.length, 6); // Distinct trail emphasis.
  });

  test('Explore theme defaults to classic and survives provider recreation',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore(prefs);
    final container = ProviderContainer(
      overrides: [localStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(container.read(exploreMapThemeProvider), ExploreMapTheme.classic);
    await container
        .read(exploreMapThemeProvider.notifier)
        .select(ExploreMapTheme.nightTrek);
    expect(store.rawString(ExploreMapThemeController.storageKey), 'nightTrek');

    final reopened = ProviderContainer(
      overrides: [localStoreProvider.overrideWithValue(store)],
    );
    addTearDown(reopened.dispose);
    expect(reopened.read(exploreMapThemeProvider), ExploreMapTheme.nightTrek);
  });

  test('new original game-world choice persists through provider recreation', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore(prefs);
    final container = ProviderContainer(
      overrides: [localStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await container
        .read(exploreMapThemeProvider.notifier)
        .select(ExploreMapTheme.canopyQuest);

    final reopened = ProviderContainer(
      overrides: [localStoreProvider.overrideWithValue(store)],
    );
    addTearDown(reopened.dispose);
    expect(reopened.read(exploreMapThemeProvider), ExploreMapTheme.canopyQuest);
    expect(store.rawString(ExploreMapThemeController.storageKey), 'canopyQuest');
  });

  test('unrecognized stored themes safely fall back to classic', () async {
    SharedPreferences.setMockInitialValues({
      ExploreMapThemeController.storageKey: 'removed_theme',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [localStoreProvider.overrideWithValue(LocalStore(prefs))],
    );
    addTearDown(container.dispose);
    expect(container.read(exploreMapThemeProvider), ExploreMapTheme.classic);
  });
}
