import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map_vector_tiles_mbtiles/flutter_map_vector_tiles_mbtiles.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';

/// An imported vector MBTiles archive stored privately in app support.
/// Packs are local-only; neither the metadata nor the tiles leave the device.
class OfflineVectorPack {
  const OfflineVectorPack({
    required this.id,
    required this.name,
    required this.path,
    required this.byteLength,
    required this.importedAt,
    this.attribution,
  });

  final String id;
  final String name;
  final String path;
  final int byteLength;
  final DateTime importedAt;
  final String? attribution;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'byteLength': byteLength,
        'importedAt': importedAt.toIso8601String(),
        'attribution': attribution,
      };

  factory OfflineVectorPack.fromJson(Map<String, dynamic> data) =>
      OfflineVectorPack(
        id: data['id'] as String,
        name: data['name'] as String,
        path: data['path'] as String,
        byteLength: data['byteLength'] as int,
        importedAt: DateTime.parse(data['importedAt'] as String),
        attribution: data['attribution'] as String?,
      );
}

class OfflineVectorPacksState {
  const OfflineVectorPacksState({
    this.packs = const [],
    this.activeId,
    this.importing = false,
  });

  final List<OfflineVectorPack> packs;
  final String? activeId;
  final bool importing;

  OfflineVectorPack? get active {
    for (final pack in packs) {
      if (pack.id == activeId) return pack;
    }
    return null;
  }
}

/// SQLite header, not proof that the archive contains the correct vector
/// tiles. The MBTiles provider opens and checks its schema after this gate.
bool hasMbtilesHeader(List<int> header) {
  const signature = <int>[
    0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66,
    0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
  ];
  if (header.length < signature.length) return false;
  for (var i = 0; i < signature.length; i++) {
    if (header[i] != signature[i]) return false;
  }
  return true;
}

/// User-supplied, licensed MBTiles packs. No remote tile scraping or bulk
/// downloading is performed by this controller.
class OfflineVectorPacksController extends Notifier<OfflineVectorPacksState> {
  static const storageKey = 'offline_vector_packs_v1';
  static const maxImportBytes = 1024 * 1024 * 1024; // 1 GiB per local archive.

  @override
  OfflineVectorPacksState build() {
    final stored = ref.read(localStoreProvider).rawString(storageKey);
    if (stored == null) return const OfflineVectorPacksState();
    try {
      final decoded = jsonDecode(stored) as Map<String, dynamic>;
      final packs = (decoded['packs'] as List<dynamic>)
          .map((value) => OfflineVectorPack.fromJson(
                value as Map<String, dynamic>,
              ))
          .toList(growable: false);
      final activeId = decoded['activeId'] as String?;
      return OfflineVectorPacksState(
        packs: packs,
        activeId: packs.any((pack) => pack.id == activeId) ? activeId : null,
      );
    } catch (_) {
      // An invalid saved index must never break live map rendering.
      return const OfflineVectorPacksState();
    }
  }

  Future<void> _persist() => ref.read(localStoreProvider).setRaw(
        storageKey,
        jsonEncode({
          'packs': state.packs.map((pack) => pack.toJson()).toList(),
          'activeId': state.activeId,
        }),
      );

  Future<void> select(String? id) async {
    if (id != null && !state.packs.any((pack) => pack.id == id)) {
      throw ArgumentError.value(id, 'id', 'Unknown offline map pack');
    }
    state = OfflineVectorPacksState(packs: state.packs, activeId: id);
    await _persist();
  }

