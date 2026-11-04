import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../../data/models/group_session.dart';
import '../engine/rope_config.dart';
import '../engine/rope_models.dart';
import 'peer_link.dart';
import 'rope_packet.dart';
import 'rope_roster.dart';
import 'rope_action_relay.dart';
import 'rope_control_frame.dart';
import 'rope_safety_relay.dart';
import 'rope_security.dart';

/// Cross-platform Bluetooth Low Energy transport for the Digital Rope.
///
/// Two layers, both without pairing:
/// 1. **Heartbeats** (advertising + scanning). Every phone broadcasts an
///    8-byte packet and hears every other phone in radio range directly. The
///    packet's gossip bitmap says "who I hear", which gives one-hop relay.
///    There is no fixed chain: links form wherever phones happen to be.
/// 2. **Roster sync** (short GATT reads/writes, every ~10 s, to 1–2 nearby
///    phones). Each phone serves a table of members with "seconds since last
///    heard". Reading a neighbour's table and adding the transfer delay gives
///    multi-hop reachability with no loops, because ages only grow as they
///    travel. The same table carries the member list, so joining by code
///    works with no internet: the joiner writes a join request to the
///    organizer, who assigns the next free index.
///
/// Field testing (task 18) is still owed: iOS strips the local name in the
/// background, so there the GATT path is the only one that keeps working.
class BlePeerLink implements PeerLink {
  BlePeerLink({
    this.config = const RopeConfig(),
    this.onRosterChanged,
    this.onSessionInfo,
    this.onPosition,
    this.onStartRequest,
    this.onGroupEnd,
    this.onLog,
    this.syncInterval = const Duration(seconds: 10),
  });

  /// Organizer side: a member asked to start the group.
  final void Function(Member who)? onStartRequest;

  /// Member side: the organizer ended the trek for everyone.
  final void Function()? onGroupEnd;

  /// Member: ask the organizer to start (rides on every heartbeat while true).
  bool requestingStart = false;

  /// Organizer: tell everyone the trek is over (rides on every heartbeat while true).
  bool ending = false;

  /// A newer GPS fix for another member, read from a neighbour's roster.
  final void Function(String memberId, MemberFix fix)? onPosition;

  /// Group details read from the organizer's phone (adventure, date, name).
  final void Function(SessionInfo info)? onSessionInfo;

  /// Optional sink for one-line transport events (bench tests read it over logcat).
  final void Function(String line)? onLog;
  void _log(String line) => onLog?.call(line);
  void _status(String line) {
    if (!_syncState.isClosed) _syncState.add(line);
  }

  static final serviceUuid = UUID.fromString('7a5e0001-5eeb-4c0d-9e1a-7261696c7365');
  static final rosterCharacteristicUuid = UUID.fromString('7a5e0002-5eeb-4c0d-9e1a-7261696c7365');

  final RopeConfig config;
  final Duration syncInterval;

  /// Called when roster sync learns new members or our assigned index.
  final void Function(List<Member> members, String? organizerId)? onRosterChanged;

  final _central = CentralManager();
  final _peripheral = PeripheralManager();
  final _obs = StreamController<PeerObservation>.broadcast();
  final _msg = StreamController<RopeMessage>.broadcast();
  RopeActionRelay? _actionRelay;
  int? _pendingActionSequence;
  final _syncState = StreamController<String>.broadcast();
  final _safetyAlerts = StreamController<SafetyAlert>.broadcast();
  SafetyAlertRelay? _safetyRelay;
  RopeSecurity? _security;
  Uint8List? _rosterCipherCache;
  DateTime? _rosterCacheAt;
  final Map<int, DateTime> _lastHintSync = {};
  int _controlSequence = 0;
  final List<StreamSubscription> _subs = [];

  GroupSession? _session;
  Member? _self;
  int _sessionHash = 0;
  int _seq = 0;
  int _pendingFlags = 0;
  int _pendingFlagBeats = 0;
  Timer? _timer;
  Timer? _syncTimer;
  bool _advertising = false;
  bool _syncing = false;
  int _roundRobin = 0;

  /// memberIndex -> last time we heard them directly (gossip bitmap).
  final Map<int, DateTime> _recentDirect = {};

  /// memberId -> last heard (direct or relayed), served in our roster.
  final Map<String, DateTime> _lastHeard = {};

