import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/features/rope/links/rope_packet.dart';
import 'package:trailseek/features/rope/links/rope_roster.dart';

void main() {
  test('roster rows carry GPS fixes and the start-together moment', () {
    final go = DateTime.utc(2026, 10, 28, 16, 30, 10);
    final info = SessionInfo(
      adventureId: 'athirappilly-forest-trek',
      adventureName: 'Athirappilly Forest Trek',
      groupName: 'Test',
      date: DateTime(2026, 10, 28),
      expectedStart: DateTime(2026, 10, 28, 7),
      plannedSize: 2,
      startAt: go,
    );
    final snap = RosterSnapshot(sessionHash: 7, code: 'FFXZYD', info: info, entries: const [
      RosterEntry(index: 0, id: 'host-1', name: 'Host', ageSec: 0, isOrganizer: true, lat: 10.2851234, lng: 76.5702111, posAgeSec: 4),
      RosterEntry(index: 1, id: 'mem-2', name: 'Member', ageSec: 2),
    ]);
    final back = RosterSnapshot.fromBytes(snap.toBytes());
    expect(back.info!.startAt!.isAtSameMomentAs(go), isTrue);
    expect(back.entries[0].lat, closeTo(10.28512, 1e-5));
    expect(back.entries[0].lng, closeTo(76.57021, 1e-5));
    expect(back.entries[0].posAgeSec, 4);
    expect(back.entries[1].lat, isNull);
  });

  test('sixteen members with positions still fit one GATT attribute', () {
    final snap = RosterSnapshot(sessionHash: 7, code: 'FFXZYD', entries: [
      for (var i = 0; i < 16; i++) RosterEntry(index: i, id: 'member-id-$i-long', name: 'Explorer number $i', ageSec: 3, lat: 10.123456, lng: 76.654321, posAgeSec: 12),
    ]);
    final bytes = snap.toBytes();
    expect(bytes.length, lessThanOrEqualTo(RosterSnapshot.maxBytes));
    expect(RosterSnapshot.fromBytes(bytes).entries.length, 16);
  });

  test('the heartbeat carries the starting bit', () {
    const p = RopePacket(sessionHash: 9, memberIndex: 0, seq: 1, flags: 0, gossip: 0, starting: true);
    expect(RopePacket.decode(p.encode())!.starting, isTrue);
    const q = RopePacket(sessionHash: 9, memberIndex: 0, seq: 1, flags: 0, gossip: 0);
    expect(RopePacket.decode(q.encode())!.starting, isFalse);
  });
}
