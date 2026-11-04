import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as digest;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/group_session.dart';
import '../rope/engine/rope_config.dart';
import '../rope/engine/rope_engine.dart';
import '../rope/engine/rope_models.dart';
import '../rope/rope_alerts.dart';
import '../rope/links/ble_peer_link.dart';
import '../rope/links/rope_roster.dart';

/// Bench test for the Digital Rope radio with two or more phones in a room.
/// Everyone types the same 6-letter code; one phone is the Host. The screen
/// shows what each phone hears, so the mesh can be proven before a trek.
class BleDiagnosticsScreen extends ConsumerStatefulWidget {
  const BleDiagnosticsScreen({super.key, this.autoCode, this.autoHost = false, this.autoName, this.autoSendAfter});

  /// From `trailseek://diag?code=TEST01&host=1&name=Pixel`: starts the radio immediately.
  final String? autoCode;
  final bool autoHost;
  final String? autoName;

  /// Seconds after start to send a `needHelp` automatically (bench scripts).
  final int? autoSendAfter;
  @override
  ConsumerState<BleDiagnosticsScreen> createState() => _BleDiagnosticsScreenState();
}

class _BleDiagnosticsScreenState extends ConsumerState<BleDiagnosticsScreen> {
  final _code = TextEditingController(text: 'TEST01');
  bool _host = true;
  BlePeerLink? _link;
  GroupSession? _session;
  RopeEngine? _engine;
  int _loggedEvents = 0;
  bool _wasIsolated = false;
  Timer? _autoSend;
  Timer? _tick;
  final List<String> _log = [];
  int _direct = 0;
  int _chain = 0;
  int _messages = 0;
  String? _error;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    final c = widget.autoCode;
    if (c != null && c.length == 6) {
      _code.text = c.toUpperCase();
      _host = widget.autoHost;
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  @override
  void dispose() {
    _stop();
    _code.dispose();
    super.dispose();
  }

  void _add(String line) {
    final t = DateTime.now();
    final stamp = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
    // Mirrored to logcat so a bench test can be read over adb: `logcat | grep BLEDIAG`.
    debugPrint('[BLEDIAG] $stamp $line');
    setState(() {
      _log.insert(0, '$stamp  $line');
      if (_log.length > 300) _log.removeLast();
    });
  }

  Future<void> _start() async {
    final user = ref.read(authProvider);
    final name = widget.autoName ?? user?.displayName ?? 'Tester';
    // Stable per-phone id even without an account, so a relaunch rejoins as the same member.
    final store = ref.read(localStoreProvider);
    var id = user?.id ?? store.rawString('diag_tester_id');
    if (id == null) {
      id = 'tester-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
      await store.setRaw('diag_tester_id', id);
    }
    final self = Member(id: id, displayName: name, role: _host ? MemberRole.organizer : MemberRole.member, memberIndex: _host ? 0 : unassignedMemberIndex, isSelf: true);
    final session = GroupSession(
      id: 'diag',
      code: _code.text.trim().toUpperCase(),
      name: 'Diagnostics',
      adventureId: '',
      adventureName: 'Bench test',
      date: DateTime.now(),
      expectedStart: DateTime.now(),
      plannedSize: 16,
      organizerId: _host ? id : 'pending',
      members: [self],
      status: SessionStatus.lobby,
      simulated: false,
      // BENCH ONLY: deterministic test key keeps two-code diagnostics usable.
      // Never use this derivation in real group creation or secure QR joins.
      securityKey: digest.sha256.convert(utf8.encode('trailseek-bench-only:${_code.text.trim().toUpperCase()}')).toString(),
    );
    final link = BlePeerLink(
      syncInterval: const Duration(seconds: 6),
      onRosterChanged: (members, organizerId) {
        final s = _session;
        if (s == null) return;
        final updated = GroupSession(
          id: s.id, code: s.code, name: s.name, adventureId: s.adventureId, adventureName: s.adventureName, date: s.date,
          expectedStart: s.expectedStart, plannedSize: s.plannedSize, organizerId: organizerId ?? s.organizerId, members: members,
          status: s.status, simulated: false,
          securityKey: s.securityKey,
        );
        _session = updated;
        _link?.updateSession(updated);
        for (final m in members) {
          _engine?.addMember(m.id);
        }
        _add('ROSTER ${members.map((m) => '#${m.memberIndex}:${m.displayName}').join(', ')}');
      },
    );
    _link = link;
    _session = session;
    _subs.add(link.syncStatus.listen((s) => _add('SYNC $s')));
    _engine = RopeEngine(selfId: id, memberIds: [id], startedAt: DateTime.now(), config: const RopeConfig());
    _subs.add(link.observations.listen((o) {
      _engine?.observe(o);
      if (o.viaChain) {
        _chain++;
      } else {
        _direct++;
      }
      if ((_direct + _chain) % 10 == 1) _add('HEARD ${o.memberId.substring(0, o.memberId.length.clamp(0, 8))} ${o.viaChain ? 'via chain (hops ${o.hops})' : 'direct rssi ${o.rssi}'}');
    }));
    _subs.add(link.messages.listen((m) {
      _messages++;
      _add('MSG ${m.type.name} from ${m.fromMemberId.substring(0, m.fromMemberId.length.clamp(0, 8))}');
    }));
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {});
      final eng = _engine;
      if (eng != null && eng.memberIds.isNotEmpty) {
        final snap = eng.tick(DateTime.now());
        final names = {for (final m in _session?.members ?? const <Member>[]) m.id: m.displayName};
        for (var i = _loggedEvents; i < eng.events.length; i++) {
          final e = eng.events[i];
          final name = names[e.memberId] ?? e.memberId;
          _add('STATE $name ${e.from.name} -> ${e.to.name}');
          if (e.to.isAlerting || e.from.isAlerting) RopeAlerts.instance.memberChanged(name, e.to);
        }
        _loggedEvents = eng.events.length;
        if (snap.selfIsolated != _wasIsolated) {
          _wasIsolated = snap.selfIsolated;
          _add(snap.selfIsolated ? 'SELF isolated (group moving away)' : 'SELF back with the group');
          RopeAlerts.instance.selfIsolated(snap.selfIsolated);
        }
      }
      final l = _link;
      if (l != null && DateTime.now().second % 30 == 0) {
        _add('STATUS adv=${l.isAdvertising} heard=${l.packetsHeard} direct=$_direct chain=$_chain peers=${l.peerSnapshot.map((p) => '#${p.index}:${p.rssi}dBm/${p.ageSec}s').join(' ')} myIndex=${_session?.self?.memberIndex}');
      }
    });
    setState(() => _error = null);
    _add('START as ${_host ? 'HOST (#0)' : 'member (unassigned)'} code ${session.code}');
    try {
      await link.start(session: session, self: self);
      _add('Bluetooth up: advertising=${link.isAdvertising}, central=${link.centralState.name}');
      final after = widget.autoSendAfter;
      if (after != null) {
        _autoSend = Timer(Duration(seconds: after), () {
          _add('SENT needHelp (auto)');
          link.send(RopeMessage(type: RopeMessageType.needHelp, fromMemberId: _session?.self?.id ?? '', at: DateTime.now()));
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
      _add('ERROR $e');
    }
  }

  Future<void> _stop() async {
    _tick?.cancel();
    _tick = null;
    _autoSend?.cancel();
    _autoSend = null;
    _wasIsolated = false;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final l = _link;
    _link = null;
    _engine?.dispose();
    _engine = null;
    _loggedEvents = 0;
    if (l != null) {
      try {
        await l.stop();
      } catch (_) {}
      l.dispose();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final link = _link;
    final running = link != null;
    final peers = link?.peerSnapshot ?? const [];
    final members = _session?.members ?? const <Member>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth diagnostics'),
        actions: [
          IconButton(
            tooltip: 'Share log',
            onPressed: _log.isEmpty ? null : () => SharePlus.instance.share(ShareParams(text: 'Trail Seek BLE diagnostics\n${_log.reversed.join('\n')}')),
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          const Text('Two or more phones, same code, one Host. Keep screens on, stand a few metres apart, then walk away from each other and watch the heard counts and ages.', style: TsText.caption),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  enabled: !running,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]'))],
                  decoration: const InputDecoration(labelText: 'Test code', counterText: ''),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  const Text('Host', style: TsText.caption),
                  Switch(value: _host, onChanged: running ? null : (v) => setState(() => _host = v)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          running ? NeonButton(label: 'Stop', danger: true, icon: Icons.stop, onPressed: _stop) : NeonButton(label: 'Start radio', icon: Icons.bluetooth_searching, onPressed: _start),
          if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: TsColors.danger))],
          const SectionHeader('Status'),
          TsCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _row('Advertising', running ? (link.isAdvertising ? 'yes' : 'no') : '—'),
                const Divider(indent: 16),
                _row('Packets heard', '${link?.packetsHeard ?? 0}'),
                const Divider(indent: 16),
                _row('Observations', 'direct $_direct · via chain $_chain'),
                const Divider(indent: 16),
                _row('Messages', '$_messages'),
                const Divider(indent: 16),
                _row('My index', running ? '${_session?.self?.memberIndex == unassignedMemberIndex ? 'unassigned (waiting for host)' : _session?.self?.memberIndex}' : '—'),
              ],
            ),
          ),
          const SectionHeader('Peers in range'),
          if (peers.isEmpty) const Text('None yet', style: TsText.caption),
          for (final p in peers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.phone_android, color: p.ageSec < 10 ? TsColors.neon : TsColors.textMuted),
              title: Text(p.index == unassignedMemberIndex ? 'Joiner (unassigned)' : 'Member #${p.index}${p.index == 0 ? ' (host)' : ''}'),
              subtitle: Text('rssi ${p.rssi} dBm · heard ${p.ageSec}s ago'),
            ),
          const SectionHeader('Roster'),
          if (members.isEmpty) const Text('—', style: TsText.caption),
          for (final m in members) Text('#${m.memberIndex == unassignedMemberIndex ? '?' : m.memberIndex}  ${m.displayName}${m.isSelf ? ' (me)' : ''}${m.role == MemberRole.organizer ? ' · host' : ''}', style: TsText.body),
          if (running) ...[
            const SectionHeader('Send'),
            Wrap(
              spacing: 8,
              children: [
                for (final t in [RopeMessageType.imOk, RopeMessageType.waitForMe, RopeMessageType.needHelp])
                  GhostButton(label: t.name, expanded: false, onPressed: () { _add('SENT ${t.name}'); link.send(RopeMessage(type: t, fromMemberId: _session?.self?.id ?? '', at: DateTime.now())); }),
              ],
            ),
          ],
          const SectionHeader('Log'),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: TsColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: TsColors.outline)),
            child: Text(_log.take(60).join('\n'), style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.35)),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => ListTile(dense: true, title: Text(k), trailing: Text(v, style: TsText.bodyStrong));
}