  /// memberIndex -> last flags byte seen (to de-duplicate action messages).
  final Map<int, int> _lastFlags = {};

  /// Peripherals we have discovered for this session, by member index.
  final Map<int, _Peer> _peers = {};

  /// memberId -> newest GPS fix we know (our own and relayed), served in our roster.
  final Map<String, MemberFix> _positions = {};

  /// Organizer only: the "start together" moment served to the group.
  DateTime? startAt;

  static final startCancelled = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  /// Push the current flags out now instead of on the next heartbeat.
  Future<void> beatNow() => _beat();

  /// Organizer only: set the group start and advertise it at once. Null
  /// cancels it, sent as the Unix epoch so members can tell "cancelled" apart
  /// from "this phone no longer serves a start time".
  Future<void> announceStart(DateTime? at) async {
    startAt = at ?? startCancelled;
    await _beat();
  }

  /// Our own GPS fix, shared with the group on the next roster read.
  void updateSelfPosition(double lat, double lng, DateTime at) {
    final id = _self?.id;
    if (id != null) _positions[id] = (lat: lat, lng: lng, at: at);
  }

  @override
  Stream<PeerObservation> get observations => _obs.stream;
  @override
  Stream<RopeMessage> get messages => _msg.stream;

  /// Human-readable sync progress for the lobby ("Found organizer", "Joined as #3").
  Stream<String> get syncStatus => _syncState.stream;

  /// Unseen automatic warnings, received either directly or via GATT relays.
  Stream<SafetyAlert> get safetyAlerts => _safetyAlerts.stream;

  /// Report a local state change to reachable peers without a manual SOS tap.
  /// The local UI handles its own notification; this method handles delivery.
  Future<void> broadcastSafetyAlert({required String subjectId, required SafetySignal signal}) async {
    final s = _session;
    final self = _self;
    final relay = _safetyRelay;
    if (_stopped || s == null || self == null || relay == null) return;
    if (self.memberIndex < 0 || self.memberIndex >= 16) return;
    final subject = s.members.where((m) => sameMember(m.id, subjectId)).firstOrNull;
    if (subject == null || subject.memberIndex < 0 || subject.memberIndex >= 16) return;
    relay.create(reporterIndex: self.memberIndex, subjectIndex: subject.memberIndex,
        signal: signal, now: DateTime.now());
    await _beat(); // Fast, one-hop BLE advertisement while signal still exists.
    if (!_syncing) unawaited(_syncRound()); // GATT pushes beyond the first hop.
  }

  @override
  bool get isSimulated => false;

  int get peersInRange => _peers.values.where((p) => DateTime.now().difference(p.lastSeen) < const Duration(seconds: 15)).length;

  /// Snapshot for diagnostics: (memberIndex, rssi, seconds since last heard).
  List<({int index, int rssi, int ageSec})> get peerSnapshot {
    final now = DateTime.now();
    return [for (final e in _peers.entries) (index: e.key, rssi: e.value.rssi, ageSec: now.difference(e.value.lastSeen).inSeconds)]..sort((a, b) => a.ageSec.compareTo(b.ageSec));
  }

  bool get isAdvertising => _advertising;
  int get packetsHeard => _packetsHeard;
  int _packetsHeard = 0;
  bool get hasOrganizerNearby => _peers.containsKey(0);
  BluetoothLowEnergyState get centralState => _central.state;

  /// Keep the served roster current when the controller changes the session.
  void updateSession(GroupSession session) {
    _session = session;
    _self = session.self ?? _self;
  }

  /// The platform has one BLE stack. Whichever link started last owns scanning,
  /// advertising and the GATT service; an older link's stop() must not tear
  /// down what the newer one set up (lobby radio vs rope radio hand-over).
  static BlePeerLink? _radioOwner;
  bool _stopped = false;

  /// Stopped, or another link took the radio while start() was still awaiting.
  /// Without this check a lobby link stopped mid-start came back to life and
  /// ran next to the rope's link.
  bool get _abandoned => _stopped || _radioOwner != this;
  Timer? _syncKickoff;

