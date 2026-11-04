import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../maps/map_tiles.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/activity_category.dart';
import '../rope/engine/geo.dart';
import '../settings/settings_controller.dart';
import 'tracking_controller.dart';

LatLng _ll(GeoPoint p) => LatLng(p.lat, p.lng);

/// Frame 8: live solo recording over the map.
class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});
  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final _map = MapController();
  bool _follow = true;
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trackingProvider);
    final ctrl = ref.read(trackingProvider.notifier);
    final units = ref.watch(unitsProvider);

    if (t.status == TrackingStatus.idle) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live Tracking')),
        body: Center(child: GhostButton(label: 'Start a trek', expanded: false, onPressed: () => context.pushReplacement('/track/start'))),
      );
    }

    final pos = t.lastPosition;
    if (_follow && _ready && pos != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _follow) _map.move(_ll(pos), _map.camera.zoom);
      });
    }
    final cat = ActivityCategory.fromKey(t.type.name) ?? ActivityCategory.trekking;
    final recording = t.status == TrackingStatus.recording;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: pos == null ? const LatLng(10.0, 76.5) : _ll(pos),
              initialZoom: pos == null ? 7 : 16,
              backgroundColor: TsColors.bg,
              onMapReady: () => setState(() => _ready = true),
              onPositionChanged: (_, gesture) {
                if (gesture && _follow) setState(() => _follow = false);
              },
            ),
            children: [
              const TsTileLayer(),
              if (t.points.length > 1)
                PolylineLayer(polylines: [Polyline(points: t.points.map(_ll).toList(), strokeWidth: 5, color: TsColors.neon)]),
              if (pos != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _ll(pos),
                    width: 34,
                    height: 34,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: TsColors.selfMarker,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black45)],
                      ),
                      child: const Icon(Icons.navigation, size: 16),
                    ),
                  ),
                ]),
              tsAttribution,
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  RoundIconButton(icon: Icons.arrow_back, tooltip: 'Back (recording continues)', onTap: () => context.canPop() ? context.pop() : context.go('/home')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: TsColors.surface.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(999), border: Border.all(color: TsColors.outline)),
                      child: Row(
                        children: [
                          Icon(cat.icon, size: 18, color: TsColors.neon),
                          const SizedBox(width: 8),
                          Text(cat.label, style: TsText.bodyStrong),
                          const Spacer(),
                          Icon(t.isResting ? Icons.airline_seat_recline_normal : Icons.fiber_manual_record, size: 12, color: recording ? (t.isResting ? TsColors.warning : TsColors.danger) : TsColors.textMuted),
                          const SizedBox(width: 6),
                          Text(recording ? (t.isResting ? 'Resting' : 'Recording') : 'Paused', style: TsText.caption),
                          const SizedBox(width: 10),
                          Text(_fmt(t.elapsed), style: TsText.bodyStrong.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (t.restored || t.error != null || (t.accuracyM != null && t.accuracyM! > 25))
            Positioned(
              left: 12,
              right: 12,
              top: 70,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: TsColors.warning.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    t.error ??
                        (t.restored
                            ? 'Recording restored from before the app closed. Tap play to continue.'
                            : 'Weak GPS signal (±${t.accuracyM!.round()} m). Fixes this poor are not counted.'),
                    style: const TextStyle(color: TsColors.onNeon, fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 12,
            bottom: 236,
            child: Column(
              children: [
                RoundIconButton(icon: _follow ? Icons.my_location : Icons.location_searching, tooltip: 'Follow me', onTap: () => setState(() => _follow = true)),
                const SizedBox(height: 8),
                RoundIconButton(icon: Icons.layers_outlined, tooltip: 'Map style: ${ref.watch(mapStyleProvider).label}', onTap: () => ref.read(mapStyleProvider.notifier).toggle()),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: const BoxDecoration(
                color: TsColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black54)],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _Big(units.distanceKm(t.distanceKm), 'Distance')),
                        Container(width: 1, height: 40, color: TsColors.outline),
                        Expanded(child: _Big(units.elevationM(t.gainM), 'Elevation Gain')),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: InlineStat(
                            icon: Icons.terrain,
                            value: t.currentAltitudeM == null ? '—' : units.elevationM(t.currentAltitudeM!),
                            label: 'Current Altitude',
                          ),
                        ),
                        GestureDetector(
                          onLongPress: () => _end(context),
                          child: RoundIconButton(
                            icon: recording ? Icons.pause : Icons.play_arrow,
                            neon: true,
                            size: 64,
                            onTap: () async {
                              if (recording) {
                                await ctrl.pause();
                              } else {
                                final err = await ctrl.resume();
                                if (err != null && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _end(context),
                          icon: const Icon(Icons.stop_circle_outlined, color: TsColors.danger, size: 18),
                          label: const Text('Finish', style: TextStyle(color: TsColors.danger)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _end(BuildContext context) async {
    final t = ref.read(trackingProvider);
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finish recording?'),
        content: Text('${t.distanceKm.toStringAsFixed(2)} km in ${_fmt(t.elapsed)}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: const Text('Discard', style: TextStyle(color: TsColors.danger))),
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Keep going')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Save')),
        ],
      ),
    );
    if (!context.mounted || choice == null) return;
    final ctrl = ref.read(trackingProvider.notifier);
    if (choice == 'discard') {
      await ctrl.discard();
      if (context.mounted) context.go('/home');
      return;
    }
    final id = await ctrl.stop();
    if (context.mounted) context.pushReplacement('/activity/$id?celebrate=1');
  }

  static String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }
}

class _Big extends StatelessWidget {
  const _Big(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        Text(label, style: TsText.caption),
      ],
    );
  }
}
