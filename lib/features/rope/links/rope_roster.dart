import 'dart:convert';
import 'dart:typed_data';

import '../../../data/models/group_session.dart';

/// Member index that means "joined by code, not yet assigned by the organizer".
const int unassignedMemberIndex = 255;

/// One row of the roster a phone serves over GATT: who it knows about and
/// how many seconds ago it last heard them (directly or through someone).
class RosterEntry {
  const RosterEntry({required this.index, required this.id, required this.name, this.avatarId, this.ageSec = 255, this.isOrganizer = false, this.lat, this.lng, this.posAgeSec});

  final int index;
  final String id;
  final String name;
  final String? avatarId;

  /// 0..254 seconds; 255 = never heard.
  final int ageSec;
  final bool isOrganizer;

  /// Last GPS fix this phone knows for the member, and how old it is (s).
  final double? lat;
  final double? lng;
  final int? posAgeSec;

  Member toMember({bool isSelf = false}) => Member(
        id: id,
        displayName: name,
        role: isOrganizer ? MemberRole.organizer : MemberRole.member,
        memberIndex: index,
        isSelf: isSelf,
        avatarId: avatarId,
      );
}

/// A member's last GPS fix as passed around the group.
typedef MemberFix = ({double lat, double lng, DateTime at});

/// Short id used on the air (first 8 chars of the member id). Member ids are
/// UUIDs; 16 of them would not fit the 512-byte GATT attribute limit.
String shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);

bool sameMember(String a, String b) => shortId(a) == shortId(b);

/// What a phone serves on the roster characteristic.
///
/// Compact line format (≤ 512 bytes for 16 members):
/// ```
/// 1|<hash>|<code>|<adventureId>|<adventureName>|<groupName>|<dateMin>|<startMin>|<plannedSize>
/// <idx>|<shortId>|<name>|<ageSec>|<o?>|<avatar?>|<lat?>|<lng?>|<posAgeSec?>
/// ```
/// The head may end with `|<startAtSec>`: the organizer's "start together"
/// moment (Unix seconds), empty when no start is pending.
/// The head fields after the code are optional (older builds send none).
class SessionInfo {
  const SessionInfo({required this.adventureId, required this.adventureName, required this.groupName, required this.date, required this.expectedStart, required this.plannedSize, this.startAt});
  final String adventureId;
  final String adventureName;
  final String groupName;
  final DateTime date;
  final DateTime expectedStart;
  final int plannedSize;

  /// When every phone should start the rope together; null = no start pending.
  final DateTime? startAt;

  static String _esc(String v) => v.replaceAll('|', '\u2502').replaceAll('\n', ' ');
  static String _cut(String v, int n) => v.length > n ? v.substring(0, n) : v;

  String encode() {
    final d = date.toUtc().millisecondsSinceEpoch ~/ 60000;
    final e = expectedStart.toUtc().millisecondsSinceEpoch ~/ 60000;
    final go = startAt == null ? '' : '${startAt!.toUtc().millisecondsSinceEpoch ~/ 1000}';
    return '${_esc(_cut(adventureId, 40))}|${_esc(_cut(adventureName, 32))}|${_esc(_cut(groupName, 32))}|$d|$e|$plannedSize|$go';
  }

  static SessionInfo? tryParse(List<String> head) {
    if (head.length < 9) return null;
    final d = int.tryParse(head[6]);
    final e = int.tryParse(head[7]);
    if (d == null || e == null) return null;
    return SessionInfo(
      adventureId: head[3].replaceAll('\u2502', '|'),
      adventureName: head[4].replaceAll('\u2502', '|'),
      groupName: head[5].replaceAll('\u2502', '|'),
      date: DateTime.fromMillisecondsSinceEpoch(d * 60000, isUtc: true).toLocal(),
      expectedStart: DateTime.fromMillisecondsSinceEpoch(e * 60000, isUtc: true).toLocal(),
      plannedSize: int.tryParse(head[8]) ?? 2,
      startAt: head.length > 9 && int.tryParse(head[9]) != null ? DateTime.fromMillisecondsSinceEpoch(int.parse(head[9]) * 1000, isUtc: true).toLocal() : null,
    );
  }
}

class RosterSnapshot {
  const RosterSnapshot({required this.sessionHash, required this.code, required this.entries, this.info});