  @override
  Future<void> start({required GroupSession session, required Member self}) async {
    _stopped = false;
    // One radio user at a time: a lobby link still scanning would make this
    // scan fail with "Start discovery failed with error code: 1".
    final previous = _radioOwner;
    if (previous != null && previous != this) {
      _log('stopping previous link before start');
      await previous.stop();
    }
    _radioOwner = this;
    _session = session;
    _self = self;
    // Never allow a legacy six-character-code group onto the real BLE radio.
    if (!RopeSecurity.validKey(session.securityKey)) {
      throw StateError('This group needs a secure QR invitation. Create a new real group.');
    }
    _security = RopeSecurity(session.securityKey!);
    _rosterCipherCache = null;
    _rosterCacheAt = null;
    _sessionHash = RopePacket.hashCode16(session.code);
    _actionRelay = RopeActionRelay(sessionHash: _sessionHash);
    _pendingActionSequence = null;
    _pendingFlagBeats = 0;
    _pendingFlags = 0;
    _safetyRelay = SafetyAlertRelay(sessionHash: _sessionHash);

    _log('start protected-group self=${self.displayName}#${self.memberIndex}');
    if (Platform.isAndroid) await _ensureAndroidPermissions();
    if (_abandoned) return;
    await _waitPoweredOn(_central);
    await _waitPoweredOn(_peripheral);
    if (_abandoned) return;
    _log('radio on');

    _subs.add(_central.discovered.listen(_onDiscovered));

    await _peripheral.removeAllServices();
    if (_abandoned) return;
    await _peripheral.addService(
      GATTService(
        uuid: serviceUuid,
        isPrimary: true,
        includedServices: const [],
        characteristics: [
          GATTCharacteristic.mutable(
            uuid: rosterCharacteristicUuid,
            properties: const [GATTCharacteristicProperty.read, GATTCharacteristicProperty.write, GATTCharacteristicProperty.writeWithoutResponse],
            permissions: const [GATTCharacteristicPermission.read, GATTCharacteristicPermission.write],
            descriptors: const [],
          ),
        ],
      ),
    );
    if (_abandoned) return;
    _subs.add(_peripheral.characteristicReadRequested.listen(_onRosterRead));
    _subs.add(_peripheral.characteristicWriteRequested.listen(_onRosterWrite));

    try {
      await _central.stopDiscovery();
    } catch (_) {}
    await _central.startDiscovery(serviceUUIDs: [serviceUuid]);
    if (_abandoned) return;
    _timer = Timer.periodic(config.heartbeatInterval, (_) => _beat());
    await _beat();
    _log('advertising + scanning');
    // Phones that connect to each other at the same instant collide (GATT 133 /
    // timeouts). Offset each phone's sync phase by its slot, joiners first.
    final slot = self.memberIndex == unassignedMemberIndex ? 0 : self.memberIndex + 1;
    _syncKickoff = Timer(Duration(milliseconds: 2000 + slot * 1300), () {
      if (_stopped) return;
      _syncRound();
      _syncTimer = Timer.periodic(syncInterval, (_) => _syncRound());
    });
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
    _syncKickoff?.cancel();
    _syncKickoff = null;
    _syncTimer?.cancel();
    _syncTimer = null;
    _actionRelay = null;
    _pendingActionSequence = null;
    _safetyRelay = null;
    _security = null;
    _rosterCipherCache = null;
    _rosterCacheAt = null;
    _lastHintSync.clear();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    if (_radioOwner != this) {
      _log('stop (radio owned by a newer link; left running)');
      return;
    }
    _radioOwner = null;
    try {
      await _central.stopDiscovery();
    } catch (_) {}
    if (_advertising) {
      try {
        await _peripheral.stopAdvertising();
      } catch (_) {}
      _advertising = false;
    }
    try {
      await _peripheral.removeAllServices();
    } catch (_) {}
  }

  @override
  Future<void> send(RopeMessage message) async {
    final flag = switch (message.type) {
      RopeMessageType.imOk => RopePacket.flagImOk,
      RopeMessageType.waitForMe => RopePacket.flagWaitForMe,
      RopeMessageType.needHelp => RopePacket.flagNeedHelp,
      RopeMessageType.groupAlert => RopePacket.flagGroupAlert,
      RopeMessageType.stopGroup => RopePacket.flagStopGroup,
      RopeMessageType.position => 0,
    };
    if (flag == 0) return;
    // Actions ride on the next few heartbeats so a single dropped
    // advertisement does not lose them.
    final self = _self;
    final relay = _actionRelay;
    if (_stopped || self == null || relay == null ||
        self.memberIndex < 0 || self.memberIndex >= 16) return;
    final created = relay.create(
      originIndex: self.memberIndex, type: message.type, now: DateTime.now(),
    );
    _pendingActionSequence = created.sequence;
    _pendingFlags = flag;
    _pendingFlagBeats = 8;
    _msg.add(message);
    await _beat();
    if (!_syncing) unawaited(_syncRound());
  }

