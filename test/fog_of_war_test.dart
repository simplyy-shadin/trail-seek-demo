import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trailseek/app/providers.dart';
import 'package:trailseek/data/repositories/local_store.dart';
import 'package:trailseek/features/maps/fog_of_war_controller.dart';

Future<(LocalStore, ProviderContainer)> _newContainer({
  Map<String, Object> values = const {},
}) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  final store = LocalStore(prefs);
  final container = ProviderContainer(
    overrides: [localStoreProvider.overrideWithValue(store)],
  );
  return (store, container);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fog is off by default and cannot collect exploration points', () async {
    final (_, container) = await _newContainer();
    addTearDown(container.dispose);

    final state = container.read(fogOfWarProvider);
    expect(state.enabled, isFalse);
    expect(state.exploredCellCount, 0);
    final recorded = container.read(fogOfWarProvider.notifier).revealAcceptedPoint(
      latitude: 10.2851,
      longitude: 76.5699,
      accuracyM: 5,
    );
    expect(recorded, isFalse);
    expect(container.read(fogOfWarProvider).revealed, isEmpty);
  });

  test('record accepted points only once per approximate 100m cell', () async {
    final (_, container) = await _newContainer();
    addTearDown(container.dispose);
    final fog = container.read(fogOfWarProvider.notifier);
    await fog.setEnabled(true);

    expect(fog.revealAcceptedPoint(
      latitude: 10.2851, longitude: 76.5699, accuracyM: 6,
    ), isTrue);
    expect(fog.revealAcceptedPoint(
      latitude: 10.2852, longitude: 76.56991, accuracyM: 6,
    ), isFalse);
    expect(fog.revealAcceptedPoint(
      latitude: 10.2862, longitude: 76.5699, accuracyM: 7,
    ), isTrue);
    expect(container.read(fogOfWarProvider).exploredCellCount, 2);
  });

  test('invalid or inaccurate GPS points do not reveal new areas', () async {
    final (_, container) = await _newContainer();
    addTearDown(container.dispose);
    final fog = container.read(fogOfWarProvider.notifier);
    await fog.setEnabled(true);

    expect(fog.revealAcceptedPoint(
      latitude: 10, longitude: 76, accuracyM: 500,
    ), isFalse);
    expect(fog.revealAcceptedPoint(
      latitude: double.nan, longitude: 76, accuracyM: 2,
    ), isFalse);
    expect(fog.revealAcceptedPoint(
      latitude: 91, longitude: 76, accuracyM: 2,
    ), isFalse);
    expect(fog.revealAcceptedPoint(
      latitude: 10, longitude: 181, accuracyM: 2,
    ), isFalse);
    expect(container.read(fogOfWarProvider).revealed, isEmpty);
  });

  test('fog opt-in and explored cells persist on device across restarts', () async {
    final (store, container) = await _newContainer();
    addTearDown(container.dispose);
    final fog = container.read(fogOfWarProvider.notifier);
    await fog.setEnabled(true);
    expect(fog.revealAcceptedPoint(
      latitude: 10.2851, longitude: 76.5699, accuracyM: 6,
    ), isTrue);
    // Persist is fired only when a new coarse cell is added, never per fix.
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final revived = ProviderContainer(
      overrides: [localStoreProvider.overrideWithValue(store)],
    );
    addTearDown(revived.dispose);
    expect(revived.read(fogOfWarProvider).enabled, isTrue);
    expect(revived.read(fogOfWarProvider).exploredCellCount, 1);
    await revived.read(fogOfWarProvider.notifier).setEnabled(false);
    expect(revived.read(fogOfWarProvider).enabled, isFalse);
    expect(revived.read(fogOfWarProvider).exploredCellCount, 1);
    await revived.read(fogOfWarProvider.notifier).clearHistory();
    expect(revived.read(fogOfWarProvider).exploredCellCount, 0);
    expect(
      revived.read(fogOfWarProvider.notifier).revealAcceptedPoint(
        latitude: 10.5, longitude: 76.7, accuracyM: 4,
      ),
      isFalse,
    );
  });

  test('corrupt saved fog data safely resets and does not opt in', () async {
    final (_, container) = await _newContainer(values: {
      FogOfWarController.storageKey: '{invalid!',
    });
    addTearDown(container.dispose);
    expect(container.read(fogOfWarProvider).enabled, isFalse);
    expect(container.read(fogOfWarProvider).revealed, isEmpty);
  });

  test('invalid cell keys are filtered from restored history', () async {
    final (_, container) = await _newContainer(values: {
      FogOfWarController.storageKey: jsonEncode({
        'enabled': true,
        'revealed': ['10285:76569', 'BAD', '10000000:0'],
      }),
    });
    addTearDown(container.dispose);
    expect(container.read(fogOfWarProvider).exploredCellCount, 1);
    expect(container.read(fogOfWarProvider).enabled, isTrue);
  });
}
