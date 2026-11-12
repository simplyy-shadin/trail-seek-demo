import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/destination.dart';
import 'offline_vector_packs.dart';
import 'tile_math.dart';

/// Public OpenFreeMap terms (2026-10-14): up to 3,000 tiles OR 50 MB per
/// offline download, no more than 4 parallel requests and a unique User-Agent.
/// We use a single explicit request at a time to stay under those limits.
class OfflineVectorRegionPolicy {
  static const maxTiles = 3000;
  static const maxBytes = 50 * 1000 * 1000;
  static const maxTileBytes = 2 * 1000 * 1000;
  static const paddingKm = 3.0;
  static const minZoom = 12;
  static const maxZoom = 16;
  static const attribution =
      'OpenFreeMap © OpenMapTiles · Data from OpenStreetMap contributors';
  static const userAgent = 'Trailseek/0.6.1 (offline-vector-map; com.trailseek.trailseek)';

  static Uri tileUrl(TileId tile) => Uri.https(
        'tiles.openfreemap.org',
        '/planet/latest/${tile.z}/${tile.x}/${tile.y}.pbf',
      );

  static OfflineVectorRegionPlan plan(Destination destination) {
    final lat = destination.lat;
    final lng = destination.lng;
    if (!lat.isFinite || !lng.isFinite || lat.abs() >= 85 || lng.abs() > 180) {
      throw const FormatException('Invalid destination coordinates');
    }
    final bounds = boundsAround(lat, lng, paddingKm);
    final tiles = tilesFor(
      south: bounds.south,
      west: bounds.west,
      north: bounds.north,
      east: bounds.east,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
    if (tiles.isEmpty || tiles.length > maxTiles) {
      throw FormatException(
        'Region would require ${tiles.length} tiles; 3,000 is the download limit.',
      );
    }
    return OfflineVectorRegionPlan(
      name: destination.name,
      south: bounds.south,
      west: bounds.west,
      north: bounds.north,
      east: bounds.east,
      tiles: tiles,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
  }
}

class OfflineVectorRegionPlan {
  const OfflineVectorRegionPlan({
    required this.name,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    required this.minZoom,
    required this.maxZoom,
    required this.tiles,
  });

  final String name;
  final double south, west, north, east;
  final int minZoom, maxZoom;
  final List<TileId> tiles;
}

class OfflineRegionCancelled implements Exception {
  const OfflineRegionCancelled();
}

class OfflineRegionLimitExceeded implements Exception {
  const OfflineRegionLimitExceeded(this.message);
  final String message;

  @override
  String toString() => message;
}

int mbtilesTmsRow(TileId tile) => (1 << tile.z) - tile.y - 1;

/// Store complete tiles in a temporary MBTiles archive, rolling back/deleting
/// the file on an error or cancellation. The fetch callback is injectable so
/// tests never contact an external provider.
Future<int> writeOfflineVectorRegion({
  required File destination,
  required OfflineVectorRegionPlan plan,
  required Future<Uint8List> Function(TileId tile) fetch,
  required bool Function() cancelled,
  void Function(int completed, int total, int bytes)? onProgress,
}) async {
  if (plan.tiles.isEmpty || plan.tiles.length > OfflineVectorRegionPolicy.maxTiles) {
    throw const OfflineRegionLimitExceeded('Offline region tile count exceeds policy');
  }
  if (await destination.exists()) {
    throw StateError('Cannot overwrite an existing offline archive');
  }

  final db = sqlite3.open(destination.path);
  var transactionOpen = false;
  var committed = false;
  var completed = 0;
  var bytes = 0;
  try {
    db.execute('CREATE TABLE metadata (name TEXT PRIMARY KEY, value TEXT NOT NULL)');
    db.execute('CREATE TABLE tiles (zoom_level INTEGER NOT NULL, tile_column INTEGER NOT NULL, tile_row INTEGER NOT NULL, tile_data BLOB NOT NULL)');
    db.execute('CREATE UNIQUE INDEX tile_index ON tiles (zoom_level, tile_column, tile_row)');
    const sql = 'INSERT INTO metadata (name, value) VALUES (?, ?)';
    final metadata = <String, String>{
      'name': plan.name,
      'format': 'pbf',
      'type': 'baselayer',
      'bounds': '${plan.west},${plan.south},${plan.east},${plan.north}',
      'minzoom': '${plan.minZoom}',
      'maxzoom': '${plan.maxZoom}',
      'attribution': OfflineVectorRegionPolicy.attribution,
      'description': 'Trailseek small-area offline vector map · 3 km around destination',
    };
    for (final entry in metadata.entries) {
      db.execute(sql, [entry.key, entry.value]);
    }
    db.execute('BEGIN TRANSACTION');
    transactionOpen = true;

    for (final tile in plan.tiles) {
      if (cancelled()) throw const OfflineRegionCancelled();
      final data = await fetch(tile);
      if (cancelled()) throw const OfflineRegionCancelled();
      if (data.isEmpty || data.length > OfflineVectorRegionPolicy.maxTileBytes) {
        throw const OfflineRegionLimitExceeded('Tile empty or larger than per-tile allowance');
      }
      bytes += data.length;
      if (bytes > OfflineVectorRegionPolicy.maxBytes) {
        throw const OfflineRegionLimitExceeded('The 50 MB download limit was reached');
      }
      db.execute(
        'INSERT INTO tiles (zoom_level, tile_column, tile_row, tile_data) VALUES (?, ?, ?, ?)',
        [tile.z, tile.x, mbtilesTmsRow(tile), data],
      );
      completed++;
      onProgress?.call(completed, plan.tiles.length, bytes);
      // Yield between synchronous SQLite writes so cancellation can be handled.
      if (completed % 12 == 0) await Future<void>.delayed(Duration.zero);
    }
    db.execute('COMMIT');
    transactionOpen = false;
    committed = true;
  } catch (_) {
    if (transactionOpen) db.execute('ROLLBACK');
    rethrow;
  } finally {
    db.close();
    // An error *after* the final tile (e.g. COMMIT or progress callback)
    // must not leave an incomplete archive that looks installed.
    if (!committed && await destination.exists()) {
      await destination.delete();
    }
  }
  return bytes;
}

/// Fetch only from the documented OpenFreeMap vector tile URL. Redirects are
/// disabled and responses are streamed with a hard byte bound.
Future<Uint8List> fetchOpenFreeMapTile(HttpClient client, TileId tile) async {
  final uri = OfflineVectorRegionPolicy.tileUrl(tile);
  final request = await client.getUrl(uri).timeout(const Duration(seconds: 20));
  request.followRedirects = false;
  request.headers.set(HttpHeaders.userAgentHeader, OfflineVectorRegionPolicy.userAgent);
  request.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip');
  final response = await request.close().timeout(const Duration(seconds: 20));
  if (response.statusCode != HttpStatus.ok) {
    await response.drain<void>();
    throw HttpException('Vector tile ${tile.z}/${tile.x}/${tile.y} returned HTTP ${response.statusCode}', uri: uri);
  }
  final body = BytesBuilder(copy: false);
  await for (final chunk in response.timeout(const Duration(seconds: 20))) {
    if (body.length + chunk.length > OfflineVectorRegionPolicy.maxTileBytes) {
      throw const OfflineRegionLimitExceeded('Server returned an oversized vector tile');
    }
    body.add(chunk);
  }
  return body.takeBytes();
}

class OfflineRegionDownloadState {
  const OfflineRegionDownloadState({
    this.isDownloading = false,
    this.progress = 0,
    this.completed = 0,
    this.total = 0,
    this.bytes = 0,
    this.error,
  });

  final bool isDownloading;
  final double progress;
  final int completed, total, bytes;
  final String? error;
}

class OfflineVectorRegionDownloadController
    extends Notifier<OfflineRegionDownloadState> {
  bool _cancelled = false;

  @override
  OfflineRegionDownloadState build() {
    ref.onDispose(() => _cancelled = true);
    return const OfflineRegionDownloadState();
  }

  void cancel() => _cancelled = true;

  Future<OfflineVectorPack?> download(Destination destination) async {
    if (state.isDownloading) return null;
    final plan = OfflineVectorRegionPolicy.plan(destination);
    _cancelled = false;
    state = OfflineRegionDownloadState(isDownloading: true, total: plan.tiles.length);
    File? temp;
    final client = HttpClient()..autoUncompress = false;
    try {
      final directory = await getApplicationSupportDirectory();
      final scratch = Directory('${directory.path}/offline_vector_packs');
      await scratch.create(recursive: true);
      temp = File('${scratch.path}/${const Uuid().v4()}.partial.mbtiles');
      await writeOfflineVectorRegion(
        destination: temp,
        plan: plan,
        cancelled: () => _cancelled,
        fetch: (tile) => fetchOpenFreeMapTile(client, tile),
        onProgress: (done, total, bytes) {
          if (!ref.mounted) return;
          state = OfflineRegionDownloadState(
            isDownloading: true,
            progress: done / total,
            completed: done,
            total: total,
            bytes: bytes,
          );
        },
      );
      if (_cancelled) throw const OfflineRegionCancelled();
      final installed = await ref
          .read(offlineVectorPacksProvider.notifier)
          .installGeneratedPack(temp, displayName: '${destination.name} · 3 km');
      temp = null;
      await ref.read(offlineVectorPacksProvider.notifier).select(installed.id);
      if (ref.mounted) state = const OfflineRegionDownloadState();
      return installed;
    } on OfflineRegionCancelled {
      if (ref.mounted) {
        state = const OfflineRegionDownloadState(error: 'Offline map download cancelled.');
      }
      return null;
    } catch (error) {
      if (ref.mounted) {
        state = OfflineRegionDownloadState(error: 'Offline map download failed: $error');
      }
      rethrow;
    } finally {
      client.close(force: true);
      if (temp != null && await temp.exists()) await temp.delete();
      if (ref.mounted && state.isDownloading) {
        state = const OfflineRegionDownloadState();
      }
    }
  }
}

final offlineVectorRegionDownloadProvider =
    NotifierProvider<OfflineVectorRegionDownloadController, OfflineRegionDownloadState>(
  OfflineVectorRegionDownloadController.new,
);