  // ------------------------------------------------------------ heartbeats

  RopePacket _buildPacket() {
    final now = DateTime.now();
    // Quick actions take precedence while the message is advertised.
    final advertisingAction = _pendingFlagBeats > 0;
    final safety = advertisingAction ? null : _safetyRelay?.localBeacon(now);
    final freshness = config.heartbeatInterval * 5;
    var gossip = 0;
    _recentDirect.forEach((idx, at) {
      if (idx < 16 && now.difference(at) <= freshness) gossip |= 1 << idx;
    });
    return RopePacket(
      sessionHash: _sessionHash,
      memberIndex: _self?.memberIndex ?? unassignedMemberIndex,
      seq: advertisingAction ? (_pendingActionSequence ?? _seq) : (safety?.sequence ?? _seq),
      safetySignal: safety?.signal,
      safetySubjectIndex: safety?.subjectIndex,
      actionV2: advertisingAction,
      flags: advertisingAction ? _pendingFlags : 0,
      gossip: gossip,
      starting: startAt != null && startAt!.isAfter(now),
      requestStart: requestingStart,
      ending: ending,
    );
  }

  Future<void> _beat() async {
    if (_stopped) return;
    _seq = (_seq + 1) & 0xFF;
    final packet = _buildPacket();
    if (_pendingFlagBeats > 0) _pendingFlagBeats--;
    try {
      if (_advertising) await _peripheral.stopAdvertising();
      await _peripheral.startAdvertising(Advertisement(name: packet.encode(), serviceUUIDs: [serviceUuid]));
      _advertising = true;
    } catch (_) {
      _advertising = false;
    }
  }

  void _onDiscovered(DiscoveredEventArgs e) {
    if (_stopped) return;
    final packet = RopePacket.decode(e.advertisement.name);
    if (packet == null || packet.sessionHash != _sessionHash) return;
    _packetsHeard++;
    final session = _session;
    final self = _self;
    if (session == null || self == null) return;
    final now = DateTime.now();
    _peers[packet.memberIndex] = _Peer(e.peripheral, now, e.rssi);
    if (packet.memberIndex == self.memberIndex || packet.memberIndex == unassignedMemberIndex) return;

    final byIndex = {for (final m in session.members) m.memberIndex: m};
    final sender = byIndex[packet.memberIndex];
    if (sender == null) return; // known index arrives with the next roster sync

    // Organizer started a countdown: fetch the start time now, not on the next round.
    if (packet.starting && packet.memberIndex == 0 && !_syncing && (_startKick == null || now.difference(_startKick!) > const Duration(seconds: 3))) {
      _startKick = now;
      _syncRound();
    }

    // Advertisements contain no room for a cryptographic tag, so treat all
    // manual actions, weak warnings and organizer controls as *untrusted hints*.
    // Only the authenticated GATT frames below may vibrate, start or end a group.
    if (packet.flags != 0 || packet.safetySignal != null ||
        packet.requestStart || packet.ending) {
      final previous = _lastHintSync[packet.memberIndex];
      if (previous == null || now.difference(previous) > const Duration(seconds: 3)) {
        _lastHintSync[packet.memberIndex] = now;
        if (!_syncing) unawaited(_syncRound());
      }
    }

    _recentDirect[packet.memberIndex] = now;
    _lastHeard[sender.id] = now;
    _obs.add(PeerObservation(memberId: sender.id, at: now, rssi: e.rssi));

    for (final m in session.members) {
      if (m.memberIndex == self.memberIndex || m.memberIndex == packet.memberIndex || m.memberIndex > 15) continue;
      if (packet.hears(m.memberIndex)) {
        _lastHeard[m.id] = now;
        _obs.add(PeerObservation(memberId: m.id, at: now, viaChain: true, hops: 1));
      }
    }

    // No action is dispatched from the unauthenticated advertising local name.
    // Full HMAC-protected GATT frames produce notifications in _onRosterWrite.
    _lastFlags[packet.memberIndex] = packet.flags;
  }

