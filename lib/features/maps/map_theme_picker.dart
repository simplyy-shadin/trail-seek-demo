import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'explore_game_map.dart';
import 'fog_of_war_controller.dart';
import 'map_tiles.dart';

/// A single theme picker for Explore, solo recording and Digital Rope.
/// Changing the world never touches tracking, route geometry or BLE state.
Future<void> showMapWorldPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final world = ref.watch(exploreMapThemeProvider);
        final classicLayer = ref.watch(mapStyleProvider);
        final fog = ref.watch(fogOfWarProvider);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.72,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Choose your map world',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Applies to Explore, live treks and activity routes.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  for (final theme in ExploreMapTheme.values)
                    ListTile(
                      key: ValueKey('map-world-${theme.name}'),
                      leading: CircleAvatar(
                        backgroundColor: theme.accentColor.withValues(alpha: 0.15),
                        child: Icon(theme.icon, color: theme.accentColor),
                      ),
                      title: Text(theme.label),
                      subtitle: Text(theme.description),
                      selected: world == theme,
                      trailing:
                          world == theme ? const Icon(Icons.check_circle) : null,
                      onTap: () async {
                        await ref
                            .read(exploreMapThemeProvider.notifier)
                            .select(theme);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                    ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    key: const ValueKey('fog-of-war-toggle'),
                    title: const Text('Fog of War — reveal as you explore'),
                    subtitle: Text(
                      'Optional, on this device only. Accepted solo GPS track '
                      'points reveal areas; no extra GPS or group tracking. '
                      '${fog.exploredCellCount} explored zones.',
                    ),
                    secondary: const Icon(Icons.explore_outlined),
                    value: fog.enabled,
                    onChanged: (enabled) => ref
                        .read(fogOfWarProvider.notifier)
                        .setEnabled(enabled),
                  ),
                  if (fog.exploredCellCount > 0)
                    TextButton.icon(
                      key: const ValueKey('fog-of-war-clear'),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear explored Fog of War history'),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: sheetContext,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Clear explored areas?'),
                            content: const Text(
                              'All locally stored explored zones will be '
                              'removed. This cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(dialogContext, true),
                                child: const Text('Clear history'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ref.read(fogOfWarProvider.notifier).clearHistory();
                        }
                      },
                    ),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Classic map layers',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  for (final layer in MapStyle.values)
                    ListTile(
                      key: ValueKey('classic-layer-${layer.name}'),
                      dense: true,
                      leading: Icon(
                        switch (layer) {
                          MapStyle.satellite => Icons.satellite_alt_outlined,
                          MapStyle.standard => Icons.map_outlined,
                          MapStyle.terrain => Icons.terrain_outlined,
                        },
                      ),
                      title: Text(layer.label),
                      selected:
                          world == ExploreMapTheme.classic && classicLayer == layer,
                      trailing:
                          world == ExploreMapTheme.classic && classicLayer == layer
                              ? const Icon(Icons.check_circle)
                              : null,
                      onTap: () async {
                        ref.read(mapStyleProvider.notifier).select(layer);
                        await ref
                            .read(exploreMapThemeProvider.notifier)
                            .select(ExploreMapTheme.classic);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
