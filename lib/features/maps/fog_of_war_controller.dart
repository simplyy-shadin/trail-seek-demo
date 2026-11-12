import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

/// Deliberately coarse, local-only exploration cells (~110 m north/south).
/// No network calls, Bluetooth scans, or additional location subscription.
class FogCell {
  const FogCell(this.latitudeIndex, this.longitudeIndex);

  static const step = 0.001;

  final int latitudeIndex;
  final int longitudeIndex;

  String get key => '$latitudeIndex:$longitudeIndex';

  double get latitude => (latitudeIndex + 0.5) * step;
  double get longitude => (longitudeIndex + 0.5) * step;

  static FogCell? fromPoint(double latitude, double longitude) {
    if (!latitude.isFinite || !longitude.isFinite ||
        latitude.abs() > 85 || longitude.abs() > 180) {
      return null;
    }
    return FogCell(
      (latitude / step).floor(),
      (longitude / step).floor(),
    );
  }

  static FogCell? fromKey(String key) {
    final parts = key.split(':');
    if (parts.length != 2) return null;
    final latitudeIndex = int.tryParse(parts[0]);
    final longitudeIndex = int.tryParse(parts[1]);
    if (latitudeIndex == null || longitudeIndex == null) return null;
    final cell = FogCell(latitudeIndex, longitudeIndex);
    return fromPoint(cell.latitude, cell.longitude) == null ? null : cell;
  }
}

class FogOfWarState {
  const FogOfWarState({
    this.enabled = false,
    this.revealed = const <String>{},
  });

  final bool enabled;
  final Set<String> revealed;
  int get exploredCellCount => revealed.length;
}

/// User opt-in; only positions already accepted by Solo SmartTrace are saved.
/// The fixed-size local list is capped to avoid expensive repaints/storage.
class FogOfWarController extends Notifier<FogOfWarState> {
  static const storageKey = 'fog_of_war_v1';
  static const maxCells = 6000;
  static const maxAcceptedAccuracyM = 50.0;

  @override
  FogOfWarState build() {
    final raw = ref.read(localStoreProvider).rawString(storageKey);
    if (raw == null) return const FogOfWarState();
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final cells = <String>{};
      for (final value in (data['revealed'] as List<dynamic>? ?? const [])) {
        if (value is! String) continue;
        final cell = FogCell.fromKey(value);
        if (cell == null) continue;
        cells.add(cell.key);
        if (cells.length >= maxCells) break;
      }
      return FogOfWarState(
        enabled: data['enabled'] == true,
        revealed: cells,
      );
    } catch (_) {
      return const FogOfWarState();
    }
  }

  Future<void> _persist() => ref.read(localStoreProvider).setRaw(
    storageKey,
    jsonEncode({
      'enabled': state.enabled,
      'revealed': state.revealed.toList(growable: false),
    }),
  );

  Future<void> setEnabled(bool enabled) async {
    if (enabled == state.enabled) return;
    state = FogOfWarState(enabled: enabled, revealed: state.revealed);
    await _persist();
  }

  /// Always call only with *accepted* foreground solo recording fixes.
  /// Rejects poor-accuracy, invalid and duplicate cells. Returns whether a
  /// newly visited cell was recorded.
  bool revealAcceptedPoint({
    required double latitude,
    required double longitude,
    required double accuracyM,
  }) {
    if (!state.enabled || !accuracyM.isFinite ||
        accuracyM < 0 || accuracyM > maxAcceptedAccuracyM) return false;

    final cell = FogCell.fromPoint(latitude, longitude);
    if (cell == null || state.revealed.contains(cell.key)) return false;

    final updated = {...state.revealed, cell.key};
    if (updated.length > maxCells) updated.remove(updated.first);
    state = FogOfWarState(enabled: true, revealed: updated);
    // Only one write per *new* ~100 m cell, not every GPS sample.
    _persist();
    return true;
  }

  Future<void> clearHistory() async {
    state = FogOfWarState(enabled: state.enabled);
    await _persist();
  }
}

final fogOfWarProvider =
    NotifierProvider<FogOfWarController, FogOfWarState>(
  FogOfWarController.new,
);
