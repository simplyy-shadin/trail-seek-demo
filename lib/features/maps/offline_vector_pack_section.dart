import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import 'offline_vector_packs.dart';
import 'tile_math.dart';

/// A native import workflow for licensed or self-hosted MBTiles vector maps.
/// No tile service or in-app region scraper is used by this feature.
class OfflineVectorPacksSection extends ConsumerWidget {
  const OfflineVectorPacksSection({super.key});

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    try {
      final selected = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['mbtiles'],
      );
      if (selected == null) return;
      final notifier = ref.read(offlineVectorPacksProvider.notifier);
      final pack = await notifier.importFile(selected);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Imported ${pack.name}. Tap the pack to use it offline.'),
      ));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Unable to import vector map: $error'),
      ));
    }
  }

  Future<void> _select(BuildContext context, WidgetRef ref, String? id) async {
    try {
      await ref.read(offlineVectorPacksProvider.notifier).select(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            id == null
                ? 'Online game maps selected.'
                : 'Offline pack selected for game-themed maps.',
          ),
        ));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to switch maps: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offlineVectorPacksProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Offline game map packs'),
        TsCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Import a licensed vector .mbtiles file saved on your phone. '
                'Adventure RPG and Night Trek will use it without fetching '
                'map tiles over the internet.',
                style: TsText.bodyStrong,
              ),
              const SizedBox(height: 6),
              Text(
                'This does not download a region for you. The file must '
                'contain OpenMapTiles-compatible PBF/MVT data. '
                'Outside its coverage, geographic features may be missing. '
                'Check its licence and always carry an independent navigation backup.',
                style: TsText.caption,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: state.importing ? null : () => _import(context, ref),
                icon: const Icon(Icons.file_upload_outlined),
                label: Text(state.importing ? 'Importing offline map…' : 'Import vector MBTiles'),
              ),
              if (state.importing) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(),
              ],
              if (state.active != null) ...[
                const SizedBox(height: 8),
                Text('Active offline pack: ${state.active!.name}', style: TsText.caption),
                TextButton(
                  onPressed: () => _select(context, ref, null),
                  child: const Text('Use online game maps instead'),
                ),
              ],
            ],
          ),
        ),
        if (state.packs.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final pack in state.packs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TsCard(
                padding: const EdgeInsets.all(8),
                child: ListTile(
                  key: ValueKey('offline-pack-${pack.id}'),
                  selected: state.activeId == pack.id,
                  leading: Icon(
                    state.activeId == pack.id
                        ? Icons.offline_pin
                        : Icons.map_outlined,
                    color: state.activeId == pack.id
                        ? TsColors.neon
                        : TsColors.textMuted,
                  ),
                  title: Text(pack.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${humanBytes(pack.byteLength)} · ${state.activeId == pack.id ? 'Enabled' : 'Tap to enable'}'
                    '\n${pack.attribution ?? 'Confirm the pack data licence before use'}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TsText.caption,
                  ),
                  onTap: state.importing
                      ? null
                      : () => _select(context, ref, pack.id),
                  trailing: IconButton(
                    tooltip: 'Delete ${pack.name}',
                    icon: const Icon(Icons.delete_outline, color: TsColors.danger),
                    onPressed: state.importing
                        ? null
                        : () async {
                            final approved = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Delete offline map?'),
                                content: Text('Remove ${pack.name} from this device?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogContext, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(dialogContext, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (approved != true) return;
                            await ref
                                .read(offlineVectorPacksProvider.notifier)
                                .delete(pack.id);
                          },
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