  // ---------------------------------------------------------- roster (GATT)

  Uint8List _rosterBytes() {
    final s = _session;
    if (s == null) return Uint8List(0);
    return RosterSnapshot.fromSession(s, sessionHash: _sessionHash, lastHeard: _lastHeard, now: DateTime.now(), positions: _positions, startAt: startAt).toBytes();
  }

  Future<Uint8List?> _encryptedRosterBytes() async {
    final security = _security;
    if (security == null) return null;
    final now = DateTime.now();
    if (_rosterCipherCache != null && _rosterCacheAt != null &&
        now.difference(_rosterCacheAt!) < const Duration(seconds: 5)) {
      return _rosterCipherCache;
    }
    final data = await security.encryptRoster(_rosterBytes());
    _rosterCipherCache = data;
    _rosterCacheAt = now;
    return data;
  }

  void _onRosterRead(GATTCharacteristicReadRequestedEventArgs e) {
    unawaited(_replyEncryptedRoster(e));
  }

  Future<void> _replyEncryptedRoster(GATTCharacteristicReadRequestedEventArgs e) async {
    try {
      final bytes = await _encryptedRosterBytes();
      if (_stopped || bytes == null) return;
      final offset = e.request.offset.clamp(0, bytes.length);
      _peripheral.respondReadRequestWithValue(e.request, value: bytes.sublist(offset));
    } catch (error) {
      _log('encrypted roster response failed: $error');
      // Fail closed: never fall back to an unencrypted roster.
    }
  }

  void _onRosterWrite(GATTCharacteristicWriteRequestedEventArgs e) {
    _peripheral.respondWriteRequest(e.request);
    final payload = _security?.verifyMessage(e.request.value);
    if (payload == null) {
      _log('rejected unauthenticated BLE write');
      return;
    }
    final control = RopeControlFrame.fromBytes(payload, now: DateTime.now());
    if (control != null) {
      _receiveControl(control);
      return;
    }
    final action = RopeActionFrame.fromBytes(payload);
    if (action != null) {
      _receiveAction(action, DateTime.now());
      return;
    }
    // Safety events share this write characteristic but never modify the roster.
    final safety = SafetyAlert.fromBytes(payload);
    if (safety != null) {
      _receiveSafetyAlert(safety, DateTime.now());
      return;
    }
    final join = JoinRequest.tryParse(payload);
    final s = _session;
    final self = _self;
    if (join == null || s == null || self == null) return;
    if (s.organizerId != self.id) return; // only the organizer assigns indices
    if (s.members.any((m) => sameMember(m.id, join.id))) return;
    final idx = RosterMerge.nextFreeIndex(s.members);
    if (idx == null) {
      _status('Group is full (16)');
      return;
    }
    final member = Member(id: join.id, displayName: join.name, role: MemberRole.member, memberIndex: idx, avatarId: join.avatarId);
    final members = [...s.members, member];
    _session = s.copyWith(members: members);
    _log('join request from ${join.name} -> #$idx');
    _status('${join.name} joined as #$idx');
    onRosterChanged?.call(members, s.organizerId);
  }

  void _receiveControl(RopeControlFrame control) {
    final s = _session;
    final self = _self;
    if (s == null || self == null) return;
    final member = s.members.where((m) => m.memberIndex == control.originIndex).firstOrNull;
    if (member == null) return;
    if (control.type == RopeControlType.requestStart && self.memberIndex == 0 &&
        control.originIndex != 0) {
      final last = _requestSeen[member.id];
      if (last == null || DateTime.now().difference(last) > const Duration(seconds: 5)) {
        onStartRequest?.call(member);
      }
      _requestSeen[member.id] = DateTime.now();
    } else if (control.type == RopeControlType.endGroup &&
        control.originIndex == 0 && self.memberIndex != 0 && !_endSeen) {
      _endSeen = true;
      onGroupEnd?.call();
    }
  }

