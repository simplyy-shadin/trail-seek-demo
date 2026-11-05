import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/links.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/avatar.dart';
import '../../data/models/group_session.dart';
import '../rope/rope_controller.dart';
import 'lobby_sync.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key, required this.sessionId});
  final String sessionId;
  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  String get sessionId => widget.sessionId;
  late final LobbySyncController _sync;
  Timer? _countdown;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    _sync = ref.read(lobbySyncProvider.notifier);
    // Redraw the "start together" countdown.
    _countdown = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && ref.read(lobbySyncProvider).startAt != null) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = ref.read(sessionByIdProvider(sessionId));
      if (s != null && !s.simulated && s.status != SessionStatus.active) _sync.start(s);
    });
  }

  @override
  void dispose() {
    // Captured in initState: ref must not be used once the widget is unmounted.
    _countdown?.cancel();
    final sync = _sync;
    Future.microtask(sync.stop);
    super.dispose();
  }

  /// Starts the rope on this phone at the group's start moment and opens the live screen.
  Future<void> _launch(GroupSession s, DateTime startedAt) async {
    if (_launching) return;
    setState(() => _launching = true);
    _countdown?.cancel();
    await ref.read(lobbySyncProvider.notifier).stop();
    final repo = ref.read(adventureRepositoryProvider);
    final a = await repo.byId(s.adventureId) ?? (await repo.all()).first;
    final active = await ref.read(groupProvider.notifier).setStatus(s.id, SessionStatus.active, startedAt: startedAt);
    await ref.read(ropeProvider.notifier).start(session: active, adventure: a);
    if (mounted) context.pushReplacement('/group/${s.id}/live');
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(lobbySyncProvider);
    final s = ref.watch(sessionByIdProvider(sessionId));
    if (s == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Group not found')),
      );
    }
    if (s.status == SessionStatus.active) {
      // Already walking: hand straight over to the live screen and leave the radio to the rope.
      WidgetsBinding.instance.addPostFrameCallback((_) => context.pushReplacement('/group/${s.id}/live'));
    } else if (!s.simulated && !_launching && ModalRoute.of(context)?.isCurrent != false) {
      // Only while the lobby is on top: under the checklist or live screen the
      // rope owns the radio, and a second scan fails with error code 1.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_launching && ModalRoute.of(context)?.isCurrent != false) _sync.start(s);
      });
    }
    final pendingOrganizer = s.organizerId == 'pending';
    final joined = s.members.length;
    final canStart = joined >= 2 && (s.simulated || (s.securityKey != null && (s.self?.memberIndex ?? 255) != 255));
    final link = AppLinks.joinDeepLink(s.code, securityKey: s.securityKey);
    final startAt = s.simulated || sync.waiting ? null : sync.startAt;
    final organizerName = s.members.where((m) => m.id == s.organizerId).firstOrNull?.displayName ?? 'the organizer';
    final left = startAt?.difference(DateTime.now());
    if (left != null && left <= Duration.zero && canStart && !_launching) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _launch(s, startAt!));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group lobby'),
        actions: [
          IconButton(
            onPressed: (!s.simulated && s.securityKey == null) ? null : () => SharePlus.instance.share(
              ShareParams(
                text: AppLinks.groupInvite(groupName: s.name, adventureName: s.adventureName, date: DateFormat('d MMM').format(s.date), code: s.code, securityKey: s.securityKey),
              ),
            ),
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 230),
        children: [
          const Text(
            'Your Group is Ready!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Share the private QR invitation with trusted group members. The short code alone cannot authorize a real Bluetooth join.',
            textAlign: TextAlign.center,
            style: TextStyle(color: TsColors.muted),
          ),
          if (!s.simulated && s.securityKey == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('This group predates secure invitations. Create a new real group before using Bluetooth.', textAlign: TextAlign.center, style: TextStyle(color: Colors.orange)),
            ),
          const SizedBox(height: 22),
          if (s.simulated || s.securityKey != null)
            Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: QrImageView(data: link, version: QrVersions.auto, size: 200, backgroundColor: Colors.white),
            ),
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: (!s.simulated && s.securityKey == null) ? null : () {
              Clipboard.setData(ClipboardData(text: s.simulated ? s.code : link));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation copied')));
            },
            child: Column(
              children: [
                Text(
                  s.code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 34, letterSpacing: 8, fontWeight: FontWeight.w900),
                ),
                Text(s.simulated ? 'tap to copy demo code' : (s.securityKey == null ? 'create a new group to invite' : 'tap to copy secure invitation'), style: const TextStyle(fontSize: 11, color: TsColors.muted)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${s.adventureName}  •  ${DateFormat('d MMM yyyy').format(s.date)}  •  ${DateFormat('h:mm a').format(s.expectedStart)}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: TsColors.muted),
          ),
          const SizedBox(height: 22),
          if (!s.simulated)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: TsColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: sync.error != null ? TsColors.danger : TsColors.outline),
                ),
                child: Row(
                  children: [
                    if (sync.running && sync.error == null)
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Icon(sync.error != null ? Icons.bluetooth_disabled : Icons.bluetooth, color: sync.error != null ? TsColors.danger : TsColors.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sync.error ?? (sync.status.isEmpty ? 'Bluetooth sync' : sync.status), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          Text(
                            pendingOrganizer
                                ? 'Stand within a few metres of the organizer\'s phone. Keep this screen open.'
                                : '${sync.peersInRange} phone${sync.peersInRange == 1 ? '' : 's'} in range · everyone taps Start on their own phone',
                            style: const TextStyle(fontSize: 12, color: TsColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: TsColors.surface, borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(joined >= s.plannedSize ? Icons.check_circle : Icons.hourglass_top, color: joined >= s.plannedSize ? TsColors.green : TsColors.amber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$joined / ${s.plannedSize} Members Joined',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (s.simulated)
                      const Chip(
                        label: Text('DEMO', style: TextStyle(fontSize: 10)),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in s.members)
                      Tooltip(
                        message: '${m.displayName}${m.role == MemberRole.organizer ? ' (organizer)' : ''}',
                        child: MemberAvatar(
                          initials: m.initials,
                          avatar: m.avatarId == null ? null : Avatar.decode(m.avatarId),
                          avatarId: m.avatarId,
                          size: 42,
                          color: m.isSelf ? TsColors.primary.withValues(alpha: 0.3) : null,
                          ring: m.role == MemberRole.organizer ? TsColors.primary : null,
                        ),
                      ),
                    for (var i = joined; i < s.plannedSize; i++) const MemberAvatar(initials: '+', size: 42),
                  ],
                ),
                if (s.simulated && joined < s.plannedSize) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(onPressed: () => ref.read(groupProvider.notifier).addSimulatedMembers(s.id), icon: const Icon(Icons.person_add_alt), label: const Text('Add demo members')),
                ],
              ],
            ),
          ),
          if (!s.simulated) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: TsColors.neon.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TsColors.neon.withValues(alpha: 0.6)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.phone_android, color: TsColors.neon),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Only the organizer starts and ends the trek. Members can ask to start; when the organizer accepts, every phone counts down 10 seconds and starts together. Keep Trail Seek open.',
                      style: TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          for (final m in s.members)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: MemberAvatar(initials: m.initials, avatar: m.avatarId == null ? null : Avatar.decode(m.avatarId), avatarId: m.avatarId),
              title: Text(m.isSelf ? '${m.displayName} (you)' : m.displayName),
              subtitle: Text(m.role == MemberRole.organizer ? 'Organizer' : (m.memberIndex == 255 ? 'Waiting for the organizer to confirm…' : 'Member · slot ${m.memberIndex}')),
              trailing: const Icon(Icons.check, color: TsColors.green, size: 18),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!canStart)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  (s.self?.memberIndex ?? 0) == 255 ? 'Waiting to be added by the organizer…' : 'Need at least 2 members to start Digital Rope.',
                  style: const TextStyle(color: TsColors.muted, fontSize: 12),
                ),
              ),
            if (startAt != null && left != null)
              _CountdownCard(
                seconds: left.inMilliseconds <= 0 ? 0 : (left.inMilliseconds / 1000).ceil(),
                organizer: s.selfIsOrganizer,
                organizerName: organizerName,
                onCancel: s.selfIsOrganizer ? () => ref.read(lobbySyncProvider.notifier).wait(organizer: true) : null,
              )
            else if (s.simulated)
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: TsColors.green),
                onPressed: canStart
                    ? () async {
                        await ref.read(lobbySyncProvider.notifier).stop();
                        await ref.read(groupProvider.notifier).setStatus(s.id, SessionStatus.checklist);
                        if (context.mounted) context.push('/group/${s.id}/checklist');
                      }
                    : null,
                child: const Text('Start Adventure'),
              )
            else if (s.selfIsOrganizer) ...[
              // Members asked to start: the organizer accepts for everyone.
              for (final who in sync.requests.take(1))
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  decoration: BoxDecoration(
                    color: TsColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: TsColors.neon),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.front_hand_outlined, color: TsColors.neon),
                      const SizedBox(width: 10),
                      Expanded(child: Text(sync.requests.length > 1 ? '$who and ${sync.requests.length - 1} more are ready to start' : '$who is ready to start', style: TsText.bodyStrong)),
                      TextButton(onPressed: () => ref.read(lobbySyncProvider.notifier).dismissRequests(), child: const Text('Not yet')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: TsColors.green),
                        onPressed: canStart ? () => ref.read(lobbySyncProvider.notifier).startTogether() : null,
                        child: const Text('Accept'),
                      ),
                    ],
                  ),
                ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: TsColors.green, minimumSize: const Size.fromHeight(52)),
                onPressed: canStart ? () => ref.read(lobbySyncProvider.notifier).startTogether() : null,
                icon: const Icon(Icons.timer_outlined),
                label: const Text('Start for everyone (10 s)'),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  sync.asked ? 'Asked $organizerName to start. Waiting for them to accept…' : 'Only $organizerName can start. Everyone starts together.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: TsColors.muted, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: canStart && !sync.asked ? () => ref.read(lobbySyncProvider.notifier).askToStart() : null,
                icon: Icon(sync.asked ? Icons.hourglass_top : Icons.front_hand_outlined),
                label: Text(sync.asked ? 'Waiting for $organizerName' : 'Ask $organizerName to start'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.seconds, required this.organizer, required this.organizerName, this.onCancel});
  final int seconds;
  final bool organizer;
  final String organizerName;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: TsColors.neon.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TsColors.neon),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(organizer ? 'Starting the group together' : '$organizerName is starting the trek', style: TsText.bodyStrong, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            seconds > 0 ? '$seconds' : 'Go!',
            style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w900, color: TsColors.neon, height: 1.1),
          ),
          const Text('Every phone starts at the same moment', style: TextStyle(color: TsColors.muted, fontSize: 12)),
          if (onCancel != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              onPressed: onCancel,
              icon: const Icon(Icons.front_hand_outlined),
              label: const Text('Wait, stop the countdown'),
            ),
          ],
        ],
      ),
    );
  }
}
