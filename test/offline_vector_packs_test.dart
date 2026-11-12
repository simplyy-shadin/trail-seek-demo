import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trailseek/app/providers.dart';
import 'package:trailseek/data/repositories/local_store.dart';
import 'package:trailseek/features/maps/offline_vector_packs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sqliteHeader = <int>[
    0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66,
    0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
  ];

  test('rejects non-SQLite and truncated offline archives', () {
    expect(hasMbtilesHeader(sqliteHeader), isTrue);
    expect(hasMbtilesHeader(sqliteHeader.take(15).toList()), isFalse);
    expect(hasMbtilesHeader(utf8.encode('not a map archive')), isFalse);
  });

  test('pack metadata round trips without losing attribution', () {
    final pack = OfflineVectorPack(
      id: 'thrissur',
      name: 'Thrissur trails',
      path: '/app/trails.mbtiles',
      byteLength: 10240,
      importedAt: DateTime.utc(2026, 11, 12),
      attribution: '© Example data contributor',
    );
    final decoded = OfflineVectorPack.fromJson(pack.toJson());
    expect(decoded.id, pack.id);
    expect(decoded.name, pack.name);
    expect(decoded.path, pack.path);
    expect(decoded.byteLength, pack.byteLength);
    expect(decoded.importedAt, pack.importedAt);
    expect(decoded.attribution, pack.attribution);
  });

  test('active archive persists; removing it returns to online mode', () async {
    final pack = OfflineVectorPack(
      id: 'pack-1',
      name: 'Pilot',
      path: '/a/not-installed-test.mbtiles',
      byteLength: 256,
      importedAt: DateTime.utc(2026, 11, 12),
    );
    SharedPreferences.setMockInitialValues({
      OfflineVectorPacksController.storageKey: jsonEncode({
        'packs': [pack.toJson()],
        'activeId': pack.id,
      }),
    });

    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore(prefs);
    final container = ProviderContainer(
      overrides: [localStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    expect(container.read(offlineVectorPacksProvider).active?.id, 'pack-1');

    await container.read(offlineVectorPacksProvider.notifier).select(null);
    expect(container.read(offlineVectorPacksProvider).active, isNull);
    await expectLater(
      container.read(offlineVectorPacksProvider.notifier).select('pack-1'),
      throwsA(isA<FileSystemException>()),
    );
    expect(container.read(offlineVectorPacksProvider).active, isNull);

    final next = ProviderContainer(
      overrides: [localStoreProvider.overrideWithValue(store)],
    );
    addTearDown(next.dispose);
    expect(next.read(offlineVectorPacksProvider).packs.length, 1);
    expect(next.read(offlineVectorPacksProvider).active, isNull);

    await container.read(offlineVectorPacksProvider.notifier).delete('pack-1');
    expect(container.read(offlineVectorPacksProvider).packs, isEmpty);
  });

  test('corrupt saved index cannot break map startup', () async {
    SharedPreferences.setMockInitialValues({
      OfflineVectorPacksController.storageKey: '{invalid-json',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(LocalStore(prefs)),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(offlineVectorPacksProvider).active, isNull);
    expect(container.read(offlineVectorPacksProvider).packs, isEmpty);
  });
}
