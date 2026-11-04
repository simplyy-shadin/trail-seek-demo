import 'dart:convert';
import 'dart:io';

import '../../data/repositories/local_store.dart';
import 'engine/rope_models.dart';

/// Everything the beta needs to learn from one Digital Rope session
/// (product plan §14 "Beta metrics to capture"). Stored on the phone after
/// each session and exported from Settings as CSV.
class RopeSessionLog {
  const RopeSessionLog({
    required this.sessionId,
    required this.groupName,
    required this.adventureName,
    required this.startedAt,
    required this.endedAt,
    required this.memberCount,
    required this.simulated,
    required this.events,
    required this.messages,
    required this.platform,
  });

  factory RopeSessionLog.fromJson(Map<String, dynamic> j) => RopeSessionLog(
        sessionId: j['sessionId'] as String,
        groupName: j['groupName'] as String,
        adventureName: j['adventureName'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        endedAt: DateTime.parse(j['endedAt'] as String),
        memberCount: j['memberCount'] as int,
        simulated: j['simulated'] as bool? ?? false,
        events: (j['events'] as List).map((e) => RopeLogEvent.fromJson(e as Map<String, dynamic>)).toList(),
        messages: (j['messages'] as List).map((e) => RopeLogMessage.fromJson(e as Map<String, dynamic>)).toList(),
        platform: j['platform'] as String? ?? '',
      );

  factory RopeSessionLog.capture({
    required String sessionId,
    required String groupName,
    required String adventureName,
    required DateTime startedAt,
    required DateTime endedAt,
    required int memberCount,
    required bool simulated,
    required List<RopeEvent> events,
    required List<RopeMessage> messages,
    required Map<String, String> memberNames,
  }) =>
      RopeSessionLog(
        sessionId: sessionId,
        groupName: groupName,
        adventureName: adventureName,
        startedAt: startedAt,
        endedAt: endedAt,
        memberCount: memberCount,
        simulated: simulated,
        events: [for (final e in events) RopeLogEvent(e.at, memberNames[e.memberId] ?? e.memberId, e.from.name, e.to.name)],
        messages: [for (final m in messages) RopeLogMessage(m.at, memberNames[m.fromMemberId] ?? m.fromMemberId, m.type.name)],
        platform: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'.trim(),
      );

  final String sessionId;
  final String groupName;
  final String adventureName;
  final DateTime startedAt;
  final DateTime endedAt;
  final int memberCount;
  final bool simulated;
  final List<RopeLogEvent> events;
  final List<RopeLogMessage> messages;
  final String platform;

  Duration get duration => endedAt.difference(startedAt);

  /// Seconds from session start to the first "falling behind" for anyone; null if none.
  int? get secondsToFirstWarning {
    for (final e in events) {
      if (e.to == RopeState.fallingBehind.name) return e.at.difference(startedAt).inSeconds;
    }
    return null;
  }

  int get fallingBehindCount => events.where((e) => e.to == RopeState.fallingBehind.name).length;
  int get separatedCount => events.where((e) => e.to == RopeState.separated.name).length;
  int get criticalCount => events.where((e) => e.to == RopeState.critical.name).length;

  /// Alerts that cleared within [window] count as likely false alarms (the
  /// member was never really gone). Tuning target for RopeConfig.
  int shortLivedAlerts({Duration window = const Duration(seconds: 45)}) {
    var n = 0;
    final open = <String, DateTime>{};
    for (final e in events) {
      final alerting = e.to == RopeState.fallingBehind.name || e.to == RopeState.separated.name || e.to == RopeState.critical.name;
      if (alerting) {
        open.putIfAbsent(e.member, () => e.at);
      } else if (open.containsKey(e.member)) {
        if (e.at.difference(open[e.member]!) <= window) n++;
        open.remove(e.member);
      }
    }
    return n;
  }

  /// Median seconds from an alert starting to the member being connected again.
  int? get medianReconnectSeconds {
    final durations = <int>[];
    final open = <String, DateTime>{};
    for (final e in events) {
      final alerting = e.to != RopeState.connected.name && e.to != RopeState.weak.name;
      if (alerting) {
        open.putIfAbsent(e.member, () => e.at);
      } else if (open.containsKey(e.member)) {
        durations.add(e.at.difference(open[e.member]!).inSeconds);
        open.remove(e.member);
      }
    }
    if (durations.isEmpty) return null;
    durations.sort();
    return durations[durations.length ~/ 2];
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'groupName': groupName,
        'adventureName': adventureName,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'memberCount': memberCount,
        'simulated': simulated,
        'events': events.map((e) => e.toJson()).toList(),
        'messages': messages.map((m) => m.toJson()).toList(),
        'platform': platform,
      };

  static String _q(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';

  /// One row per session: the product plan's metric list.
  static String summaryCsv(Iterable<RopeSessionLog> logs) {
    final b = StringBuffer('session_id,group,trail,started_at,duration_min,members,mode,platform,sec_to_first_warning,falling_behind_events,separated_events,critical_events,short_lived_alerts_45s,median_reconnect_sec,messages\n');
    for (final l in logs) {
      b.writeln([
        _q(l.sessionId), _q(l.groupName), _q(l.adventureName), _q(l.startedAt.toIso8601String()), l.duration.inMinutes, l.memberCount,
        l.simulated ? 'demo' : 'bluetooth', _q(l.platform), l.secondsToFirstWarning ?? '', l.fallingBehindCount, l.separatedCount, l.criticalCount,
        l.shortLivedAlerts(), l.medianReconnectSeconds ?? '', l.messages.length,
      ].join(','));
    }
    return b.toString();
  }

  /// One row per state transition, for plotting.
  static String eventsCsv(Iterable<RopeSessionLog> logs) {
    final b = StringBuffer('session_id,at,sec_since_start,member,from,to\n');
    for (final l in logs) {
      for (final e in l.events) {
        b.writeln([_q(l.sessionId), _q(e.at.toIso8601String()), e.at.difference(l.startedAt).inSeconds, _q(e.member), e.from, e.to].join(','));
      }
    }
    return b.toString();
  }
}

class RopeLogEvent {
  const RopeLogEvent(this.at, this.member, this.from, this.to);
  factory RopeLogEvent.fromJson(Map<String, dynamic> j) => RopeLogEvent(DateTime.parse(j['t'] as String), j['m'] as String, j['f'] as String, j['o'] as String);
  final DateTime at;
  final String member;
  final String from;
  final String to;
  Map<String, dynamic> toJson() => {'t': at.toIso8601String(), 'm': member, 'f': from, 'o': to};
}

class RopeLogMessage {
  const RopeLogMessage(this.at, this.from, this.type);
  factory RopeLogMessage.fromJson(Map<String, dynamic> j) => RopeLogMessage(DateTime.parse(j['t'] as String), j['f'] as String, j['y'] as String);
  final DateTime at;
  final String from;
  final String type;
  Map<String, dynamic> toJson() => {'t': at.toIso8601String(), 'f': from, 'y': type};
}

/// Stores logs under `rope_log_<id>` with an index, newest first.
class RopeLogStore {
  RopeLogStore(this._store);
  final LocalStore _store;
  static const _index = 'rope_log_index';

  List<String> ids() => (_store.rawString(_index) ?? '').split(',').where((s) => s.isNotEmpty).toList();

  Future<void> save(RopeSessionLog log) async {
    await _store.setRaw('rope_log_${log.sessionId}', jsonEncode(log.toJson()));
    final ids = [log.sessionId, ...this.ids().where((i) => i != log.sessionId)].take(50).toList();
    await _store.setRaw(_index, ids.join(','));
  }

  List<RopeSessionLog> all() {
    final out = <RopeSessionLog>[];
    for (final id in ids()) {
      final raw = _store.rawString('rope_log_$id');
      if (raw == null) continue;
      try {
        out.add(RopeSessionLog.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }
}
