import 'geo.dart';

/// Safety states from the product plan, ordered by severity.
enum RopeState {
  connected('Connected', 'Normal heartbeat, stable connection'),
  weak('Weak', 'Signal or heartbeat trend is degrading'),
  fallingBehind('Falling Behind', 'Sustained separation trend'),
  separated('Separated', 'No longer part of the Digital Rope chain'),
  critical('Critical', 'No reconnection within the escalation window');

  const RopeState(this.label, this.meaning);
  final String label;
  final String meaning;

  int get severity => index;
  bool get isAlerting => severity >= fallingBehind.severity;
}

/// One heartbeat heard from (or about) a member.
class PeerObservation {
  const PeerObservation({
    required this.memberId,
    required this.at,
    this.rssi,
    this.viaChain = false,
    this.hops = 0,
    this.position,
  });

  final String memberId;
  final DateTime at;

  /// Signal strength when heard directly. Null for chain observations.
  final int? rssi;

  /// True when a neighbour reported hearing this member, not us.
  final bool viaChain;
  final int hops;
  final GeoPoint? position;
}

class RopeMemberState {
  const RopeMemberState({
    required this.memberId,
    required this.state,
    required this.stateSince,
    this.lastDirectSeen,
    this.lastChainSeen,
    this.missedHeartbeats = 0,
    this.rssiTrendDb,
    this.lastRssi,
    this.lastKnownPosition,
    this.lastPositionAt,
  });

  final String memberId;
  final RopeState state;
  final DateTime stateSince;
  final DateTime? lastDirectSeen;
  final DateTime? lastChainSeen;
  final int missedHeartbeats;

  /// Positive means the signal is getting weaker.
  final double? rssiTrendDb;
  final int? lastRssi;
  final GeoPoint? lastKnownPosition;
  final DateTime? lastPositionAt;

  DateTime? get lastSeen {
    if (lastDirectSeen == null) return lastChainSeen;
    if (lastChainSeen == null) return lastDirectSeen;
    return lastDirectSeen!.isAfter(lastChainSeen!) ? lastDirectSeen : lastChainSeen;
  }

  bool get viaChainOnly =>
      lastChainSeen != null && (lastDirectSeen == null || lastChainSeen!.isAfter(lastDirectSeen!));
}

class RopeEvent {
  const RopeEvent({
    required this.at,
    required this.memberId,
    required this.from,
    required this.to,
  });
  final DateTime at;
  final String memberId;
  final RopeState from;
  final RopeState to;

  @override
  String toString() => '$at $memberId ${from.name} -> ${to.name}';
}

class RopeSnapshot {
  const RopeSnapshot({
    required this.at,
    required this.members,
    required this.selfIsolated,
  });

  final DateTime at;
  final Map<String, RopeMemberState> members;

  /// True when most of the group has gone quiet at once, which almost
  /// always means *we* are the one falling behind.
  final bool selfIsolated;

  int get total => members.length;
  int get connectedCount =>
      members.values.where((m) => m.state == RopeState.connected || m.state == RopeState.weak).length;

  RopeState get worst {
    var worst = RopeState.connected;
    for (final m in members.values) {
      if (m.state.severity > worst.severity) worst = m.state;
    }
    return worst;
  }

  List<RopeMemberState> get alerting =>
      members.values.where((m) => m.state.isAlerting).toList()
        ..sort((a, b) => b.state.severity.compareTo(a.state.severity));

  bool get allTogether => members.values.every((m) => !m.state.isAlerting);
}

/// Small messages that travel between phones alongside heartbeats.
enum RopeMessageType { imOk, waitForMe, needHelp, groupAlert, stopGroup, position }

class RopeMessage {
  const RopeMessage({
    required this.type,
    required this.fromMemberId,
    required this.at,
    this.position,
    this.text,
  });
  final RopeMessageType type;
  final String fromMemberId;
  final DateTime at;
  final GeoPoint? position;
  final String? text;
}