  void _receiveSafetyAlert(SafetyAlert alert, DateTime now) {
    if (_stopped) return;
    final s = _session;
    if (s == null) return;
    // A 16-bit advertisement hash alone is not an identity credential: accept
    // only known indices from this session. The BLE session itself still needs
    // authenticated pairing before production safety guarantees are claimed.
    if (!s.members.any((m) => m.memberIndex == alert.reporterIndex) ||
        !s.members.any((m) => m.memberIndex == alert.subjectIndex)) return;
    if (_safetyRelay?.accept(alert, now: now) != true) return;
    if (!_safetyAlerts.isClosed) _safetyAlerts.add(alert);
    // Advance newly learned warnings toward our other neighbours immediately.
    if (!_syncing) unawaited(_syncRound());
  }

  void _receiveAction(RopeActionFrame action, DateTime now) {
    final group = _session;
    if (_stopped || group == null) return;
    final member = group.members
        .where((m) => m.memberIndex == action.originIndex).firstOrNull;
    if (member == null || _actionRelay?.accept(action, now: now) != true) {
      return;
    }
    if (!_msg.isClosed) {
      _msg.add(RopeMessage(
        type: action.type, fromMemberId: member.id, at: action.sentAt,
      ));
    }
    // Push toward neighbouring phones; on a busy sync round the next
    // scheduled round will pick up this queued event.
    if (!_syncing) unawaited(_syncRound());
  }

  /// Hard ceiling for one roster exchange (connect + discover + write + read + disconnect).
  static const _syncCap = Duration(seconds: 30);

  Future<void> _syncRound() async {
    if (_syncing || _stopped) return;
    final s = _session;
    final self = _self;
    if (s == null || self == null) return;
    _syncing = true;
    try {
      final now = DateTime.now();
      final fresh = _peers.entries.where((p) => now.difference(p.value.lastSeen) < const Duration(seconds: 20)).toList();
      if (fresh.isEmpty) {
        _status(self.memberIndex == unassignedMemberIndex ? 'Searching for your group nearby…' : 'No other phones in range');
        return;
      }
      if (self.memberIndex == unassignedMemberIndex) {
        final org = _peers[0];
        if (org == null || now.difference(org.lastSeen) > const Duration(seconds: 20)) {
          _status('Found the group. Waiting for the organizer\'s phone…');
          return;
        }
        _status('Joining…');
        _log('sync -> organizer (join)');
        await _syncWith(org.peripheral, join: JoinRequest(id: self.id, name: self.displayName, avatarId: self.avatarId), fromOrganizer: true)
            .timeout(_syncCap);
        return;
      }
      // Rotate through up to two nearby peers, strongest first, organizer always included when near.
      fresh.sort((a, b) => b.value.rssi.compareTo(a.value.rssi));
      final picks = <MapEntry<int, _Peer>>[];
      final org = fresh.where((p) => p.key == 0).firstOrNull;
      if (org != null && self.memberIndex != 0) picks.add(org);
      final others = fresh.where((p) => p.key != 0 && p.key != self.memberIndex && p.key != unassignedMemberIndex).toList();
      if (others.isNotEmpty) picks.add(others[_roundRobin++ % others.length]);
      if (picks.isEmpty) {
        final joiners = fresh.where((p) => p.key == unassignedMemberIndex).length;
        _status(joiners > 0 ? '$joiners phone${joiners == 1 ? '' : 's'} nearby joining…' : 'Group in range');
        return;
      }
      for (final p in picks.take(2)) {
        _log('sync -> #${p.key}');
        await _syncWith(p.value.peripheral, fromOrganizer: p.key == 0).timeout(_syncCap);
      }
    } on TimeoutException {
      _log('sync round capped at ${_syncCap.inSeconds}s');
      _status('A nearby phone stopped answering; retrying');
    } catch (e) {
      _log('sync error: $e');
      _status('Sync hiccup: $e');
    } finally {
      _syncing = false;
    }
  }

  DateTime? _lastTimeoutLog;
  DateTime? _startKick;
  final Map<String, DateTime> _requestSeen = {};
  bool _endSeen = false;

