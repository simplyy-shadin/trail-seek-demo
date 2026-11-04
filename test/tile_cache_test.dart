import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/features/maps/tile_cache.dart';
import 'package:trailseek/features/maps/tile_math.dart';

void main() {
  test('tile maths matches known slippy-map values', () {
    // Chembra Peak, zoom 15.
    expect(lonToTileX(76.0940, 15), 23310);
    expect(latToTileY(11.5097, 15), 15329);
    expect(lonToTileX(-180, 3), 0);
    expect(lonToTileX(179.9, 3), 7);
  });

  test('tiles for a 3 km box stay small and estimate is proportional', () {
    final b = boundsAround(11.5097, 76.0940, 3);
    final tiles = tilesFor(south: b.south, west: b.west, north: b.north, east: b.east, minZoom: 12, maxZoom: 16);
    expect(tiles.length, inInclusiveRange(40, 200));
    expect(tiles.toSet().length, tiles.length);
    expect(estimateBytes(tiles.length), tiles.length * averageTileBytes);
    expect(humanBytes(estimateBytes(100)), '2.1 MB');
  });

  test('cache stores on miss, serves hits without fetching, and evicts LRU', () async {
    final dir = await Directory.systemTemp.createTemp('tiles');
    addTearDown(() => dir.delete(recursive: true));
    var fetches = 0;
    final cache = TileCache(dir, fetcher: (url, h) async {
      fetches++;
      return Uint8List(1000);
    });
    const k1 = '15/1/1.png', k2 = '15/1/2.png', k3 = '15/1/3.png';
    expect(await cache.get(k1), isNull);
    await cache.fetchAndStore(k1, 'u1', const {});
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await cache.fetchAndStore(k2, 'u2', const {});
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await cache.fetchAndStore(k3, 'u3', const {});
    expect(fetches, 3);
    expect((await cache.get(k2))!.length, 1000);
    expect(fetches, 3);
    expect(await cache.sizeBytes(), 3000);

    // Reading k2 above made it the most recently used, so k3 is now the oldest unprotected tile.
    final removed = await cache.evict(cap: 2000, protect: {k1});
    expect(removed, 1);
    expect(await cache.has(k1), isTrue); // protected
    expect(await cache.has(k2), isTrue); // recently read
    expect(await cache.has(k3), isFalse); // least recently used
  });
}
