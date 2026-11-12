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
    for (final theme in [
      ExploreMapTheme.adventureRpg,
      ExploreMapTheme.nightTrek,
    ]) {
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
    }
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
