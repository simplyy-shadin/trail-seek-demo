import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../maps/map_tiles.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/activity_category.dart';
import '../../data/models/activity_record.dart';
import '../rope/engine/geo.dart';
import '../settings/settings_controller.dart';
import 'elevation_chart.dart';
import 'share_card.dart';
import 'track_store.dart';

/// Frame 9: hero, title, date, Verified pill, route, stat cards,
/// elevation profile, XP strip, group section, share.
class ActivitySummaryScreen extends ConsumerWidget {
  const ActivitySummaryScreen({super.key, required this.activityId, this.celebrate = false});
  final String activityId;
  final bool celebrate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(activitiesProvider);
    final a = activities.where((r) => r.id == activityId).firstOrNull;
    if (a == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Activity not found')));
    }
    final track = ref.watch(trackDataProvider(a.id));
    final progress = ref.watch(progressProvider);
    final user = ref.watch(authProvider);
    final units = ref.watch(unitsProvider);
    final xp = progress.xpByActivity[a.id] ?? 0;
    final cat = ActivityCategory.fromKey(a.type.name) ?? ActivityCategory.trekking;
    final d = a.duration;
    final route = track?.points.map((p) => p.geo).toList() ?? const <GeoPoint>[];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
            actions: [
              IconButton(onPressed: () => _editTitle(context, ref, a), icon: const Icon(Icons.edit_outlined)),
              IconButton(onPressed: () => _share(context, a, route, user?.initials ?? 'TS', xp), icon: const Icon(Icons.ios_share)),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: CoverArt(
                hue: 140 + a.type.index * 9.0,
                icon: cat.icon,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, TsColors.bg]),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            sliver: SliverList.list(
              children: [
                Text(a.title, style: TsText.h1),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('d MMM yyyy').format(a.startedAt)} · ${DateFormat('h:mm a').format(a.startedAt)} – ${DateFormat('h:mm a').format(a.endedAt)}',
                  style: TsText.caption,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (a.isTrivial)
                      const Chip(avatar: Icon(Icons.timer_off, size: 16, color: TsColors.warning), label: Text('Too short to count'))
                    else if (a.verified)
                      const Chip(avatar: Icon(Icons.verified, size: 16, color: TsColors.neon), label: Text('Verified'))
                    else
                      const Chip(avatar: Icon(Icons.gps_off, size: 16, color: TsColors.warning), label: Text('Not GPS-verified')),
                    Chip(avatar: Icon(cat.icon, size: 16, color: TsColors.neon), label: Text(cat.label)),
                    if (a.isGroup) Chip(avatar: const Icon(Icons.groups, size: 16, color: TsColors.neon), label: Text('${a.memberCount} members')),
                    if (a.simulated) const Chip(avatar: Icon(Icons.science_outlined, size: 16, color: TsColors.textMuted), label: Text('Demo')),
                  ],
                ),
                const SizedBox(height: 16),
                if (route.length >= 2) _RouteMap(route: route),
                if (route.length >= 2) const SizedBox(height: 12),
                if (xp > 0)
                  TsCard(
                    highlighted: celebrate,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt, color: TsColors.neon),
                        const SizedBox(width: 10),
                        Text('+$xp XP', style: TsText.h3.copyWith(color: TsColors.neon)),
                        const Spacer(),
                        Text('Level ${progress.level} · ${progress.xpInLevel} / ${progress.xpForLevel}', style: TsText.caption),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.9,
                  children: [
                    _Stat(icon: Icons.straighten, label: 'Distance', value: units.distanceKm(a.distanceKm)),
                    _Stat(icon: Icons.trending_up, label: 'Elevation Gain', value: units.elevationM(a.elevationGainM)),
                    _Stat(icon: Icons.schedule, label: 'Duration', value: '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m'),
                    _Stat(icon: Icons.terrain, label: 'Highest Altitude', value: units.elevationM(a.maxAltitudeM)),
                  ],
                ),
                if (track != null && track.movingTime > Duration.zero) ...[
                  const SizedBox(height: 10),
                  TsCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(child: InlineStat(icon: Icons.directions_walk, value: _fmt(track.movingTime), label: 'Moving time')),
                        Expanded(
                          child: InlineStat(
                            icon: Icons.speed,
                            value: '${units.pace(track.movingTime, a.distanceM)} ${units.paceUnit}',
                            label: 'Avg pace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SectionHeader('Elevation Profile'),
                TsCard(
                  padding: const EdgeInsets.fromLTRB(12, 14, 16, 12),
                  child: ElevationChart(profile: track?.hasElevation == true ? track!.elevationProfile() : const []),
                ),
                if (a.isGroup) ...[
                  const SectionHeader('Group'),
                  TsCard(
                    child: Row(
                      children: [
                        Expanded(child: InlineStat(icon: Icons.groups, value: '${a.memberCount}', label: 'Members')),
                        Expanded(child: InlineStat(icon: Icons.link_off, value: '${a.separations}', label: 'Separations caught')),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () => _delete(context, ref, a),
                  icon: const Icon(Icons.delete_outline, color: TsColors.danger, size: 18),
                  label: const Text('Delete activity', style: TextStyle(color: TsColors.danger)),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: NeonButton(label: 'Share Activity', icon: Icons.share, onPressed: () => _share(context, a, route, user?.initials ?? 'TS', xp)),
      ),
    );
  }

  static String _fmt(Duration d) => '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';

  Future<void> _share(BuildContext context, ActivityRecord a, List<GeoPoint> route, String initials, int xp) async {
    try {
      await shareActivityCard(
        ShareCard(activity: a, route: route, initials: initials, xp: xp),
        fileName: 'trailseek-${a.id.substring(0, 8)}.png',
      );
    } catch (_) {
      // Fall back to text if image rendering is unavailable on this device.
      await SharePlus.instance.share(ShareParams(
        text: '${a.title}: ${a.distanceKm.toStringAsFixed(1)} km, ${a.elevationGainM} m up, '
            '${a.duration.inHours}h ${a.duration.inMinutes % 60}m${a.verified ? ' (GPS-verified)' : ''}. Tracked with Trail Seek.',
      ));
    }
  }

  Future<void> _editTitle(BuildContext context, WidgetRef ref, ActivityRecord a) async {
    final c = TextEditingController(text: a.title);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename activity'),
        content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.sentences, maxLength: 60),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (title != null && title.isNotEmpty) await ref.read(activitiesProvider.notifier).updateTitle(a.id, title);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, ActivityRecord a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this activity?'),
        content: const Text('XP and badges will be recalculated without it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: TsColors.danger, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(trackStoreProvider).delete(a.id);
    await ref.read(activitiesProvider.notifier).remove(a.id);
    if (context.mounted) context.canPop() ? context.pop() : context.go('/home');
  }
}

class _RouteMap extends StatelessWidget {
  const _RouteMap({required this.route});
  final List<GeoPoint> route;

  @override
  Widget build(BuildContext context) {
    final pts = route.map((p) => LatLng(p.lat, p.lng)).toList();
    final bounds = LatLngBounds.fromPoints(pts);
    return ClipRRect(
      borderRadius: BorderRadius.circular(TsSpace.radiusLg),
      child: SizedBox(
        height: 180,
        child: IgnorePointer(
          child: FlutterMap(
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(28)),
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              backgroundColor: TsColors.surface,
            ),
            children: [
              const TsTileLayer(),
              PolylineLayer(polylines: [Polyline(points: pts, strokeWidth: 4, color: TsColors.neon)]),
              MarkerLayer(markers: [
                Marker(point: pts.first, width: 14, height: 14, child: const DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white))),
                Marker(point: pts.last, width: 14, height: 14, child: const DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: TsColors.neon))),
              ]),
              tsAttribution,
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return TsCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [Icon(icon, size: 14, color: TsColors.textMuted), const SizedBox(width: 6), Text(label, style: TsText.caption)]),
          const SizedBox(height: 6),
          Text(value, style: TsText.stat),
        ],
      ),
    );
  }
}
