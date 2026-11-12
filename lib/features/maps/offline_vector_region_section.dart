import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/destination.dart';
import 'offline_vector_region_download.dart';
import 'tile_math.dart';

/// Explicit, user-initiated downloads for the existing Thrissur destinations.
/// The area is fixed to a 3 km radius and hard-capped by provider policy.
class OfflineVectorRegionSection extends ConsumerStatefulWidget {
  const OfflineVectorRegionSection({super.key});

  @override
  ConsumerState<OfflineVectorRegionSection> createState() =>
      _OfflineVectorRegionSectionState();
}

class _OfflineVectorRegionSectionState
    extends ConsumerState<OfflineVectorRegionSection> {
  String? _selectedDestinationId;

  Future<void> _start(Destination destination) async {
    try {
      final plan = OfflineVectorRegionPolicy.plan(destination);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Download offline game map?'),
          content: Text(
            'Download ${plan.tiles.length} vector tiles covering approximately '
            '3 km around ${destination.name}, zoom 12–16. The app stops before '
            '50 MB and downloads one tile at a time.\n\n'
            'OpenFreeMap © OpenMapTiles; data © OpenStreetMap contributors. '
            'Use Wi-Fi. This will not include areas outside the selected region.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Download'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final pack = await ref
          .read(offlineVectorRegionDownloadProvider.notifier)
          .download(destination);
      if (pack != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${pack.name} saved for offline game maps.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Offline game map: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = ref.watch(destinationsProvider).value ??
        const <Destination>[];
    final progress = ref.watch(offlineVectorRegionDownloadProvider);
    final chosen = destinations.where((d) => d.id == _selectedDestinationId)
        .firstOrNull ??
        (destinations.isNotEmpty ? destinations.first : null);
    OfflineVectorRegionPlan? plan;
    if (chosen != null) {
      try {
        plan = OfflineVectorRegionPolicy.plan(chosen);
      } catch (_) {
        // Unusable coordinates disable the download button.
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Download a game-map region'),
        TsCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Save a small vector map around a Thrissur destination for '
                'Adventure RPG and Night Trek.',
                style: TsText.bodyStrong,
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                isExpanded: true,
                value: chosen?.id,
                hint: const Text('Choose a destination'),
                onChanged: progress.isDownloading
                    ? null
                    : (id) => setState(() => _selectedDestinationId = id),
                items: [
                  for (final d in destinations)
                    DropdownMenuItem(value: d.id, child: Text(d.name)),
                ],
              ),
              if (plan != null)
                Text(
                  '${plan.tiles.length} tiles · 3 km radius · zoom 12–16 · '
                  'download capped at 50 MB',
                  style: TsText.caption,
                ),
              const SizedBox(height: 12),
              if (progress.isDownloading) ...[
                LinearProgressIndicator(value: progress.progress),
                const SizedBox(height: 7),
                Text(
                  '${progress.completed}/${progress.total} tiles '
                  '· ${humanBytes(progress.bytes)}',
                  style: TsText.caption,
                ),
                TextButton.icon(
                  onPressed: () => ref
                      .read(offlineVectorRegionDownloadProvider.notifier)
                      .cancel(),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel download'),
                ),
              ] else
                OutlinedButton.icon(
                  onPressed:
                      plan == null || chosen == null ? null : () => _start(chosen),
                  icon: const Icon(Icons.download_for_offline_outlined),
                  label: const Text('Download small offline region'),
                ),
              if (progress.error != null)
                Text(progress.error!,
                    style: TsText.caption.copyWith(color: TsColors.warning)),
              const SizedBox(height: 8),
              const Text(
                'Downloads are explicit and bounded by the tile provider's '
                'offline terms. Missing regions remain unavailable without '
                'internet. For safety, always carry an independent navigation '
                'backup and perform field testing before relying on this map.',
                style: TsText.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
