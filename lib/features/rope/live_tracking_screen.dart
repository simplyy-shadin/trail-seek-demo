import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../maps/map_tiles.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/group_session.dart';
import 'engine/geo.dart';
import 'engine/rope_models.dart';
import '../../data/models/avatar.dart';
import 'links/simulated_peer_link.dart';
import 'participants_sheet.dart';
import 'rope_controller.dart';

Color stateColor(RopeState s) => ropeStateColor(s);

LatLng _ll(GeoPoint p) => LatLng(p.lat, p.lng);

class LiveTrackingScreen extends ConsumerStatefulWidget {
  const LiveTrackingScreen({super.key, required this.sessionId});
  final String sessionId;
  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  final _map = MapController();
  bool _follow = true;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureStarted());
  }

  Future<void> _ensureStarted() async {
    final rope = ref.read(ropeProvider);
    if (rope != null && rope.session.id == widget.sessionId) return;
    final s = ref.read(sessionByIdProvider(widget.sessionId));
    if (s == null || s.status != SessionStatus.active) return;
    final a = await ref.read(adventureRepositoryProvider).byId(s.adventureId) ?? (await ref.read(adventureRepositoryProvider).all()).first;
    await ref.read(ropeProvider.notifier).start(session: s, adventure: a);
  }

  bool _fresh(RopeSessionState r, String id) {
    final at = r.positionTimes[id];
    return r.positions[id] != null && at != null && DateTime.now().difference(at) < const Duration(minutes: 2);
  }

  @override
  Widget build(BuildContext context) {
    final rope = ref.watch(ropeProvider);
    if (rope == null || rope.session.id != widget.sessionId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group Tracking')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final snap = rope.snapshot;
    final alerting = snap?.alerting ?? const [];
    final worst = snap?.worst ?? RopeState.connected;
    final self = rope.selfPosition;
    if (rope.endedByOrganizer) WidgetsBinding.instance.addPostFrameCallback((_) => _endedByOrganizer(rope));

    if (_follow && _mapReady && self != null) {
      // Keep me and everyone with a fresh fix in view.
      final group = [
        self,
        for (final m in rope.others)
          if (_fresh(rope, m.id)) rope.positions[m.id]!,
      ];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_follow) return;
        if (group.length < 2) {
          _map.move(_ll(self), _map.camera.zoom);
        } else {
          _map.fitCamera(CameraFit.coordinates(coordinates: group.map(_ll).toList(), padding: const EdgeInsets.fromLTRB(60, 170, 60, 380), maxZoom: 18));
        }
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _ll(self ?? rope.route.points.first),
              initialZoom: 16,
              backgroundColor: TsColors.bg,
              onMapReady: () => setState(() => _mapReady = true),
              onPositionChanged: (_, hasGesture) {
                if (hasGesture && _follow) setState(() => _follow = false);
              },
            ),
            children: [
              const TsTileLayer(),
              if (rope.simulated)
                PolylineLayer(
                  polylines: [Polyline(points: rope.route.points.map(_ll).toList(), strokeWidth: 5, color: TsColors.green.withValues(alpha: 0.85))],
                ),
              // Where everyone has walked: my path in neon, members in their state colour.
              PolylineLayer(
                polylines: [
                  for (final m in rope.session.members)
                    if ((rope.trails[m.id]?.length ?? 0) >= 2)
                      Polyline(
                        points: rope.trails[m.id]!.map(_ll).toList(),
                        strokeWidth: m.isSelf ? 6 : 4.5,
                        color: m.isSelf ? TsColors.neon : stateColor(rope.stateOf(m.id)),
                        // Soft glow around the line, like a lit trail.
                        borderStrokeWidth: 7,
                        borderColor: (m.isSelf ? TsColors.neon : stateColor(rope.stateOf(m.id))).withValues(alpha: 0.28),
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                ],
              ),
              // Tether from me to each member with a known fix.
              if (self != null)
                PolylineLayer(
                  polylines: [
                    for (final m in rope.others)
                      if (rope.positions[m.id] != null) Polyline(points: [_ll(self), _ll(rope.positions[m.id]!)], strokeWidth: 2.5, color: stateColor(rope.stateOf(m.id)).withValues(alpha: 0.7)),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (final m in rope.others)
                    if (rope.positions[m.id] != null)
                      Marker(
                        point: _ll(rope.positions[m.id]!),
                        width: 54,
                        height: 66,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(onTap: () => _memberSheet(context, rope, m), child: _Pin(member: m, color: stateColor(rope.stateOf(m.id)))),
                      ),
                  // Me: blue dot with a halo.
                  if (self != null)
                    Marker(
                      point: _ll(self),
                      width: 46,
                      height: 46,
                      child: Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF2F80FF).withValues(alpha: 0.25)),
                        alignment: Alignment.center,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2F80FF),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black54)],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              tsAttribution,
            ],
          ),
          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      _RoundButton(icon: Icons.arrow_back, tooltip: 'Back (rope keeps running)', onTap: () => context.go('/home')),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alerting.isEmpty ? rope.session.name : 'Group Alert',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                              ),
                            ),
                            Row(
                              children: [
                                Icon(rope.simulated ? Icons.science_outlined : Icons.bluetooth, size: 14, color: TsColors.muted),
                                const SizedBox(width: 4),
                                Text(
                                  '${rope.session.members.length} participants · ${_fmt(rope.elapsed)}',
                                  style: const TextStyle(
                                    color: TsColors.text,
                                    fontWeight: FontWeight.w600,
                                    shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      RoundIconButton(icon: Icons.layers_outlined, tooltip: 'Map style: ${ref.watch(mapStyleProvider).label}', onTap: () => ref.read(mapStyleProvider.notifier).toggle()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (rope.error != null)
                    rope.error!.contains('Location')
                        ? _Banner(color: TsColors.amber, icon: Icons.location_off, title: 'Location is off', body: rope.error!)
                        : _Banner(color: TsColors.red, icon: Icons.bluetooth_disabled, title: 'Radio problem', body: radioErrorText(rope.error!))
                  else if (snap?.selfIsolated == true)
                    _Banner(
                      color: TsColors.amber,
                      icon: Icons.directions_walk,
                      title: 'Your group is moving away',
                      body: 'Most of the group has gone quiet. Catch up or let them know.',
                      action: TextButton(
                        onPressed: () => ref.read(ropeProvider.notifier).sendAction(RopeMessageType.waitForMe),
                        child: const Text('Wait for me', style: TextStyle(color: Colors.white)),
                      ),
                    )
                  else if (alerting.isNotEmpty)
                    _Banner(
                      color: stateColor(worst),
                      icon: Icons.warning_amber_rounded,
                      title: alerting.length == 1 ? '1 member is ${worst == RopeState.fallingBehind ? 'falling behind' : worst.label.toLowerCase()}' : '${alerting.length} members need attention',
                      body: alerting.length == 1
                          ? '${rope.member(alerting.first.memberId)?.displayName ?? 'A member'} is getting separated from the group. Please wait or check on them.'
                          : alerting.map((m) => rope.member(m.memberId)?.displayName ?? '?').join(', '),
                    )
                  else
                    _Banner(color: TsColors.green, icon: Icons.link, title: '${snap?.connectedCount ?? 0} / ${snap?.total ?? 0} Connected', body: 'All members are together'),
                ],
              ),
            ),
          ),
          // Right-side map controls
          Positioned(
            right: 12,
            bottom: 232,
            child: Column(
              children: [
                _RoundButton(icon: _follow ? Icons.my_location : Icons.location_searching, tooltip: 'Follow me', onTap: () => setState(() => _follow = true)),
                const SizedBox(height: 8),
                _RoundButton(icon: Icons.people_outline, tooltip: 'Participants', onTap: () => _membersSheet(context, rope)),
                if (rope.simulated) ...[const SizedBox(height: 8), _RoundButton(icon: Icons.science_outlined, tooltip: 'Demo scenarios', onTap: () => _scenarioSheet(context, rope))],
              ],
            ),
          ),
          // Bottom panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
                    _MemberStrip(rope: rope, onTap: (m) => _memberSheet(context, rope, m)),
                    Row(
                      children: [
                        Expanded(child: _Stat(rope.distanceKm < 1 ? '${(rope.distanceKm * 1000).round()} m' : '${rope.distanceKm.toStringAsFixed(2)} km', 'Distance')),
                        Expanded(child: _Stat(_fmt(rope.elapsed), 'Time')),
                        Expanded(child: _Stat(rope.elevationM == null ? '—' : '${rope.elevationM} m', 'Elevation')),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (alerting.isNotEmpty)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final p = rope.positions[alerting.first.memberId];
                                if (p != null) {
                                  setState(() => _follow = false);
                                  _map.move(_ll(p), 17);
                                }
                              },
                              icon: const Icon(Icons.map_outlined),
                              label: const Text('View on Map'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: rope.session.selfIsOrganizer
                                ? FilledButton.icon(
                                    onPressed: () => ref.read(ropeProvider.notifier).sendAction(RopeMessageType.groupAlert),
                                    icon: const Icon(Icons.campaign_outlined),
                                    label: const Text('Send Reminder'),
                                  )
                                : FilledButton.icon(
                                    onPressed: () => ref.read(ropeProvider.notifier).sendAction(RopeMessageType.waitForMe),
                                    icon: const Icon(Icons.front_hand_outlined),
                                    label: const Text('Wait for me'),
                                  ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _Quick(icon: Icons.thumb_up_alt_outlined, label: "I'm OK", onTap: () => ref.read(ropeProvider.notifier).sendAction(RopeMessageType.imOk)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _Quick(icon: Icons.front_hand_outlined, label: 'Wait for me', onTap: () => ref.read(ropeProvider.notifier).sendAction(RopeMessageType.waitForMe)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _Quick(icon: Icons.sos, label: 'Need help', color: TsColors.red, onTap: () => ref.read(ropeProvider.notifier).sendAction(RopeMessageType.needHelp)),
                          ),
                        ],
                      ),
                    if (rope.log.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('${rope.member(rope.log.first.fromMemberId)?.displayName ?? 'You'}: ${_messageLabel(rope.log.first.type)}', style: const TextStyle(fontSize: 12, color: TsColors.muted)),
                    ],
                    const SizedBox(height: 10),
                    if (rope.simulated || rope.session.selfIsOrganizer || _organizerLost(rope))
                      GestureDetector(
                        onLongPress: _ending ? null : () => _end(context, rope),
                        child: OutlinedButton.icon(
                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hold the button for a second.'))),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            foregroundColor: TsColors.danger,
                            side: const BorderSide(color: TsColors.danger),
                          ),
                          icon: _ending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.stop_circle_outlined, size: 18),
                          label: Text(
                            _ending
                                ? 'Ending for everyone…'
                                : rope.simulated
                                ? 'Hold to end session'
                                : rope.session.selfIsOrganizer
                                ? 'Hold to end for everyone'
                                : 'Organizer lost: hold to leave',
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'Only ${_organizerName(rope)} can end the trek. It ends on every phone together.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: TsColors.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
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

  String _messageLabel(RopeMessageType t) => switch (t) {
    RopeMessageType.imOk => "I'm OK",
    RopeMessageType.waitForMe => 'Wait for me',
    RopeMessageType.needHelp => 'Need help!',
    RopeMessageType.groupAlert => 'Group alert sent',
    RopeMessageType.stopGroup => 'Stop the group',
    RopeMessageType.position => 'Position update',
  };

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  bool _ending = false;
  bool _autoEnding = false;

  String _organizerName(RopeSessionState r) => r.member(r.session.organizerId)?.displayName ?? 'the organizer';

  /// A member may leave on their own only when the organizer's phone has been gone for 2 minutes.
  bool _organizerLost(RopeSessionState r) {
    final st = r.snapshot?.members[r.session.organizerId];
    final heard = [st?.lastDirectSeen, st?.lastChainSeen].whereType<DateTime>().fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    return DateTime.now().difference(heard ?? r.startedAt) > const Duration(minutes: 2);
  }

  Future<void> _end(BuildContext context, RopeSessionState rope) async {
    final forAll = !rope.simulated && rope.session.selfIsOrganizer;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(forAll ? 'End the trek for everyone?' : 'End Digital Rope?'),
        content: Text(forAll ? 'Do a headcount first. Every phone in the group stops tracking at the same moment.' : 'Ending stops tracking on this phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep tracking')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: TsColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(forAll ? 'End for everyone' : 'End session'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    setState(() => _ending = true);
    final ctrl = ref.read(ropeProvider.notifier);
    final summary = forAll ? await ctrl.endForAll() : await ctrl.end();
    if (context.mounted) context.pushReplacement('/group/${summary.sessionId}/summary');
  }

  /// The organizer ended the trek: end here too, no questions asked.
  Future<void> _endedByOrganizer(RopeSessionState rope) async {
    if (_autoEnding) return;
    _autoEnding = true;
    final name = _organizerName(rope);
    final summary = await ref.read(ropeProvider.notifier).end();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name ended the trek for everyone.')));
    context.pushReplacement('/group/${summary.sessionId}/summary');
  }

  void _membersSheet(BuildContext context, RopeSessionState rope) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ParticipantsSheet(
        onLocate: (id) {
          final p = rope.positions[id];
          if (p != null) {
            setState(() => _follow = false);
            _map.move(_ll(p), 17);
          }
        },
        onMemberTap: (m) {
          Navigator.pop(ctx);
          _memberSheet(context, rope, m);
        },
      ),
    );
  }

  String _lastSeen(RopeSessionState r, String id) {
    final st = r.snapshot?.members[id];
    if (st == null || st.lastSeen == null) return 'Not heard yet';
    final ago = DateTime.now().difference(st.lastSeen!).inSeconds;
    final via = st.viaChainOnly ? ' via chain' : '';
    return ago < 3 ? 'Heard just now$via' : 'Last heard ${ago}s ago$via';
  }

  void _memberSheet(BuildContext context, RopeSessionState rope, Member m) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final r = ref.watch(ropeProvider) ?? rope;
          final st = r.snapshot?.members[m.id];
          final state = st?.state ?? RopeState.connected;
          final pos = st?.lastKnownPosition ?? r.positions[m.id];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      MemberAvatar(initials: m.initials, size: 48, color: stateColor(state)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            Text(state.meaning, style: const TextStyle(color: TsColors.muted, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      _StateChip(state),
                    ],
                  ),
                  const SizedBox(height: 16),
                  InfoRow(icon: Icons.schedule, label: 'Last heard', value: _lastSeen(r, m.id)),
                  InfoRow(
                    icon: Icons.signal_cellular_alt,
                    label: 'Signal trend',
                    value: st?.rssiTrendDb == null
                        ? 'Not enough data'
                        : st!.rssiTrendDb! > 6
                        ? 'Weakening'
                        : st.rssiTrendDb! < -6
                        ? 'Improving'
                        : 'Steady',
                    color: TsColors.amber,
                  ),
                  InfoRow(icon: Icons.place_outlined, label: 'Last known position', value: pos == null ? 'Unknown' : '${pos.lat.toStringAsFixed(5)}, ${pos.lng.toStringAsFixed(5)}'),
                  if (state.isAlerting) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pos == null
                                ? null
                                : () {
                                    Navigator.pop(ctx);
                                    setState(() => _follow = false);
                                    _map.move(_ll(pos), 17);
                                  },
                            icon: const Icon(Icons.location_searching),
                            label: const Text('Locate'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: TsColors.red),
                            onPressed: () {
                              ref.read(ropeProvider.notifier).sendAction(RopeMessageType.stopGroup);
                              Navigator.pop(ctx);
                            },
                            icon: const Icon(Icons.pan_tool_outlined),
                            label: const Text('Stop Group'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _scenarioSheet(BuildContext context, RopeSessionState rope) {
    final ctrl = ref.read(ropeProvider.notifier);
    final first = rope.others.isEmpty ? null : rope.others.first;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          children: [
            const Text('Demo scenarios', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const Text('Thresholds are shortened in demo mode (warning after 8 s, separated after 20 s).', style: TextStyle(color: TsColors.muted, fontSize: 12)),
            const SizedBox(height: 8),
            if (first != null) ...[
              ListTile(
                leading: const Icon(Icons.timer_outlined, color: TsColors.primary),
                title: Text('Shoelace stop: ${first.displayName}'),
                subtitle: const Text('Goes silent, then catches up'),
                onTap: () {
                  ctrl.simulateShoelace(first.id);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.trending_down, color: TsColors.amber),
                title: Text('Drift away: ${first.displayName}'),
                subtitle: const Text('Signal fades, then drops out'),
                onTap: () {
                  ctrl.simulate(first.id, SimBehaviour.drifting);
                  Navigator.pop(ctx);
                },
              ),
              if (rope.others.length > 1)
                ListTile(
                  leading: const Icon(Icons.link, color: TsColors.green),
                  title: Text('Chain only: ${rope.others.last.displayName}'),
                  subtitle: const Text('Heard via a neighbour, not directly'),
                  onTap: () {
                    ctrl.simulate(rope.others.last.id, SimBehaviour.viaChain);
                    Navigator.pop(ctx);
                  },
                ),
              if (rope.others.length > 1)
                ListTile(
                  leading: const Icon(Icons.person_off_outlined, color: TsColors.red),
                  title: const Text('I fall behind'),
                  subtitle: const Text('Everyone else goes quiet at once'),
                  onTap: () {
                    for (final m in rope.others) {
                      ctrl.simulate(m.id, SimBehaviour.silent);
                    }
                    Navigator.pop(ctx);
                  },
                ),
            ],
            ListTile(
              leading: const Icon(Icons.restart_alt, color: TsColors.green),
              title: const Text('Everyone back together'),
              onTap: () {
                ctrl.simulateAllTogether();
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip(this.state);
  final RopeState state;
  @override
  Widget build(BuildContext context) {
    final c = stateColor(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c),
      ),
      child: Text(
        state.label,
        style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.title, required this.body, this.action});
  final Color color;
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.35), TsColors.surface),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(fontSize: 12.5, height: 1.3)),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  @override
  Widget build(BuildContext context) {
    final m = Material(
      color: TsColors.surface,
      shape: const CircleBorder(side: BorderSide(color: TsColors.outline)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 22)),
      ),
    );
    return tooltip == null ? m : Tooltip(message: tooltip!, child: m);
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(fontSize: 11, color: TsColors.muted)),
      ],
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({required this.icon, required this.label, required this.onTap, this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        foregroundColor: color ?? TsColors.text,
        side: BorderSide(color: color ?? TsColors.outline),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

/// Short, readable text for a Bluetooth failure instead of a platform stack trace.
String radioErrorText(String raw) {
  if (raw.contains('error code: 1')) return 'Bluetooth was busy with another scan. End the session and start it again.';
  if (raw.toLowerCase().contains('permission')) return 'Trail Seek needs Bluetooth and Nearby devices permission. Allow it in Settings.';
  if (raw.toLowerCase().contains('powered') || raw.toLowerCase().contains('turned off')) return 'Turn on Bluetooth to stay linked with your group.';
  final m = RegExp(r'Exception: ([^,\n]+)').firstMatch(raw);
  return m?.group(1) ?? raw.split('\n').first;
}

/// Everyone in the group with live distance from me (GPS) and when we last heard them.
class _MemberStrip extends StatelessWidget {
  const _MemberStrip({required this.rope, required this.onTap});
  final RopeSessionState rope;
  final void Function(Member m) onTap;

  @override
  Widget build(BuildContext context) {
    final others = rope.others;
    if (others.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: others.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final m = others[i];
            final color = stateColor(rope.stateOf(m.id));
            final pos = rope.positions[m.id];
            final at = rope.positionTimes[m.id];
            final me = rope.selfPosition;
            final metres = pos == null || me == null ? null : haversineMetres(me, pos);
            final st = rope.snapshot?.members[m.id];
            final heard = [st?.lastDirectSeen, st?.lastChainSeen].whereType<DateTime>().fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
            final ago = heard == null ? null : now.difference(heard).inSeconds;
            final dist = metres == null
                ? (pos == null ? 'Waiting for their GPS' : 'Waiting for my GPS')
                : metres < 1000
                ? '${metres.round()} m away'
                : '${(metres / 1000).toStringAsFixed(1)} km away';
            final fixAge = at == null ? null : now.difference(at).inSeconds;
            return GestureDetector(
              onTap: () => onTap(m),
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
                decoration: BoxDecoration(
                  color: TsColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.7)),
                ),
                child: Row(
                  children: [
                    MemberAvatar(initials: m.initials, avatar: m.avatarId == null ? null : Avatar.decode(m.avatarId), avatarId: m.avatarId, size: 40, color: color, ring: color),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(
                          dist,
                          style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13),
                        ),
                        Text(
                          [if (ago != null) ago < 3 ? 'heard now' : 'heard ${ago}s ago', if (fixAge != null && fixAge > 20) 'GPS ${fixAge}s old'].join(' · '),
                          style: const TextStyle(fontSize: 11, color: TsColors.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Teardrop map pin with the member's avatar, coloured by rope state.
class _Pin extends StatelessWidget {
  const _Pin({required this.member, required this.color});
  final Member member;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Icon(Icons.location_on, size: 66, color: color, shadows: const [Shadow(blurRadius: 8, color: Colors.black54)]),
        Padding(
          padding: const EdgeInsets.only(top: 9),
          child: MemberAvatar(initials: member.initials, avatar: member.avatarId == null ? null : Avatar.decode(member.avatarId), avatarId: member.avatarId, size: 30, color: color, ring: Colors.white),
        ),
      ],
    );
  }
}