  Future<void> _syncWith(Peripheral peripheral, {JoinRequest? join, required bool fromOrganizer, bool retried = false}) async {
    final s = _session;
    final self = _self;
    if (s == null || self == null) return;
    try {
      try {
        await _central.connect(peripheral).timeout(const Duration(seconds: 8));
      } on PlatformException catch (e) {
        // 133 = Android's generic GATT connect failure, usually a collision; one retry after a short pause.
        if (!retried && (e.message ?? '').contains('133')) {
          await Future<void>.delayed(const Duration(milliseconds: 800));
          return await _syncWith(peripheral, join: join, fromOrganizer: fromOrganizer, retried: true);
        }
        rethrow;
      }
      try {
        try {
          await _central.requestMTU(peripheral, mtu: 247).timeout(const Duration(seconds: 5));
        } catch (_) {}
        final services = await _central.discoverGATT(peripheral).timeout(const Duration(seconds: 8));
        GATTCharacteristic? ch;
        for (final sv in services) {
          for (final c in sv.characteristics) {
            if (c.uuid == rosterCharacteristicUuid) ch = c;
          }
        }
        if (ch == null) return;
        if (join != null) {
          var max = 180;
          try {
            max = await _central.getMaximumWriteLength(peripheral, type: GATTCharacteristicWriteType.withResponse).timeout(const Duration(seconds: 5));
          } catch (_) {}
          final security = _security;
          if (security == null) return;
          final joined = security.signMessage(join.toBytes(maxBytes: (max - 17).clamp(20, 180)));
          if (joined.length > max) {
            _status('This phone GATT MTU is too small for secure join.');
            return;
          }
          await _central.writeCharacteristic(peripheral, ch,
            value: joined, type: GATTCharacteristicWriteType.withResponse)
            .timeout(const Duration(seconds: 8));
        }
        // Organizer/member control must also be MAC-protected; the
        // corresponding advertising bits only request an early sync.
        if (self.memberIndex != unassignedMemberIndex &&
            (requestingStart || ending)) {
          final kind = ending ? RopeControlType.endGroup : RopeControlType.requestStart;
          final control = RopeControlFrame(
            type: kind,
            originIndex: self.memberIndex,
            sequence: _controlSequence++ & 0xFF,
            createdAt: DateTime.now(),
          );
          await _central.writeCharacteristic(peripheral, ch,
            value: _security!.signMessage(control.toBytes()),
            type: GATTCharacteristicWriteType.withResponse)
            .timeout(const Duration(seconds: 5));
        }
        // Push a few distinct, bounded 12-byte warnings over the same GATT
        // connection. Acknowledged writes and event IDs prevent relay loops;
        // no extra platform characteristic or pairing flow is required.
        final pending = _safetyRelay?.outgoing(DateTime.now(), limit: 3) ?? const <SafetyAlert>[];
        for (final alert in pending) {
          await _central.writeCharacteristic(peripheral, ch,
            value: _security!.signMessage(alert.toBytes()), type: GATTCharacteristicWriteType.withResponse)
            .timeout(const Duration(seconds: 5));
        }
        // A GATT response confirms only this neighbour received the frame.
        // End-to-end delivery to everyone cannot be assumed.
        final actions = _actionRelay?.pending(DateTime.now(), limit: 4)
            ?? const <RopeActionFrame>[];
        for (final action in actions) {
          await _central.writeCharacteristic(
            peripheral, ch, value: _security!.signMessage(action.toBytes()),
            type: GATTCharacteristicWriteType.withResponse,
          ).timeout(const Duration(seconds: 5));
        }
        final bytes = await _central.readCharacteristic(peripheral, ch).timeout(const Duration(seconds: 8));
        final cleartext = await _security?.decryptRoster(bytes);
        if (cleartext == null) {
          _log('rejected unauthenticated roster snapshot');
          return;
        }
        final readAt = DateTime.now();
        final snap = RosterSnapshot.fromBytes(cleartext);
        if (snap.sessionHash != _sessionHash) return;
        _applyRoster(snap, readAt: readAt, fromOrganizer: fromOrganizer || (snap.organizer != null && sameMember(snap.organizer!.id, s.organizerId)));
      } finally {
        try {
          await _central.disconnect(peripheral).timeout(const Duration(seconds: 5));
        } catch (_) {}
      }
    } on TimeoutException {
      _log('sync timeout');
      final now = DateTime.now();
      if (_lastTimeoutLog == null || now.difference(_lastTimeoutLog!) > const Duration(seconds: 60)) {
        _lastTimeoutLog = now;
        _status('A nearby phone did not answer in time (retrying every few seconds)');
      }
    }
  }

