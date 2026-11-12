import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import 'offline_areas.dart';
import 'offline_vector_pack_section.dart';
import 'tile_math.dart';

class OfflineMapsScreen extends ConsumerWidget {
  const OfflineMapsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(offlineMapsProvider);
    final n = ref.read(offlineMapsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Offline maps')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          const OfflineVectorPacksSection(),
          const SizedBox(height: 18),
          TsCard(
            child: Row(
              children: [
                const Icon(Icons.sd_storage_outlined, color: TsColors.neon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${humanBytes(s.cacheBytes)} used', style: TsText.h3),
                      Text('${s.areas.length} downloaded ${s.areas.length == 1 ? 'area' : 'areas'} · cache cap 1 GB, oldest tiles go first', style: TsText.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (s.error != null) ...[
            const SizedBox(height: 10),
            Text(s.error!, style: TsText.caption.copyWith(color: TsColors.warning)),
          ],
          const SectionHeader('Legacy raster downloads'),
          if (s.areas.isEmpty)
            TsCard(
              onTap: () => context.go('/home'),
              child: const Row(
                children: [
                  Icon(Icons.map_outlined, color: TsColors.textMuted),
                  SizedBox(width: 12),
                  Expanded(child: Text('Nothing yet. Open a trail and tap "Download for offline" while on Wi-Fi.', style: TsText.caption)),
                  Icon(Icons.chevron_right, color: TsColors.textMuted),
                ],
              ),
            ),
          for (final a in s.areas)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TsCard(
                padding: const EdgeInsets.all(12),
                onTap: () => context.push('/adventure/${a.id}'),
                child: Row(
                  children: [
                    const Icon(Icons.offline_pin, color: TsColors.neon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.name, style: TsText.h3),
                          Text('${a.tileCount} tiles · ${humanBytes(a.bytes)} · ${DateFormat('d MMM').format(a.createdAt)}', style: TsText.caption),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => n.delete(a.id), icon: const Icon(Icons.delete_outline, color: TsColors.danger)),
                  ],
                ),
              ),
            ),
          if (s.areas.isNotEmpty || s.cacheBytes > 0) ...[
            const SizedBox(height: 10),
            GhostButton(label: 'Clear all cached tiles', icon: Icons.cleaning_services_outlined, onPressed: n.clearCache),
          ],
          const SizedBox(height: 20),
          const Text(
            'Map data © OpenStreetMap contributors. Downloads cover 3 km around the trail at zoom 12–16. '
            'The legacy raster downloader currently uses public OSM tiles, which are not licensed for bulk offline downloads. '
            'Do not use it to pre-download areas until the source is replaced. Imported MBTiles vector packs are separate.',
            style: TsText.caption,
          ),
        ],
      ),
    );
  }
}

/// "Download for offline" tile for the adventure detail page.
class OfflineDownloadTile extends ConsumerWidget {
  const OfflineDownloadTile({super.key, required this.adventureId, required this.onDownload});
  final String adventureId;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(offlineMapsProvider);
    final n = ref.read(offlineMapsProvider.notifier);
    final progress = s.progress[adventureId];
    final has = s.has(adventureId);
    return TsCard(
      padding: const EdgeInsets.all(12),
      onTap: progress != null ? null : (has ? () => context.push('/settings/offline-maps') : onDownload),
      child: Row(
        children: [
          Icon(has ? Icons.offline_pin : Icons.download_for_offline_outlined, color: has ? TsColors.neon : TsColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(progress != null ? 'Downloading map… ${(progress * 100).round()}%' : (has ? 'Map available offline' : 'Download map for offline'), style: TsText.bodyStrong),
                if (progress != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, minHeight: 5)),
                ] else
                  Text(has ? 'Tiles for 3 km around the trail are on this phone' : 'Trailheads rarely have signal. Do this on Wi-Fi.', style: TsText.caption),
              ],
            ),
          ),
          if (progress != null)
            IconButton(onPressed: () => n.cancel(adventureId), icon: const Icon(Icons.close))
          else
            const Icon(Icons.chevron_right, color: TsColors.textMuted),
        ],
      ),
    );
  }
}