  // Reserve 29 bytes for AES-GCM magic, 96-bit nonce and 128-bit tag.
  // BLE GATT long-read size limit is 512 bytes including encryption overhead.
  static const maxBytes = 483;

  factory RosterSnapshot.fromBytes(Uint8List bytes) {
    final lines = utf8.decode(bytes).split('\n').where((l) => l.isNotEmpty).toList();
    final head = lines.first.split('|');
    final entries = <RosterEntry>[];
    for (final l in lines.skip(1)) {
      final f = l.split('|');
      if (f.length < 4) continue;
      entries.add(RosterEntry(
        index: int.tryParse(f[0]) ?? unassignedMemberIndex,
        id: f[1],
        name: f[2].replaceAll('\u2502', '|'),
        ageSec: int.tryParse(f[3]) ?? 255,
        isOrganizer: f.length > 4 && f[4] == 'o',
        avatarId: f.length > 5 && f[5].isNotEmpty ? f[5] : null,
        lat: f.length > 8 ? double.tryParse(f[6]) : null,
        lng: f.length > 8 ? double.tryParse(f[7]) : null,
        posAgeSec: f.length > 8 ? int.tryParse(f[8]) : null,
      ));
    }
    return RosterSnapshot(
      sessionHash: int.tryParse(head.length > 1 ? head[1] : '') ?? 0,
      code: head.length > 2 ? head[2] : '',
      entries: entries,
      info: SessionInfo.tryParse(head),
    );
  }

  final int sessionHash;
  final String code;
  final List<RosterEntry> entries;

  /// Group details as the organizer knows them; null from older builds.
  final SessionInfo? info;

  RosterEntry? get organizer => entries.where((e) => e.isOrganizer).firstOrNull;

  Uint8List toBytes() {
    // Try rich → compact until it fits the attribute limit. Positions are
    // dropped last: on a trek every member's name is already known, so names
    // shrink first (a 10-person group used to lose everyone's pin here).
    for (final (nameLen, withAvatar, withInfo, withPos) in [
      (16, true, true, true), (12, false, true, true), (6, false, true, true), (2, false, true, true), (0, false, true, true),
      (4, false, true, false), (4, false, false, false),
    ]) {
      final b = StringBuffer('1|$sessionHash|$code');
      if (withInfo && info != null) b.write('|${info!.encode()}');
      for (final e in entries) {
        final name = e.name.replaceAll('|', '\u2502');
        final n = name.length > nameLen ? name.substring(0, nameLen) : name;
        final av = withAvatar && e.avatarId != null && (e.avatarId!.startsWith('v1:') || e.avatarId!.startsWith('char:')) ? e.avatarId! : '';
        b.write('\n${e.index}|${shortId(e.id)}|$n|${e.ageSec.clamp(0, 255)}|${e.isOrganizer ? 'o' : ''}|$av');
        if (withPos && e.lat != null && e.lng != null) b.write('|${e.lat!.toStringAsFixed(5)}|${e.lng!.toStringAsFixed(5)}|${(e.posAgeSec ?? 0).clamp(0, 9999)}');
      }
      final bytes = Uint8List.fromList(utf8.encode(b.toString()));
      if (bytes.length <= maxBytes) return bytes;
    }
    // Still too big (cannot happen with ≤16 members); send the first 16 rows only.
    return RosterSnapshot(sessionHash: sessionHash, code: code, entries: entries.take(16).toList(), info: info).toBytes();
  }

  /// Build from a session plus last-heard times.
  static RosterSnapshot fromSession(GroupSession s,
      {required int sessionHash, required Map<String, DateTime> lastHeard, required DateTime now, Map<String, MemberFix> positions = const {}, DateTime? startAt}) {
    final selfIsOrganizer = s.self != null && s.self!.id == s.organizerId;
    return RosterSnapshot(
      sessionHash: sessionHash,
      code: s.code,
      // Only the organizer's phone is the source of truth for what the group is.
      info: selfIsOrganizer
          ? SessionInfo(adventureId: s.adventureId, adventureName: s.adventureName, groupName: s.name, date: s.date, expectedStart: s.expectedStart, plannedSize: s.plannedSize, startAt: startAt)
          : null,
      entries: [
        for (final m in s.members)
          RosterEntry(
            index: m.memberIndex,
            id: m.id,
            name: m.displayName,
            avatarId: m.avatarId,
            ageSec: m.isSelf ? 0 : (lastHeard[m.id] == null ? 255 : now.difference(lastHeard[m.id]!).inSeconds.clamp(0, 255)),
            isOrganizer: m.id == s.organizerId,
            lat: positions[m.id]?.lat,
            lng: positions[m.id]?.lng,
            posAgeSec: positions[m.id] == null ? null : now.difference(positions[m.id]!.at).inSeconds,
          ),
      ],
    );
  }
}

