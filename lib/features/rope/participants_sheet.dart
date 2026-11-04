import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/avatar.dart';
import '../../data/models/group_session.dart';
import '../settings/settings_controller.dart';
import 'engine/rope_models.dart';
import 'participant_distance.dart';
import 'rope_controller.dart';

Color ropeStateColor(RopeState s) => switch (s) {
      RopeState.connected => TsColors.ropeConnected,
      RopeState.weak => TsColors.ropeWeak,
      RopeState.fallingBehind => TsColors.ropeFallingBehind,
      RopeState.separated => TsColors.ropeSeparated,
      RopeState.critical => TsColors.ropeCritical,
    };

/// Digital Rope state → the simple Online / Offline wording of the mockup.
bool isOnline(RopeState s) => s == RopeState.connected || s == RopeState.weak;

String lastHeardLabel(RopeSessionState r, String memberId, DateTime now) {
  final st = r.snapshot?.members[memberId];
  if (st == null || st.lastSeen == null) return 'Not heard yet';
  final ago = now.difference(st.lastSeen!);
  final via = st.viaChainOnly ? ' via chain' : '';
  if (ago.inSeconds < 3) return 'Online$via';
  if (ago.inSeconds < 60) return '${ago.inSeconds}s ago$via';
  return '${ago.inMinutes} min ago$via';
}

/// Frame 10 bottom half: participants with status, distance and controls.
class ParticipantsSheet extends ConsumerWidget {
  const ParticipantsSheet({super.key, required this.onLocate, required this.onMemberTap});
  final void Function(String memberId) onLocate;
  final void Function(Member member) onMemberTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(ropeProvider);
    final units = ref.watch(unitsProvider);
    if (r == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final guideId = r.session.organizerId;
    final guidePos = guideId == r.self?.id ? r.selfPosition : r.positions[guideId];
    final guideAt = guideId == r.self?.id ? r.selfPositionAt : r.positionTimes[guideId];
    final online = r.others.where((m) => isOnline(r.stateOf(m.id))).length;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        children: [
          Row(
            children: [
              Expanded(child: Text('Participants', style: TsText.h2)),
              Text('$online / ${r.others.length} online', style: TsText.caption),
            ],
          ),
          const SizedBox(height: 8),
          for (final m in r.session.members)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: MemberAvatar(
                initials: m.initials,
                avatar: m.avatarId == null ? null : Avatar.decode(m.avatarId),
                avatarId: m.avatarId,
                color: m.isSelf ? TsColors.selfMarker.withValues(alpha: 0.25) : ropeStateColor(r.stateOf(m.id)).withValues(alpha: 0.25),
                ring: m.isSelf ? TsColors.selfMarker : ropeStateColor(r.stateOf(m.id)),
                size: 42,
              ),
              title: Text(m.isSelf ? '${m.displayName} (you)' : m.displayName, style: TsText.bodyStrong),
              subtitle: m.isSelf
                  ? Text(m.id == guideId ? 'Guide · this phone' : 'This phone', style: TsText.caption)
                  : StatusDot(
                      color: isOnline(r.stateOf(m.id)) ? TsColors.neon : TsColors.textMuted,
                      text: [
                        isOnline(r.stateOf(m.id)) ? 'Online' : 'Offline · ${lastHeardLabel(r, m.id, now)}',
                        ?coarseDistance(a: guidePos, aAt: guideAt, b: r.positions[m.id], bAt: r.positionTimes[m.id], now: now, metric: units.metric),
                      ].join(' · '),
                    ),
              trailing: m.isSelf
                  ? (m.id == guideId ? const Chip(label: Text('Guide', style: TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact) : null)
                  : const Icon(Icons.chevron_right, color: TsColors.textMuted),
              onTap: m.isSelf ? null : () => onMemberTap(m),
            ),
        ],
      ),
    );
  }
}
