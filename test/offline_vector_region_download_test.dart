import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:trailseek/data/models/destination.dart';
import 'package:trailseek/features/maps/offline_vector_region_download.dart';
import 'package:trailseek/features/maps/tile_math.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pilot plan stays within provider limits and uses real destination coordinates', () {
    final place = Destination.fromJson({
      'id': 'athirappilly-vazhachal',
      'name': 'Athirappilly – Vazhachal',
      'lat': 10.2851,
      'lng': 76.5699,
    });
    final plan = OfflineVectorRegionPolicy.plan(place);
    expect(plan.tiles, isNotEmpty);
    expect(plan.tiles.length, lessThanOrEqualTo(3000));
    expect(plan.minZoom, 12);
    expect(plan.maxZoom, 16);
    expect(plan.south, lessThan(place.lat));
    expect(plan.north, greaterThan(place.lat));
    expect(plan.west, lessThan(place.lng));
    expect(plan.east, greaterThan(place.lng));
    final url = OfflineVectorRegionPolicy.tileUrl(plan.tiles.first);
    expect(url.scheme, 'https');
    expect(url.host, 'tiles.openfreemap.org');
    expect(url.path, endsWith('.pbf'));
  });

  test('XYZ tile coordinates flip into the MBTiles TMS row scheme', () {
    expect(mbtilesTmsRow(const TileId(0, 0, 0)), 0);
    expect(mbtilesTmsRow(const TileId(3, 4, 0)), 7);
    expect(mbtilesTmsRow(const TileId(3, 4, 7)), 0);
  });

  test('writer produces a valid SQLite MBTiles with the original data', () async {
    final folder = await Directory.systemTemp.createTemp('trailseek-mbtiles-test');
    addTearDown(() => folder.delete(recursive: true));
    final path = File('${folder.path}/pilot.mbtiles');
    final plan = OfflineVectorRegionPlan(
      name: 'Pilot',
      south: 10.2, west: 76.4, north: 10.3, east: 76.6,
      minZoom: 3, maxZoom: 3,
      tiles: [const TileId(3, 4, 2)],
    );
    final bytes = Uint8List.fromList([0x1a, 0x02, 0x01, 0x02]);
    final count = await writeOfflineVectorRegion(
      destination: path,
      plan: plan,
      fetch: (_) async => bytes,
      cancelled: () => false,
    );
    expect(count, 4);
    final db = sqlite3.open(path.path);
    addTearDown(db.close);
    final metadata = db.select('SELECT value FROM metadata WHERE name = ?', ['format']);
    expect(metadata.single['value'], 'pbf');
    final tiles = db.select(
      'SELECT tile_row, tile_data FROM tiles WHERE zoom_level = 3 AND tile_column = 4',
    );
    expect(tiles.length, 1);
    expect(tiles.single['tile_row'], 5);
    expect(tiles.single['tile_data'], bytes);
  });

  test('cancelled downloads do not keep a partial archive', () async {
    final folder = await Directory.systemTemp.createTemp('trailseek-mbtiles-cancel');
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}/cancel.mbtiles');
    final plan = OfflineVectorRegionPlan(
      name: 'Cancel', south: 0, west: 0, north: 1, east: 1,
      minZoom: 2, maxZoom: 2, tiles: [const TileId(2, 1, 1)],
    );
    await expectLater(
      writeOfflineVectorRegion(
        destination: file,
        plan: plan,
        fetch: (_) async => Uint8List.fromList([0x01]),
        cancelled: () => true,
      ),
      throwsA(isA<OfflineRegionCancelled>()),
    );
    expect(await file.exists(), isFalse);
  });

  test('late error after the final tile deletes the uncommitted archive', () async {
    final folder = await Directory.systemTemp.createTemp('trailseek-mbtiles-late-error');
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}/incomplete.mbtiles');
    final plan = OfflineVectorRegionPlan(
      name: 'Late failure',
      south: 10, west: 76, north: 11, east: 77,
      minZoom: 3, maxZoom: 3,
      tiles: [const TileId(3, 4, 2)],
    );
    await expectLater(
      writeOfflineVectorRegion(
        destination: file,
        plan: plan,
        fetch: (_) async => Uint8List.fromList([0x1a, 0x00]),
        cancelled: () => false,
        onProgress: (_, __, ___) => throw StateError('Simulated write failure'),
      ),
      throwsStateError,
    );
    expect(await file.exists(), isFalse);
  });

  test('oversized tile plan fails before opening a database', () async {
    final folder = await Directory.systemTemp.createTemp('trailseek-mbtiles-cap');
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}/too-large.mbtiles');
    final plan = OfflineVectorRegionPlan(
      name: 'Over limit', south: 0, west: 0, north: 1, east: 1,
      minZoom: 10, maxZoom: 10,
      tiles: List.filled(3001, const TileId(10, 1, 1)),
    );
    await expectLater(
      writeOfflineVectorRegion(
        destination: file,
        plan: plan,
        fetch: (_) async => Uint8List.fromList([0x01]),
        cancelled: () => false,
      ),
      throwsA(isA<OfflineRegionLimitExceeded>()),
    );
    expect(await file.exists(), isFalse);
  });
}