/// Written by a phone that joined with a code and needs an index.
class JoinRequest {
  const JoinRequest({required this.id, required this.name, this.avatarId});

  static JoinRequest? tryParse(Uint8List bytes) {
    try {
      final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (j['t'] != 'join') return null;
      return JoinRequest(id: j['d'] as String, name: j['n'] as String, avatarId: j['a'] as String?);
    } catch (_) {
      return null;
    }
  }

  final String id;
  final String name;
  final String? avatarId;

  /// Encodes within [maxBytes] by trimming the name and dropping the avatar.
  Uint8List toBytes({int maxBytes = 180}) {
    var name = this.name;
    var avatar = avatarId != null && avatarId!.startsWith('v1:') ? avatarId : null;
    while (true) {
      final b = utf8.encode(jsonEncode({'t': 'join', 'd': id, 'n': name, 'a': ?avatar}));
      if (b.length <= maxBytes || name.isEmpty) return Uint8List.fromList(b);
      if (avatar != null) {
        avatar = null;
      } else {
        name = name.substring(0, name.length - 1);
      }
    }
  }
}

/// Merge rules shared by every phone (pure, unit-tested):
/// * the organizer's roster is authoritative for indices;
/// * from anyone else, accept only members whose index is free;
/// * our own entry adopts the index the organizer assigned.
class RosterMerge {
  const RosterMerge._();

  static ({List<Member> members, bool changed}) apply({
    required List<Member> current,
    required RosterSnapshot incoming,
    required String selfId,
    required bool fromOrganizer,
  }) {
    final byId = {for (final m in current) shortId(m.id): m};
    final usedIndex = {for (final m in current) if (m.memberIndex != unassignedMemberIndex) m.memberIndex: shortId(m.id)};
    var changed = false;
    final next = List<Member>.of(current);

    for (final e in incoming.entries) {
      if (e.index == unassignedMemberIndex) continue;
      final existing = byId[shortId(e.id)];
      if (existing != null) {
        if (existing.memberIndex != e.index && (fromOrganizer || existing.memberIndex == unassignedMemberIndex)) {
          final i = next.indexWhere((m) => sameMember(m.id, e.id));
          next[i] = Member(id: existing.id, displayName: existing.displayName, role: e.isOrganizer ? MemberRole.organizer : existing.role, memberIndex: e.index, isSelf: existing.isSelf, avatarId: existing.avatarId ?? e.avatarId);
          usedIndex[e.index] = shortId(e.id);
          changed = true;
        }
        continue;
      }
      final owner = usedIndex[e.index];
      if (owner != null && owner != shortId(e.id) && !fromOrganizer) continue; // collision, wait for the organizer's word
      if (owner != null && owner != shortId(e.id) && fromOrganizer) {
        // Organizer says this index belongs to someone else: demote the squatter to unassigned.
        final i = next.indexWhere((m) => shortId(m.id) == owner);
        if (i >= 0 && !next[i].isSelf) {
          next[i] = Member(id: next[i].id, displayName: next[i].displayName, role: next[i].role, memberIndex: unassignedMemberIndex, isSelf: false, avatarId: next[i].avatarId);
        }
      }
      next.add(e.toMember(isSelf: sameMember(e.id, selfId)));
      usedIndex[e.index] = shortId(e.id);
      changed = true;
    }
    return (members: next, changed: changed);
  }

  /// Assigns the next free index (organizer side). Returns null when full.
  static int? nextFreeIndex(List<Member> members) {
    final used = members.map((m) => m.memberIndex).toSet();
    for (var i = 1; i < 16; i++) {
      if (!used.contains(i)) return i;
    }
    return null;
  }
}
