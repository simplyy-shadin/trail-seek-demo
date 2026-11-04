import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/adventure.dart';
import 'map_tiles.dart';
import 'tile_cache.dart';
import 'tile_math.dart';

class OfflineArea {
  const OfflineArea({
    required this.id,
    required this.name,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    required this.minZoom,
    required this.maxZoom,
    required this.tileCount,
    required this.bytes,
    required this.createdAt,
  });

  factory OfflineArea.fromJson(Map<String, dynamic> j) => OfflineArea(
        id: j['id'] as String,
        name: j['name'] as String,
        south: (j['south'] as num).toDouble(),
        west: (j['west'] as num).toDouble(),
        north: (j['north'] as num).toDouble(),
        east: (j['east'] as num).toDouble(),
        minZoom: j['minZoom'] as int,
        maxZoom: j['maxZoom'] as int,
        tileCount: j['tileCount'] as int,
        bytes: j['bytes'] as int,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  final String id;
  final String name;
  final double south, west, north, east;
  final int minZoom, maxZoom;
  final int tileCount;
  final int bytes;
  final DateTime createdAt;

  List<TileId> tiles() => tilesFor(south: south, west: west, north: north, east: east, minZoom: minZoom, maxZoom: maxZoom);

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'south': south, 'west': west, 'north': north, 'east': east,
        'minZoom': minZoom, 'maxZoom': maxZoom, 'tileCount': tileCount, 'bytes': bytes, 'createdAt': createdAt.toIso8601String(),
      };
}

@immutable
class OfflineMapsState {
  const OfflineMapsState({this.areas = const [], this.progress = const {}, this.cacheBytes = 0, this.error});
  final List<OfflineArea> areas;

  /// areaId -> 0..1 while downloading.
  final Map<String, double> progress;
  final int cacheBytes;
  final String? error;

  bool has(String id) => areas.any((a) => a.id == id);
  bool downloading(String id) => progress.containsKey(id);

  OfflineMapsState copyWith({List<OfflineArea>? areas, Map<String, double>? progress, int? cacheBytes, String? error, bool clearError = false}) => OfflineMapsState(
        areas: areas ?? this.areas,
        progress: progress ?? this.progress,
        cacheBytes: cacheBytes ?? this.cacheBytes,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Downloads and tracks per-trail tile areas on top of the shared [TileCache].
class OfflineMapsController extends Notifier<OfflineMapsState> {
  static const _key = 'offline_areas';
  static const paddingKm = 3.0;
  static const minZoom = 12;
  static const maxZoom = 16;
  static const maxTilesPerArea = 2500;
  final Set<String> _cancel = {};

  @override
  OfflineMapsState build() {
    final raw = ref.read(localStoreProvider).rawString(_key);
    final areas = raw == null ? <OfflineArea>[] : (jsonDecode(raw) as List).map((e) => OfflineArea.fromJson(e as Map<String, dynamic>)).toList();
    _refreshSize();
    return OfflineMapsState(areas: areas);
  }

  Future<void> _refreshSize() async {
    final cache = await ref.read(tileCacheProvider.future);
    final bytes = await cache.sizeBytes();
    if (ref.mounted) state = state.copyWith(cacheBytes: bytes);
  }

  Future<void> _persist() => ref.read(localStoreProvider).setRaw(_key, jsonEncode(state.areas.map((a) => a.toJson()).toList()));

  /// Size estimate before downloading, for the confirm dialog.
  static (int tiles, int bytes) estimateFor(Adventure a) {
    final b = boundsAround(a.lat, a.lng, paddingKm);
    final n = tilesFor(south: b.south, west: b.west, north: b.north, east: b.east, minZoom: minZoom, maxZoom: maxZoom).length;
    return (n, estimateBytes(n));
  }

  Future<void> download(Adventure a) async {
    if (state.downloading(a.id)) return;
    final b = boundsAround(a.lat, a.lng, paddingKm);
    final tiles = tilesFor(south: b.south, west: b.west, north: b.north, east: b.east, minZoom: minZoom, maxZoom: maxZoom);
    if (tiles.length > maxTilesPerArea) {
      state = state.copyWith(error: 'Area too large (${tiles.length} tiles).');
      return;
    }
    final cache = await ref.read(tileCacheProvider.future);
    _cancel.remove(a.id);
    state = state.copyWith(progress: {...state.progress, a.id: 0}, clearError: true);
    var done = 0;
    var bytes = 0;
    var failed = 0;
    // Two at a time with a small gap: polite to the tile server.
    final queue = List<TileId>.of(tiles);
    Future<void> worker() async {
      while (queue.isNotEmpty && !_cancel.contains(a.id)) {
        final t = queue.removeAt(0);
        try {
          final existing = await cache.get('osm/${t.key}');
          final data = existing ?? await cache.fetchAndStore('osm/${t.key}', _url(t), const {'User-Agent': 'TrailSeek/0.2 ($tileUserAgent)'});
          bytes += data.length;
        } catch (_) {
          failed++;
        }
        done++;
        if (ref.mounted) state = state.copyWith(progress: {...state.progress, a.id: done / tiles.length});
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    }

    await Future.wait([worker(), worker()]);
    final progress = {...state.progress}..remove(a.id);
    if (_cancel.contains(a.id)) {
      state = state.copyWith(progress: progress);
      return;
    }
    final area = OfflineArea(
      id: a.id, name: a.name, south: b.south, west: b.west, north: b.north, east: b.east,
      minZoom: minZoom, maxZoom: maxZoom, tileCount: tiles.length - failed, bytes: bytes, createdAt: DateTime.now(),
    );
    state = state.copyWith(
      areas: [...state.areas.where((x) => x.id != a.id), area],
      progress: progress,
      error: failed == 0 ? null : '$failed of ${tiles.length} tiles failed; try again on Wi-Fi.',
    );
    await _persist();
    await cache.evict(protect: _protected());
    await _refreshSize();
  }

  void cancel(String areaId) => _cancel.add(areaId);

  Future<void> delete(String areaId) async {
    final area = state.areas.where((a) => a.id == areaId).firstOrNull;
    if (area == null) return;
    final cache = await ref.read(tileCacheProvider.future);
    await cache.deleteKeys(area.tiles().map((t) => 'osm/${t.key}'));
    state = state.copyWith(areas: state.areas.where((a) => a.id != areaId).toList());
    await _persist();
    await _refreshSize();
  }

  Future<void> clearCache() async {
    final cache = await ref.read(tileCacheProvider.future);
    await cache.clear();
    state = state.copyWith(areas: const []);
    await _persist();
    await _refreshSize();
  }

  Set<String> _protected() => {for (final a in state.areas) for (final t in a.tiles()) 'osm/${t.key}'};

  static String _url(TileId t) => tileUrlTemplate.replaceAll('{z}', '${t.z}').replaceAll('{x}', '${t.x}').replaceAll('{y}', '${t.y}');
}

final offlineMapsProvider = NotifierProvider<OfflineMapsController, OfflineMapsState>(OfflineMapsController.new);
