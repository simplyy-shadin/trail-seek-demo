import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/data/models/group_session.dart';
import 'package:trailseek/features/rope/links/rope_roster.dart';

Member m(String id, int idx, {bool self = false, bool org = false}) =>
    Member(id: id, displayName: id.toUpperCase(), role: org ? MemberRole.organizer : MemberRole.member, memberIndex: idx, isSelf: self);

void main() {
  final session = GroupSession(
    id: 's1',
    code: '8UH2E4',
    name: 'Test',
    adventureId: 'meesapulimala',
    adventureName: 'Meesapulimala',
    date: DateTime(2026, 10, 30),
    expectedStart: DateTime(2026, 10, 30, 6),
    plannedSize: 10,
    organizerId: 'host',
    members: [m('host', 0, self: true, org: true), m('u2', 1), m('u3', 2)],
    status: SessionStatus.active,
  );

  test('roster snapshot round-trips with ages and stays under a GATT long read', () {
    final now = DateTime(2026, 10, 30, 7);
    final snap = RosterSnapshot.fromSession(session, sessionHash: 0xBEEF, lastHeard: {'u2': now.subtract(const Duration(seconds: 4))}, now: now);
    final bytes = snap.toBytes();
    expect(bytes.length, lessThan(512));
    final back = RosterSnapshot.fromBytes(bytes);
    expect(back.code, '8UH2E4');
    expect(back.organizer?.id, 'host');
    expect(back.entries.firstWhere((e) => e.id == 'u2').ageSec, 4);
    expect(back.entries.firstWhere((e) => e.id == 'u3').ageSec, 255);
    expect(back.entries.firstWhere((e) => e.id == 'host').ageSec, 0);
    expect(back.entries.firstWhere((e) => e.id == 'host').name, 'HOST');
  });

  test('a 16-member roster fits in 512 bytes', () {
    final big = GroupSession(
      id: 's', code: 'ABCDEF', name: 'Big', adventureId: 'x', adventureName: 'X', date: DateTime(2026), expectedStart: DateTime(2026),
      plannedSize: 16, organizerId: 'm0', status: SessionStatus.active,
      members: [for (var i = 0; i < 16; i++) Member(id: 'member-$i-abcdefgh', displayName: 'Participant Number $i', role: MemberRole.member, memberIndex: i, avatarId: 'v1:1.2.3.4.5')],
    );
    final bytes = RosterSnapshot.fromSession(big, sessionHash: 1, lastHeard: const {}, now: DateTime(2026)).toBytes();
    expect(bytes.length, lessThanOrEqualTo(512), reason: '${bytes.length} bytes');
    final back = RosterSnapshot.fromBytes(bytes);
    expect(back.entries.length, 16);
    expect(back.entries.last.id, 'member-1'); // 8-char short id on the wire
    expect(sameMember('member-15-abcdefgh', back.entries.last.id), isTrue);
  });

  test('names containing the separator survive the trip', () {
    final snap = RosterSnapshot(sessionHash: 9, code: 'AB12CD', entries: const [RosterEntry(index: 1, id: 'x', name: 'A|B')]);
    expect(RosterSnapshot.fromBytes(snap.toBytes()).entries.single.name, 'A|B');
  });

  test('join request trims to the write limit and parses back', () {
    const j = JoinRequest(id: 'abcdefgh-1234', name: 'A very long participant name indeed', avatarId: 'v1:1.1.1.1.1');
    final small = j.toBytes(maxBytes: 60);
    expect(small.length, lessThanOrEqualTo(60));
    final parsed = JoinRequest.tryParse(small)!;
    expect(parsed.id, 'abcdefgh-1234');
    expect(parsed.name, isNotEmpty);
    expect(JoinRequest.tryParse(RosterSnapshot(sessionHash: 1, code: 'X', entries: const []).toBytes()), isNull);
  });

  test('merge: organizer roster assigns our index and adds unknown members', () {
    final mine = [m('me', unassignedMemberIndex, self: true)];
    final incoming = RosterSnapshot(sessionHash: 1, code: '8UH2E4', entries: const [
      RosterEntry(index: 0, id: 'host', name: 'HOST', isOrganizer: true, ageSec: 0),
      RosterEntry(index: 1, id: 'u2', name: 'U2', ageSec: 3),
      RosterEntry(index: 2, id: 'me', name: 'ME', ageSec: 1),
    ]);
    final r = RosterMerge.apply(current: mine, incoming: incoming, selfId: 'me', fromOrganizer: true);
    expect(r.changed, isTrue);
    expect(r.members.firstWhere((x) => x.isSelf).memberIndex, 2);
    expect(r.members.map((x) => x.id).toSet(), {'me', 'host', 'u2'});
    expect(r.members.firstWhere((x) => x.id == 'host').role, MemberRole.organizer);
  });

  test('merge: from a peer, colliding indices are ignored until the organizer confirms', () {
    final mine = [m('host', 0, self: true, org: true), m('u2', 1)];
    final incoming = RosterSnapshot(sessionHash: 1, code: 'X', entries: const [RosterEntry(index: 1, id: 'impostor', name: 'I'), RosterEntry(index: 5, id: 'u6', name: 'U6')]);
    final r = RosterMerge.apply(current: mine, incoming: incoming, selfId: 'host', fromOrganizer: false);
    expect(r.members.any((x) => x.id == 'impostor'), isFalse);
    expect(r.members.any((x) => x.id == 'u6'), isTrue);
  });

  test('merge is idempotent', () {
    final mine = [m('host', 0, self: true, org: true), m('u2', 1)];
    final incoming = RosterSnapshot(sessionHash: 1, code: 'X', entries: const [RosterEntry(index: 1, id: 'u2', name: 'U2'), RosterEntry(index: 0, id: 'host', name: 'H', isOrganizer: true)]);
    final r = RosterMerge.apply(current: mine, incoming: incoming, selfId: 'host', fromOrganizer: false);
    expect(r.changed, isFalse);
    expect(r.members.length, 2);
  });

  test('next free index skips used slots and caps at 15', () {
    expect(RosterMerge.nextFreeIndex([m('a', 0), m('b', 1), m('c', 3)]), 2);
    expect(RosterMerge.nextFreeIndex([for (var i = 0; i < 16; i++) m('m$i', i)]), isNull);
  });
}
