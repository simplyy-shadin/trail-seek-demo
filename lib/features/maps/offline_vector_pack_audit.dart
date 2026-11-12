import 'dart:io';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

/// Bounds reported by an MBTiles archive. These describe the publisher's
/// claimed area, not a verified guarantee of every tile or walking trail.
class OfflinePackBounds {
  const OfflinePackBounds({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  final double west, south, east, north;

  static OfflinePackBounds? fromMetadata(String? csv) {
    if (csv == null) return null;
    final parts = csv.split(',');
    if (parts.length != 4) return null;
    final values = parts.map((part) => double.tryParse(part.trim())).toList();
    if (values.any((value) => value == null || !value.isFinite)) {
      return null;
    }
    final west = values[0]!, south = values[1]!;
    final east = values[2]!, north = values[3]!;
    if (west < -180 || east > 180 || west >= east ||
        south < -85.0511 || north > 85.0511 || south >= north) {
      return null;
    }
    return OfflinePackBounds(west: west, south: south, east: east, north: north);
  }

  bool contains(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= south &&
      latitude <= north &&
      longitude >= west &&
      longitude <= east;

  String get description =>
      'W ${west.toStringAsFixed(4)} · S ${south.toStringAsFixed(4)} · '
      'E ${east.toStringAsFixed(4)} · N ${north.toStringAsFixed(4)}';
}

class OfflinePackAudit {
  const OfflinePackAudit({
    required this.isValid,
    required this.message,
    this.bounds,
    this.minZoom,
    this.maxZoom,
    this.fileBytes = 0,
  });

  /// A successful audit means that the archive passes SQLite integrity,
  /// MBTiles schema and basic tile presence checks. It does *not* prove
  /// geographic completeness or offline map visual correctness.
  final bool isValid;
  final String message;
  final OfflinePackBounds? bounds;
  final int? minZoom;
  final int? maxZoom;
  final int fileBytes;
}

/// Explicit user-triggered verification runs off the UI isolate so even
/// large SQLite PRAGMA quick_check scans do not block Digital Rope controls.
Future<OfflinePackAudit> auditOfflineVectorPack(String path) =>
    Isolate.run(() => _auditOfflineVectorPackSync(path));

OfflinePackAudit _auditOfflineVectorPackSync(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return const OfflinePackAudit(
      isValid: false,
      message: 'Map file missing from device storage.',
    );
  }
  final length = file.lengthSync();
  if (length < 128) {
    return OfflinePackAudit(
      isValid: false,
      message: 'The map file is truncated or empty.',
      fileBytes: length,
    );
  }

  Database? db;
  try {
    db = sqlite3.open(path, mode: OpenMode.readOnly);
    final check = db.select('PRAGMA quick_check(1)');
    if (check.isEmpty || check.first.values.first.toString() != 'ok') {
      return OfflinePackAudit(
        isValid: false,
        message: 'SQLite integrity check failed.',
        fileBytes: length,
      );
    }
    final metadata = <String, String>{};
    for (final row in db.select('SELECT name, value FROM metadata')) {
      metadata[row['name'] as String] = row['value'].toString();
    }
    final format = metadata['format']?.trim().toLowerCase();
    if (format != 'pbf' && format != 'mvt') {
      return OfflinePackAudit(
        isValid: false,
        message: 'Archive is not a vector MBTiles PBF/MVT map.',
        fileBytes: length,
      );
    }
    final tile = db.select(
      'SELECT tile_data FROM tiles WHERE length(tile_data) > 0 LIMIT 1',
    );
    if (tile.isEmpty) {
      return OfflinePackAudit(
        isValid: false,
        message: 'The archive contains no nonempty vector tiles.',
        fileBytes: length,
      );
    }

    int? zoom(String key) => int.tryParse(metadata[key] ?? '');
    final minZoom = zoom('minzoom'), maxZoom = zoom('maxzoom');
    if (minZoom != null && maxZoom != null &&
        (minZoom < 0 || maxZoom > 22 || minZoom > maxZoom)) {
      return OfflinePackAudit(
        isValid: false,
        message: 'The archive declares invalid zoom levels.',
        fileBytes: length,
      );
    }

    final bounds = OfflinePackBounds.fromMetadata(metadata['bounds']);
    return OfflinePackAudit(
      isValid: true,
      message: bounds == null
          ? 'SQLite and tile structure checked. Geographic coverage is unknown.'
          : 'SQLite and tile structure checked. Listed coverage is only approximate.',
      bounds: bounds,
      minZoom: minZoom,
      maxZoom: maxZoom,
      fileBytes: length,
    );
  } catch (error) {
    return OfflinePackAudit(
      isValid: false,
      message: 'Unable to validate the MBTiles archive: $error',
      fileBytes: length,
    );
  } finally {
    db?.close();
  }
}