  void _applyRoster(RosterSnapshot snap, {required DateTime readAt, required bool fromOrganizer}) {
    final s = _session;
    final self = _self;
    if (s == null || self == null) return;

    if (fromOrganizer && snap.info != null && s.organizerId != self.id) onSessionInfo?.call(snap.info!);
    // Positions travel hop by hop: keep whichever fix is newest.
    for (final e in snap.entries) {
      if (e.lat == null || e.lng == null || sameMember(e.id, self.id)) continue;
      final m = s.members.where((m) => sameMember(m.id, e.id)).firstOrNull;
      if (m == null) continue;
      final at = readAt.subtract(Duration(seconds: e.posAgeSec ?? 0));
      final known = _positions[m.id];
      if (known != null && !at.isAfter(known.at)) continue;
      final fix = (lat: e.lat!, lng: e.lng!, at: at);
      _positions[m.id] = fix;
      onPosition?.call(m.id, fix);
    }
    final merged = RosterMerge.apply(current: s.members, incoming: snap, selfId: self.id, fromOrganizer: fromOrganizer);
    final orgEntry = snap.organizer;
    final organizerId = orgEntry == null ? s.organizerId : (merged.members.where((m) => sameMember(m.id, orgEntry.id)).firstOrNull?.id ?? s.organizerId);
    if (merged.changed || organizerId != s.organizerId) {
      _log('roster from peer: ${merged.members.length} members');
      _session = s.copyWith(members: merged.members);
      _self = merged.members.where((m) => m.id == self.id).firstOrNull ?? self;
      if (_self!.memberIndex != unassignedMemberIndex && self.memberIndex == unassignedMemberIndex) {
        _status('Joined as #${_self!.memberIndex}');
      }
      onRosterChanged?.call(merged.members, organizerId);
    }

    // Multi-hop reachability: a member the neighbour heard [age] seconds ago
    // was alive at readAt - age. Ages only grow as they travel, so no loops.
    final byShort = {for (final m in (_session ?? s).members) shortId(m.id): m};
    for (final e in snap.entries) {
      final m = byShort[shortId(e.id)];
      if (m == null || sameMember(e.id, self.id) || e.ageSec >= 120) continue;
      final at = readAt.subtract(Duration(seconds: e.ageSec + 1));
      final prev = _lastHeard[m.id];
      if (prev == null || at.isAfter(prev)) _lastHeard[m.id] = at;
      _obs.add(PeerObservation(memberId: m.id, at: at, viaChain: true, hops: 2));
    }
  }

  /// Request what is missing ourselves. The plugin's own `authorize()` hangs
  /// forever when every permission is already granted (Android logs
  /// "No requestable permission in the request" and never calls back), so it
  /// is only used as a fallback, and never without a timeout.
  Future<void> _ensureAndroidPermissions() async {
    final wanted = [ph.Permission.bluetoothScan, ph.Permission.bluetoothAdvertise, ph.Permission.bluetoothConnect, ph.Permission.locationWhenInUse];
    final missing = <ph.Permission>[];
    for (final p in wanted) {
      final st = await p.status;
      if (!st.isGranted && !st.isLimited) missing.add(p);
    }
    if (missing.isEmpty) return;
    final results = await missing.request();
    final stillMissing = results.entries.where((e) => !e.value.isGranted && !e.value.isLimited).map((e) => e.key).toList();
    if (stillMissing.isEmpty) return;
    try {
      await _central.authorize().timeout(const Duration(seconds: 10));
      await _peripheral.authorize().timeout(const Duration(seconds: 10));
    } on TimeoutException {
      // Proceed; startDiscovery/startAdvertising will surface a real failure.
    }
  }

  Future<void> _waitPoweredOn(BluetoothLowEnergyManager m, {Duration timeout = const Duration(seconds: 8)}) async {
    if (m.state == BluetoothLowEnergyState.poweredOn) return;
    try {
      await m.stateChanged.firstWhere((e) => e.state == BluetoothLowEnergyState.poweredOn).timeout(timeout);
    } on TimeoutException {
      throw StateError('Bluetooth is ${m.state.name}. Turn it on to start the Digital Rope.');
    }
  }

  void dispose() {
    stop();
    _obs.close();
    _msg.close();
    _syncState.close();
    _safetyAlerts.close();
  }
}

class _Peer {
  const _Peer(this.peripheral, this.lastSeen, this.rssi);
  final Peripheral peripheral;
  final DateTime lastSeen;
  final int rssi;
}
