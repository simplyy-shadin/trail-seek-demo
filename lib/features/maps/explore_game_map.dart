import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_map_vector_tiles_mbtiles/flutter_map_vector_tiles_mbtiles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'map_tiles.dart';
import 'offline_vector_packs.dart';

/// Shared map appearance for Explore, live Solo Tracking, Digital Rope and
/// the route preview. The historical preference key is retained to preserve
/// existing users' Explore selections after this app-wide rollout.
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
  ),
  monsoonMist(
    'Monsoon Mist',
    'Rain-washed forests, misty roads and teal-blue rivers',
    Icons.cloud,
    'asset://assets/maps/styles/monsoon_mist.json',
  ),
  highlandQuest(
    'Highland Quest',
    'Mountain meadows, warm rock and bold ochre trails',
    Icons.landscape,
    'asset://assets/maps/styles/highland_quest.json',
  ),
  coastalExplorer(
    'Coastal Explorer',
    'Sandy shores, sea-green vegetation and bright waterways',
    Icons.waves,
    'asset://assets/maps/styles/coastal_explorer.json',
  ),
  canopyQuest(
    'Canopy Quest',
    'Deep jungle greens with glowing golden expedition trails',
    Icons.park,
    'asset://assets/maps/styles/canopy_quest.json',
  );

  const ExploreMapTheme(this.label, this.description, this.icon, this.styleUri);

  final String label;
  final String description;
  final IconData icon;
  final String? styleUri;

  /// Contrasting location-marker/preview accent for each map world.
  /// Independent of the safety/route marker colors (Digital Rope is unchanged).
  Color get accentColor => switch (this) {
    ExploreMapTheme.classic => const Color(0xFF496E7C),
    ExploreMapTheme.adventureRpg => const Color(0xFF985538),
    ExploreMapTheme.nightTrek => const Color(0xFF94E9B2),
    ExploreMapTheme.monsoonMist => const Color(0xFF236D78),
    ExploreMapTheme.highlandQuest => const Color(0xFF9B5C32),
    ExploreMapTheme.coastalExplorer => const Color(0xFF16759C),
    ExploreMapTheme.canopyQuest => const Color(0xFFC77B2E),
  };
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

/// A user-selected local MBTiles archive replaces only the vector source
/// named openmaptiles. All six game-world style JSON assets are bundled, and no vector tile
/// requests are made to OpenFreeMap while this provider is selected.
final offlineGameVectorStyleProvider =
    FutureProvider.family<vt.Style, (ExploreMapTheme, String)>(
  (ref, selection) async {
    final (theme, path) = selection;
    final uri = theme.styleUri;
    if (uri == null) throw StateError('Classic has no vector tiles');

    final archive = await MbTilesVectorTileProvider.open(path);
    try {
      final style = await vt.StyleReader(
        uri: uri,
        resolveProvider: (id) async => id == 'openmaptiles' ? archive : null,
      ).read();
      ref.onDispose(style.dispose);
      return style;
    } catch (_) {
      archive.dispose();
      rethrow;
    }
  },
);

/// Substitutes a styled vector basemap without changing any map overlays,
/// recorded route geometry, member positions or safety alert state.
class ExploreGameTileLayer extends ConsumerWidget {
  const ExploreGameTileLayer({super.key, required this.theme});

  final ExploreMapTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPack = ref.watch(offlineVectorPacksProvider).active;
    final loaded = selectedPack == null
        ? ref.watch(exploreVectorStyleProvider(theme))
        : ref.watch(offlineGameVectorStyleProvider((theme, selectedPack.path)));
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

/// Map theme shared by all FlutterMap screens. The original raster layer is
/// always available, even before a vector style has finished loading.
class ThemedMapBaseLayer extends ConsumerWidget {
  const ThemedMapBaseLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = ref.watch(exploreMapThemeProvider);
    return world == ExploreMapTheme.classic
        ? const TsTileLayer()
        : ExploreGameTileLayer(theme: world);
  }
}

/// Source credit follows the actual selected base map on every screen.
class ThemedMapAttribution extends ConsumerWidget {
  const ThemedMapAttribution({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = ref.watch(exploreMapThemeProvider);
    final pack = ref.watch(offlineVectorPacksProvider).active;
    if (world == ExploreMapTheme.classic) return tsAttribution;
    if (pack != null) {
      return SimpleAttributionWidget(
        source: Text('Offline MBTiles · ${pack.attribution ?? 'Map data attribution in pack details'}'),
      );
    }
    return const SimpleAttributionWidget(
      source: Text('OpenFreeMap © OpenMapTiles · Data from OpenStreetMap'),
    );
  }
}
