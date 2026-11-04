import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/big_cards.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/adventure.dart';
import '../../data/models/destination.dart';
import '../maps/map_tiles.dart';

/// One of the Thrissur destinations: photos, what it is, fees, how to reach,
/// nearby places and every programme the Forest Department runs there.
class DestinationScreen extends ConsumerWidget {
  const DestinationScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dest = ref.watch(destinationByIdProvider(id)).value;
    if (dest == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final all = ref.watch(adventuresProvider).value ?? const <Adventure>[];
    final programs = all.where((a) => a.destinationId == dest.id).toList();
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
                ScreenTitle(dest.shortName),
                const SizedBox(height: 4),
                Text(dest.tagline, style: TsText.caption),
                const SizedBox(height: 18),
                for (final a in programs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: ProgrammeBigCard(a: a, onTap: () => context.push('/adventure/${a.id}')),
                  ),
                const SectionTitle('About this place'),
                Text(dest.description, style: const TextStyle(height: 1.5)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [for (final h in dest.highlights) Chip(label: Text(h), avatar: const Icon(Icons.star, size: 16, color: TsColors.amber))]),
                const SectionTitle('Entry fees'),
                TsCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Column(
                    children: [
                      for (final e in dest.entryFees.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [Expanded(child: Text(e.key)), Text(ProgramPricing.rupees(e.value), style: TsText.bodyStrong)]),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [const Icon(Icons.schedule, size: 16, color: TsColors.textMuted), const SizedBox(width: 8), Expanded(child: Text(dest.timings, style: TsText.caption))]),
                      ),
                    ],
                  ),
                ),
                const SectionTitle('How to reach'),
                Text(dest.howToReach, style: const TextStyle(height: 1.5)),
                const SizedBox(height: 10),
                _Map(dest),
                if (dest.nearby.isNotEmpty) ...[
                  const SectionTitle('Nearby'),
                  for (final n in dest.nearby)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.place_outlined, color: TsColors.neon),
                      title: Text(n.name),
                      subtitle: Text(n.note, style: TsText.caption),
                      trailing: Text(n.distanceKm == 0 ? 'here' : '${n.distanceKm.round()} km', style: TsText.caption),
                    ),
                ],
                const SectionTitle('Best season'),
                Text(dest.bestSeason, style: const TextStyle(height: 1.5)),
        ],
      ),
    );
  }
}

class _Map extends StatelessWidget {
  const _Map(this.d);
  final Destination d;
  @override
  Widget build(BuildContext context) {
    final p = LatLng(d.lat, d.lng);
    return TsCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(TsSpace.radiusLg)),
            child: SizedBox(
              height: 150,
              child: IgnorePointer(
                child: FlutterMap(
                  options: MapOptions(initialCenter: p, initialZoom: 11, interactionOptions: const InteractionOptions(flags: InteractiveFlag.none), backgroundColor: TsColors.surface),
                  children: [
                    const TsTileLayer(),
                    MarkerLayer(markers: [Marker(point: p, width: 36, height: 36, child: const Icon(Icons.place, color: TsColors.neon, size: 34))]),
                    tsAttribution,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
            child: Row(
              children: [
                Expanded(child: Text('Counter near ${d.nearestTown}', style: TsText.caption, maxLines: 1, overflow: TextOverflow.ellipsis)),
                TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${d.lat},${d.lng}&travelmode=driving'), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Directions'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
