import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/big_cards.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/destination.dart';
import '../maps/map_tiles.dart';
import '../maps/explore_game_map.dart';

/// Map tab: every Thrissur destination as a pin; tap one for its card.
/// Group treks (Digital Rope) start from here too.
class MapTab extends ConsumerStatefulWidget {
  const MapTab({super.key});
  @override
  ConsumerState<MapTab> createState() => _MapTabState();
}

class _MapTabState extends ConsumerState<MapTab> {
  Destination? _picked;

  void _showMapThemes(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final selected = ref.watch(exploreMapThemeProvider);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('Choose your map world', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                ),
                for (final theme in ExploreMapTheme.values)
                  ListTile(
                    leading: Icon(theme.icon),
                    title: Text(theme.label),
                    subtitle: Text(theme.description),
                    selected: selected == theme,
                    trailing: selected == theme ? const Icon(Icons.check_circle) : null,
                    onTap: () async {
                      await ref.read(exploreMapThemeProvider.notifier).select(theme);
                      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinations = ref.watch(destinationsProvider).value ?? const <Destination>[];
    final active = ref.watch(activeSessionProvider);
    final exploreTheme = ref.watch(exploreMapThemeProvider);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Game map themes',
            icon: const Icon(Icons.layers_outlined),
            onPressed: () => _showMapThemes(context),
          ),
          TextButton.icon(onPressed: () => context.push('/groups'), icon: const Icon(Icons.groups, size: 20), label: const Text('Groups')),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(10.48, 76.47),
              initialZoom: 9.6,
              backgroundColor: TsColors.surface,
              onTap: (_, _) => setState(() => _picked = null),
            ),
            children: [
              if (exploreTheme == ExploreMapTheme.classic)
                const TsTileLayer()
              else
                ExploreGameTileLayer(theme: exploreTheme),
              MarkerLayer(markers: [
                for (final d in destinations)
                  Marker(
                    point: LatLng(d.lat, d.lng),
                    width: 46,
                    height: 46,
                    child: GestureDetector(
                      onTap: () => setState(() => _picked = d),
                      child: Icon(Icons.location_on, size: 44, color: _picked?.id == d.id ? TsColors.neon : Colors.white),
                    ),
                  ),
              ]),
              if (exploreTheme == ExploreMapTheme.classic)
                tsAttribution
              else
                const SimpleAttributionWidget(
                  source: Text('OpenFreeMap © OpenMapTiles · Data from OpenStreetMap'),
                ),
            ],
          ),
          if (active != null)
            Positioned(
              left: 16,
              right: 16,
              top: 10,
              child: TsCard(
                color: TsColors.neon,
                onTap: () => context.push('/group/${active.id}/live'),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  const Icon(Icons.sensors, color: TsColors.onNeon, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Digital Rope active · ${active.name}', style: TsText.bodyStrong.copyWith(color: TsColors.onNeon))),
                  const Icon(Icons.chevron_right, color: TsColors.onNeon),
                ]),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _picked == null
                ? TsCard(
                    onTap: () => context.push('/group/create'),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: const Row(children: [
                      Icon(Icons.link, color: TsColors.neon),
                      SizedBox(width: 10),
                      Expanded(child: Text('Trekking as a group? Start a Digital Rope so nobody gets left behind.', style: TsText.bodyStrong)),
                      Icon(Icons.chevron_right, color: TsColors.textMuted),
                    ]),
                  )
                : DestinationBigCard(d: _picked!, onTap: () => context.push('/destination/${_picked!.id}')),
          ),
        ],
      ),
    );
  }
}
