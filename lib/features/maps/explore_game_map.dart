import 'package:flutter/material.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'map_tiles.dart';

/// Explore-only map appearance. Safety and tracking maps retain their
/// independent raster style settings until the themed map is field-tested.
enum ExploreMapTheme {
  classic('Classic', 'Existing map layers', Icons.public, null),
  adventureRpg(
    'Adventure RPG',
    'Forest greens, parchment ground and illustrated-style trails',
    Icons.terrain,
    'asset://assets/maps/styles/adventure_rpg.json',
  ),
  nightTrek(
    'Night Trek',
    'Dark terrain with bright paths and readable place names',
    Icons.nightlight_round,
    'asset://assets/maps/styles/night_trek.json',
  );

  const ExploreMapTheme(this.label, this.description, this.icon, this.styleUri);

  final String label;
  final String description;
  final IconData icon;
  final String? styleUri;
}

class ExploreMapThemeController extends Notifier<ExploreMapTheme> {
  static const storageKey = 'explore_map_theme';

  @override
  ExploreMapTheme build() {
    final stored = ref.read(localStoreProvider).rawString(storageKey);
    for (final theme in ExploreMapTheme.values) {
      if (theme.name == stored) return theme;
    }
    return ExploreMapTheme.classic;
  }

  Future<void> select(ExploreMapTheme theme) async {
    state = theme;
    await ref.read(localStoreProvider).setRaw(storageKey, theme.name);
  }
}

final exploreMapThemeProvider =
    NotifierProvider<ExploreMapThemeController, ExploreMapTheme>(
      ExploreMapThemeController.new,
    );

/// Styles are loaded once per theme and cached by Riverpod. Each JSON asset
/// references real OpenMapTiles vector geography via OpenFreeMap TileJSON.
final exploreVectorStyleProvider =
    FutureProvider.family<vt.Style, ExploreMapTheme>((ref, theme) async {
  final uri = theme.styleUri;
  if (uri == null) throw StateError('Classic theme does not use vector tiles');
  final style = await vt.StyleReader(uri: uri).read();
  ref.onDispose(style.dispose);
  return style;
});

/// Substitutes the styled vector basemap while leaving destination pins and
/// all other flutter_map overlays in the original MapTab untouched.
class ExploreGameTileLayer extends ConsumerWidget {
  const ExploreGameTileLayer({super.key, required this.theme});

  final ExploreMapTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loaded = ref.watch(exploreVectorStyleProvider(theme));
    return loaded.when(
      data: (style) => vt.VectorTileLayer(
        theme: style.theme,
        tileProviders: style.providers,
        rasterSources: style.rasterSources,
        sprites: style.sprites,
        glyphs: style.glyphs,
      ),
      // A broken style or a first-time offline load never leaves a blank map.
      loading: () => const TsTileLayer(),
      error: (error, stackTrace) => const TsTileLayer(),
    );
  }
}