  /// Stream a native file-picker selection into private storage, verify that
  /// SQLite and MBTiles can read it and that it contains vector tiles.
  /// A partial/invalid file is deleted; it never becomes selectable.
  Future<OfflineVectorPack> importFile(PlatformFile selection) async {
    if (state.importing) throw StateError('An import is already running');
    if (!selection.name.toLowerCase().endsWith('.mbtiles')) {
      throw const FormatException('Choose an .mbtiles vector map archive');
    }
    final knownSize = selection.lengthSync() ?? await selection.length();
    if (knownSize != null && knownSize > maxImportBytes) {
      throw const FormatException('Offline pack is larger than 1 GiB');
    }

    state = OfflineVectorPacksState(
      packs: state.packs,
      activeId: state.activeId,
      importing: true,
    );

    File? staging;
    File? installed;
    RandomAccessFile? writer;
    MbTilesVectorTileProvider? verifier;
    try {
      final root = await getApplicationSupportDirectory();
      final folder = Directory('${root.path}/offline_vector_packs');
      await folder.create(recursive: true);

      final id = const Uuid().v4();
      staging = File('${folder.path}/$id.partial');
      installed = File('${folder.path}/$id.mbtiles');
      writer = await staging.open(mode: FileMode.write);
      var total = 0;
      await for (final data in selection.readAsByteStream()) {
        total += data.length;
        if (total > maxImportBytes) {
          throw const FormatException('Offline pack is larger than 1 GiB');
        }
        await writer.writeFrom(data);
      }
      await writer.flush();
      await writer.close();
      writer = null;

      if (total < 128) {
        throw const FormatException('Empty or truncated map archive');
      }
      final reader = await staging.open(mode: FileMode.read);
      final header = await reader.read(16);
      await reader.close();
      if (!hasMbtilesHeader(header)) {
        throw const FormatException('File is not an MBTiles SQLite archive');
      }

      await staging.rename(installed.path);
      verifier = await MbTilesVectorTileProvider.open(installed.path);
      final format = verifier.metadata.format?.toLowerCase();
      if (format != 'pbf' && format != 'mvt') {
        throw const FormatException(
          'This archive is not vector MBTiles (PBF/MVT)',
        );
      }
      final title = verifier.metadata.name?.trim();
      final pack = OfflineVectorPack(
        id: id,
        name: title == null || title.isEmpty ? selection.name : title,
        path: installed.path,
        byteLength: total,
        importedAt: DateTime.now(),
        attribution: verifier.metadata.attribution,
      );
      verifier.dispose();
      verifier = null;

      state = OfflineVectorPacksState(
        packs: [...state.packs, pack],
        activeId: state.activeId,
        importing: false,
      );
      await _persist();
      return pack;
    } catch (_) {
      if (installed != null && await installed.exists()) {
        await installed.delete();
      }
      rethrow;
    } finally {
      verifier?.dispose();
      if (writer != null) await writer.close();
      if (staging != null && await staging.exists()) {
        await staging.delete();
      }
      if (ref.mounted && state.importing) {
        state = OfflineVectorPacksState(
          packs: state.packs,
          activeId: state.activeId,
        );
      }
    }
  }

  /// Install a validated vector archive generated by Trailseek itself. The
  /// download service must only provide an archive inside app support storage.
  /// This moves (rather than re-downloads) it to its final managed filename.
  Future<OfflineVectorPack> installGeneratedPack(
    File source, {
    required String displayName,
  }) async {
    if (state.importing) throw StateError('Another map import is active');
    final root = await getApplicationSupportDirectory();
    final folder = Directory('${root.path}/offline_vector_packs');
    await folder.create(recursive: true);
    final prefix = '${folder.absolute.path}${Platform.pathSeparator}';
    if (!source.absolute.path.startsWith(prefix) ||
        !source.path.endsWith('.partial.mbtiles')) {
      throw const FormatException('Generated archive must be in app storage');
    }
    if (!await source.exists()) throw const FileSystemException('Download missing');
    if (await source.length() > maxImportBytes) {
      throw const FormatException('Generated archive exceeds storage limit');
    }

    final id = const Uuid().v4();
    final installed = File('${folder.path}/$id.mbtiles');
    MbTilesVectorTileProvider? verifier;
    try {
      await source.rename(installed.path);
      verifier = await MbTilesVectorTileProvider.open(installed.path);
      final format = verifier.metadata.format?.toLowerCase();
      if (format != 'pbf' && format != 'mvt') {
        throw const FormatException('Generated archive lacks vector tiles');
      }
      final pack = OfflineVectorPack(
        id: id,
        name: displayName,
        path: installed.path,
        byteLength: await installed.length(),
        importedAt: DateTime.now(),
        attribution: verifier.metadata.attribution,
      );
      verifier.dispose();
      verifier = null;
      state = OfflineVectorPacksState(
        packs: [...state.packs, pack],
        activeId: state.activeId,
      );
      await _persist();
      return pack;
    } catch (_) {
      if (await installed.exists()) await installed.delete();
      rethrow;
    } finally {
      verifier?.dispose();
    }
  }

  Future<void> delete(String id) async {
    if (state.importing) throw StateError('Wait for the import to finish');
    final target = state.packs.where((pack) => pack.id == id).firstOrNull;
    if (target == null) return;

    // Drop the selected map first, so no new layer starts opening this path.
    state = OfflineVectorPacksState(
      packs: state.packs.where((pack) => pack.id != id).toList(),
      activeId: state.activeId == id ? null : state.activeId,
    );
    await _persist();
    final file = File(target.path);
    if (await file.exists()) await file.delete();
  }
}

final offlineVectorPacksProvider =
    NotifierProvider<OfflineVectorPacksController, OfflineVectorPacksState>(
  OfflineVectorPacksController.new,
);
