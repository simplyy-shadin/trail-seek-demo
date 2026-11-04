import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import 'tile_math.dart';

typedef TileFetcher = Future<Uint8List> Function(String url, Map<String, String> headers);

Future<Uint8List> httpTileFetcher(String url, Map<String, String> headers) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final req = await client.getUrl(Uri.parse(url));
    headers.forEach(req.headers.set);
    final res = await req.close();
    if (res.statusCode != 200) throw HttpException('Tile ${res.statusCode}', uri: Uri.parse(url));
    final builder = BytesBuilder(copy: false);
    await for (final chunk in res) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  } finally {
    client.close();
  }
}

/// Disk cache for map tiles. Reads touch the file so eviction is least
/// recently used. One cache serves live maps and offline downloads.
class TileCache {
  TileCache(this.root, {TileFetcher? fetcher, this.capBytes = 1024 * 1024 * 1024}) : fetch = fetcher ?? httpTileFetcher;

  final Directory root;
  final TileFetcher fetch;
  final int capBytes;

  File _file(String key) => File('${root.path}/$key');

  Future<Uint8List?> get(String key) async {
    final f = _file(key);
    if (!await f.exists()) return null;
    final bytes = await f.readAsBytes();
    unawaited(f.setLastModified(DateTime.now()).catchError((_) {}));
    return bytes;
  }

  Future<bool> has(String key) => _file(key).exists();

  Future<Uint8List> fetchAndStore(String key, String url, Map<String, String> headers) async {
    final bytes = await fetch(url, headers);
    final f = _file(key);
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
    return bytes;
  }

  Future<int> sizeBytes() async {
    if (!await root.exists()) return 0;
    var total = 0;
    await for (final e in root.list(recursive: true, followLinks: false)) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  /// Deletes least recently used tiles until the cache fits [cap] (default [capBytes]).
  /// Tiles under [protect] prefixes (downloaded areas) are kept.
  Future<int> evict({int? cap, Set<String> protect = const {}}) async {
    final limit = cap ?? capBytes;
    if (!await root.exists()) return 0;
    final files = <File>[];
    await for (final e in root.list(recursive: true, followLinks: false)) {
      if (e is File) files.add(e);
    }
    var total = 0;
    final stats = <(File, FileStat)>[];
    for (final f in files) {
      final st = await f.stat();
      total += st.size;
      stats.add((f, st));
    }
    if (total <= limit) return 0;
    stats.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    var removed = 0;
    for (final (f, st) in stats) {
      if (total <= limit) break;
      final rel = f.path.substring(root.path.length + 1);
      if (protect.any(rel.startsWith)) continue;
      await f.delete();
      total -= st.size;
      removed++;
    }
    return removed;
  }

  Future<void> deleteKeys(Iterable<String> keys) async {
    for (final k in keys) {
      final f = _file(k);
      if (await f.exists()) await f.delete();
    }
  }

  Future<void> clear() async {
    if (await root.exists()) await root.delete(recursive: true);
  }
}

/// flutter_map tile provider backed by [TileCache]: cache hit → disk,
/// miss → network, then stored. Offline, cached tiles keep rendering.
class CachedTileProvider extends TileProvider {
  CachedTileProvider(this.cache, {super.headers, this.keyPrefix = 'osm'});
  final TileCache cache;

  /// Separates styles in the cache (osm/… vs topo/…).
  final String keyPrefix;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) => _CachedTileImage(
        key: '$keyPrefix/${TileId(coordinates.z, coordinates.x, coordinates.y).key}',
        // Offline areas are downloaded as street tiles; show those when another style can't load.
        fallbackKey: keyPrefix == 'osm' ? null : 'osm/${TileId(coordinates.z, coordinates.x, coordinates.y).key}',
        url: getTileUrl(coordinates, options),
        cache: cache,
        headers: headers,
      );
}

class _CachedTileImage extends ImageProvider<_CachedTileImage> {
  const _CachedTileImage({required this.key, required this.url, required this.cache, required this.headers, this.fallbackKey});
  final String key;
  final String? fallbackKey;
  final String url;
  final TileCache cache;
  final Map<String, String> headers;

  @override
  Future<_CachedTileImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_CachedTileImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1, debugLabel: url);

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    Uint8List bytes;
    try {
      bytes = await cache.get(key) ?? await cache.fetchAndStore(key, url, headers);
    } catch (_) {
      final fallback = fallbackKey == null ? null : await cache.get(fallbackKey!);
      if (fallback == null) rethrow;
      bytes = fallback;
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) => other is _CachedTileImage && other.key == key;
  @override
  int get hashCode => key.hashCode;
}
