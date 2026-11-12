import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'tile_cache.dart';

/// Single place to switch tile source. OSM's public servers forbid heavy
/// bulk use; move to MapTiler/Stadia or a self-hosted server before beta.
const tileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const tileUserAgent = 'com.trailseek.trailseek';
const tileAttribution = 'OpenStreetMap contributors';

/// Map "layers": satellite imagery, standard streets, or terrain (contours, trails).
enum MapStyle {
  satellite('Satellite', 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', 'sat', 'Esri, Maxar, Earthstar Geographics'),
  standard('Standard', tileUrlTemplate, 'osm', 'OpenStreetMap contributors'),
  terrain('Terrain', 'https://tile.opentopomap.org/{z}/{x}/{y}.png', 'topo', 'OpenStreetMap contributors, SRTM | map style: OpenTopoMap (CC-BY-SA)');

  const MapStyle(this.label, this.template, this.cacheKey, this.attribution);
  final String label;
  final String template;
  final String cacheKey;
  final String attribution;
  MapStyle get next => values[(index + 1) % values.length];
}

class MapStyleController extends Notifier<MapStyle> {
  @override
  MapStyle build() => MapStyle.satellite;
  void toggle() => state = state.next;
  void select(MapStyle style) => state = style;
}

final mapStyleProvider = NotifierProvider<MapStyleController, MapStyle>(MapStyleController.new);

final tileCacheProvider = FutureProvider<TileCache>((ref) async {
  final dir = await getApplicationSupportDirectory();
  return TileCache(Directory('${dir.path}/tiles'));
});

const _satelliteTint = ColorFilter.matrix([
  0.62, 0.10, 0.00, 0, 0, //
  0.05, 0.78, 0.05, 0, 4,
  0.00, 0.10, 0.58, 0, 6,
  0, 0, 0, 1, 0,
]);

/// The TileLayer every map uses. Falls back to plain network until the cache
/// directory is ready (first frame only).
class TsTileLayer extends ConsumerWidget {
  const TsTileLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.watch(tileCacheProvider).value;
    final style = ref.watch(mapStyleProvider);
    return TileLayer(
      key: ValueKey(style),
      urlTemplate: style.template,
      userAgentPackageName: tileUserAgent,
      tileProvider: cache == null ? null : CachedTileProvider(cache, keyPrefix: style.cacheKey, headers: {'User-Agent': 'TrailSeek/0.3 ($tileUserAgent)'}),
      // Offline with no cached tile: dark panel instead of a broken image.
      errorImage: const AssetImage('assets/images/mountain_silhouette.png'),
      // Satellite: darker and deeper green so neon trails and pins stand out.
      tileBuilder: style == MapStyle.satellite ? (context, tile, _) => ColorFiltered(colorFilter: _satelliteTint, child: tile) : null,
    );
  }
}

/// Attribution follows the active style.
class TsAttribution extends ConsumerWidget {
  const TsAttribution({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      RichAttributionWidget(attributions: [TextSourceAttribution(ref.watch(mapStyleProvider).attribution)], showFlutterMapAttribution: false);
}

const tsAttribution = TsAttribution();
