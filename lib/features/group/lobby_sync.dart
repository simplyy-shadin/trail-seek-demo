import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/group_session.dart';
import '../rope/links/ble_peer_link.dart';

@immutable
class LobbySyncState {
  const LobbySyncState({this.running = false, this.status = '', this.peersInRange = 0, this.error, this.startAt, this.waiting = false, this.requests = const [], this.asked = false});
  final bool running;
  final String status;
  final int peersInRange;
  final String? error;

  /// The group's "start together" moment, when one is counting down.
  final DateTime? startAt;

  /// This phone pressed Wait and will not auto-start with the group.
  final bool waiting;

  /// Organizer: names of members asking to start.
  final List<String> requests;

  /// Member: this phone has asked the organizer to start.
  final bool asked;
  LobbySyncState copyWith({bool? running, String? status, int? peersInRange, String? error, bool clearError = false, DateTime? startAt, bool clearStart = false, bool? waiting, List<String>? requests, bool? asked}) => LobbySyncState(
        running: running ?? this.running,
        status: status ?? this.status,
        peersInRange: peersInRange ?? this.peersInRange,
        error: clearError ? null : (error ?? this.error),
        startAt: clearStart ? null : (startAt ?? this.startAt),
        waiting: waiting ?? this.waiting,
        requests: requests ?? this.requests,
        asked: asked ?? this.asked,
      );
}

/// Runs the BLE roster exchange while people are in the lobby, so a group
/// formed at a trailhead with no signal still ends up with one shared member
/// list on every phone before anyone starts walking.
class LobbySyncController extends Notifier<LobbySyncState> {
  BlePeerLink? _link;
  String? _sessionId;
  Timer? _ticker;
  final List<StreamSubscription> _subs = [];

  @override
  LobbySyncState build() {
    ref.onDispose(_release);
    return const LobbySyncState();
  }

  Future<void>? _starting;
  String? _startingFor;

  Future<void> start(GroupSession session) {
    if (session.simulated || session.self == null) return Future.value();
    if (_sessionId == session.id && _link != null) {
      _link!.updateSession(session);
      return Future.value();
    }
    // The lobby asks twice in quick succession (initState + first build); one radio only.
    if (_startingFor == session.id && _starting != null) return _starting!;
    _startingFor = session.id;
    return _starting = _start(session).whenComplete(() {
      _starting = null;
      _startingFor = null;
    });
  }

  Future<void> _start(GroupSession session) async {
    await _release();
    _sessionId = session.id;
    final link = BlePeerLink(
      syncInterval: const Duration(seconds: 6),
      onLog: (l) => debugPrint('[BLE] $l'),
      onSessionInfo: (info) async {
        final go = info.startAt;
        if (go != null && go.millisecondsSinceEpoch == 0) {
          if (state.startAt != null || state.waiting) debugPrint('[LOBBY] organizer cancelled the start');
          state = state.copyWith(clearStart: true, waiting: false); // organizer pressed Wait
        } else if (go != null && go != state.startAt && !state.waiting && go.isAfter(DateTime.now().subtract(const Duration(seconds: 5)))) {
          debugPrint('[LOBBY] start together at $go');
          _link?.requestingStart = false;
          state = state.copyWith(startAt: go, asked: false);
        }
        final updated = await ref.read(groupProvider.notifier).applySessionInfo(session.id, info);
        if (updated != null) {
          debugPrint('[LOBBY] group details: ${updated.adventureName} · ${updated.name}');
          _link?.updateSession(updated);
        }
      },
      onStartRequest: (who) {
        if (state.startAt != null || state.requests.contains(who.displayName)) return;
        if (_dismissedAt != null && DateTime.now().difference(_dismissedAt!) < const Duration(seconds: 60)) return;
        debugPrint('[LOBBY] ${who.displayName} asks to start');
        state = state.copyWith(requests: [...state.requests, who.displayName]);
      },
      onRosterChanged: (members, organizerId) async {
        final s = ref.read(sessionByIdProvider(session.id));
        if (s == null) return;
        final updated = await ref.read(groupProvider.notifier).replaceMembers(s.id, members, organizerId: organizerId);
        debugPrint('[LOBBY] roster ${members.length} members: ${members.map((m) => '${m.displayName}#${m.memberIndex}').join(', ')}');
        _link?.updateSession(updated);
      },
    );
    _link = link;
    _subs.add(link.syncStatus.listen((s) {
      debugPrint('[LOBBY] $s');
      state = state.copyWith(status: s);
    }));
    _ticker = Timer.periodic(const Duration(seconds: 2), (_) => state = state.copyWith(peersInRange: link.peersInRange));
    state = const LobbySyncState(running: true, status: 'Starting Bluetooth…');
    debugPrint('[LOBBY] start session=${session.code} self=${session.self!.displayName}#${session.self!.memberIndex} organizer=${session.selfIsOrganizer}');
    try {
      await link.start(session: session, self: session.self!);
      state = state.copyWith(status: session.selfIsOrganizer ? 'Waiting for members nearby…' : 'Searching for your group nearby…');
    } catch (e) {
      debugPrint('[LOBBY] start failed: $e');
      // Drop the failed radio so "Try again" really starts over.
      await _release();
      if (ref.mounted) state = LobbySyncState(error: e.toString());
    }
  }

  /// Organizer: every phone in the group starts at the same moment, [lead] from now.
  Future<void> startTogether({Duration lead = const Duration(seconds: 10)}) async {
    final at = DateTime.now().add(lead);
    state = state.copyWith(startAt: at, waiting: false, requests: const []);
    await _link?.announceStart(at);
    debugPrint('[LOBBY] announced start at $at');
  }

  /// Member: ask the organizer to start the group (shown on the organizer's phone).
  Future<void> askToStart() async {
    _link?.requestingStart = true;
    state = state.copyWith(asked: true);
    await _link?.beatNow();
  }

  /// Organizer: "not yet" to the pending start requests.
  void dismissRequests() {
    _dismissedAt = DateTime.now();
    state = state.copyWith(requests: const []);
  }

  DateTime? _dismissedAt;

  /// Wait: the organizer cancels the countdown for everyone; a member only opts this phone out.
  Future<void> wait({required bool organizer}) async {
    state = state.copyWith(clearStart: true, waiting: !organizer);
    if (organizer) await _link?.announceStart(null);
  }

  Future<void> stop() async {
    await _release();
    if (ref.mounted) state = const LobbySyncState();
  }

  /// Tears the radio down without touching [state]; safe from onDispose.
  Future<void> _release() async {
    _ticker?.cancel();
    _ticker = null;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final l = _link;
    _link = null;
    _sessionId = null;
    if (l != null) {
      try {
        await l.stop();
      } catch (_) {}
      l.dispose();
    }
  }
}

final lobbySyncProvider = NotifierProvider<LobbySyncController, LobbySyncState>(LobbySyncController.new);
