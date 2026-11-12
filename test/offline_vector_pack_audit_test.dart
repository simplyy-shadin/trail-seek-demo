import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:trailseek/features/maps/offline_vector_pack_audit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MBTiles bounds parse and reject impossible regions', () {
    final bounds = OfflinePackBounds.fromMetadata('76.45,10.20,76.65,10.32');
    expect(bounds, isNotNull);
    expect(bounds!.contains(10.2851, 76.5699), isTrue);
    expect(bounds.contains(11.0, 76.5699), isFalse);
    expect(OfflinePackBounds.fromMetadata('n/a'), isNull);
    expect(OfflinePackBounds.fromMetadata('5,10,4,20'), isNull);
    expect(OfflinePackBounds.fromMetadata('76.1,10,76.2,100'), isNull);
  });

  test('missing archive is reported without claiming offline availability', () async {
    final scratch = await Directory.systemTemp.createTemp('trailseek-missing-map');
    addTearDown(() => scratch.delete(recursive: true));
    final result = await auditOfflineVectorPack('${scratch.path}/missing.mbtiles');
    expect(result.isValid, isFalse);
    expect(result.message, contains('missing'));
  });

  test('invalid SQLite file fails audit', () async {
    final scratch = await Directory.systemTemp.createTemp('trailseek-invalid-map');
    addTearDown(() => scratch.delete(recursive: true));
    final path = '${scratch.path}/not-a-map.mbtiles';
    await File(path).writeAsBytes(List<int>.filled(1024, 0x42));
    final result = await auditOfflineVectorPack(path);
    expect(result.isValid, isFalse);
  });

  test('well-formed vector archive passes file structure and coverage checks', () async {
    final scratch = await Directory.systemTemp.createTemp('trailseek-good-map');
    addTearDown(() => scratch.delete(recursive: true));
    final file = File('${scratch.path}/pilot.mbtiles');
    final db = sqlite3.open(file.path);
    db.execute('CREATE TABLE metadata (name TEXT, value TEXT)');
    db.execute(
      'CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, '
      'tile_row INTEGER, tile_data BLOB)',
    );
    for (final entry in <String, String>{
      'name': 'Pilot',
      'format': 'pbf',
      'bounds': '76.45,10.20,76.65,10.32',
      'minzoom': '12',
      'maxzoom': '16',
    }.entries) {
      db.execute('INSERT INTO metadata VALUES (?, ?)', [entry.key, entry.value]);
    }
    db.execute(
      'INSERT INTO tiles VALUES (?, ?, ?, ?)',
      [12, 1000, 1500, Uint8List.fromList([0x1a, 0x00])],
    );
    db.close();

    final result = await auditOfflineVectorPack(file.path);
    expect(result.isValid, isTrue);
    expect(result.bounds, isNotNull);
    expect(result.bounds!.contains(10.2851, 76.5699), isTrue);
    expect(result.bounds!.contains(12.0, 76.5699), isFalse);
    expect(result.minZoom, 12);
    expect(result.maxZoom, 16);
    expect(result.message, contains('approximate'));
  });

  test('archive without tiles is rejected even with valid metadata', () async {
    final scratch = await Directory.systemTemp.createTemp('trailseek-empty-map');
    addTearDown(() => scratch.delete(recursive: true));
    final file = File('${scratch.path}/empty.mbtiles');
    final db = sqlite3.open(file.path);
    db.execute('CREATE TABLE metadata (name TEXT, value TEXT)');
    db.execute(
      'CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, '
      'tile_row INTEGER, tile_data BLOB)',
    );
    db.execute("INSERT INTO metadata VALUES ('format', 'pbf')");
    db.close();

    final result = await auditOfflineVectorPack(file.path);
    expect(result.isValid, isFalse);
    expect(result.message, contains('no nonempty vector tiles'));
  });
}
