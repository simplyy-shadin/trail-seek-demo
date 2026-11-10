import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/features/rope/engine/geo.dart';
import 'package:trailseek/features/rope/links/rope_roster.dart';
import 'package:trailseek/features/rope/links/rope_security.dart';
import 'package:trailseek/features/rope/links/rope_trail.dart';

/// One exchange as BlePeerLink does it: [reader] writes what it has, reads
/// [server]'s page, merges. Returns how many points arrived.
int pull(TrailBook reader, TrailBook server) {
  final have = TrailBook.parseRequest(reader.encodeRequest(maxBytes: 244 - 17))!;
  final page = server.encodeResponse(have, maxBytes: RopeSecurity.maxRosterPlaintextBytes);
  expect(page.length, lessThanOrEqualTo(RopeSecurity.maxRosterPlaintextBytes));
  var added = 0;
  for (final b in TrailBook.parseResponse(page)) {
    added += reader.merge(b.key, b.start, b.points).length;
  }
  return added;
}

/// Pull pages until nothing new, like up to [TrailBook] pages per sync.
void syncFully(TrailBook reader, TrailBook server) {
  while (pull(reader, server) > 0) {}
}

final t0 = DateTime.utc(2026, 11, 8, 6);

/// Member [i] walking north-east, a point every 6 m.
List<TrailPoint> walk(int i, int n) => [
      for (var k = 0; k < n; k++)
        TrailPoint(10.5 + i * 0.001 + k * 0.00004, 76.2 + i * 0.001 + k * 0.00003, t0.add(Duration(seconds: k * 5))),
    ];

void main() {
  test('own breadcrumbs: one every 5 m, or every 30 s while standing still', () {
    final book = TrailBook();
    const k = (index: 1, run: 100);
    final start = TrailPoint(10.5, 76.2, t0);
    expect(book.addOwn(k, start), isTrue);
    expect(book.addOwn(k, TrailPoint(10.50001, 76.2, t0.add(const Duration(seconds: 2)))), isFalse); // ~1 m
    expect(book.addOwn(k, TrailPoint(10.50006, 76.2, t0.add(const Duration(seconds: 4)))), isTrue); // ~6.7 m
    expect(book.addOwn(k, TrailPoint(10.50006, 76.2, t0.add(const Duration(seconds: 40)))), isTrue); // stood 36 s
    expect(book.count(k), 3);
  });

  test('points arrive to the centimetre with their time', () {
    final a = TrailBook();
    const k = (index: 3, run: 7);
    a.addOwn(k, TrailPoint(10.5273419, 76.2144521, t0));
    final b = TrailBook();
    pull(b, a);
    final p = b.line(k).single;
    expect(p.lat, closeTo(10.5273419, 1e-7));
    expect(p.lng, closeTo(76.2144521, 1e-7));
    expect(p.at, t0.toLocal());
  });

  test('a page asks only for what is missing and never leaves a gap', () {
    final a = TrailBook();
    const k = (index: 2, run: 1);
    for (final p in walk(2, 100)) {
      a.addOwn(k, p);
    }
    final b = TrailBook();
    final first = pull(b, a);
    expect(first, greaterThan(30)); // ~39 points fit one encrypted page
    expect(first, lessThan(100));
    syncFully(b, a);
    expect(b.count(k), 100);
    expect(pull(b, a), 0); // nothing more to send

    // A block that starts beyond what we hold is refused, not stitched in.
    final c = TrailBook();
    expect(c.merge(k, 10, walk(2, 5)), isEmpty);
    expect(c.count(k), 0);
  });

  test('10 members, chain of phones: everyone ends with every full path, exactly', () {
    // Phones in a line 0-1-2-...-9; each only reaches its neighbours.
    final books = List.generate(10, (_) => TrailBook());
    final paths = {for (var i = 0; i < 10; i++) i: walk(i, 120)};
    for (var i = 0; i < 10; i++) {
      for (final p in paths[i]!) {
        books[i].addOwn((index: i, run: 1000 + i), p);
      }
    }
    // A few sync rounds, 8 pages per neighbour per round, like the real link.
    for (var round = 0; round < 40; round++) {
      for (var i = 0; i < 10; i++) {
        for (final j in [i - 1, i + 1]) {
          if (j < 0 || j > 9) continue;
          for (var page = 0; page < 8; page++) {
            if (pull(books[i], books[j]) == 0) break;
          }
        }
      }
    }
    for (var phone = 0; phone < 10; phone++) {
      for (var m = 0; m < 10; m++) {
        final got = books[phone].pathOf(m);
        expect(got.length, 120, reason: 'phone $phone, member $m');
        for (var k = 0; k < 120; k++) {
          expect(haversineMetres(got[k].geo, paths[m]![k].geo), lessThan(0.05));
        }
      }
    }
  });

  test('one long line cannot starve the others in a page', () {
    final a = TrailBook();
    for (final p in walk(0, 500)) {
      a.addOwn((index: 0, run: 1), p);
    }
    for (var i = 1; i < 6; i++) {
      for (final p in walk(i, 5)) {
        a.addOwn((index: i, run: 1), p);
      }
    }
    final blocks = TrailBook.parseResponse(a.encodeResponse(const {}));
    expect(blocks.map((b) => b.key.index).toSet(), {0, 1, 2, 3, 4, 5});
  });

  test('app reopened mid-trek: the earlier run comes back and paths join in order', () {
    final owner = TrailBook();
    final friend = TrailBook();
    for (final p in walk(4, 20)) {
      owner.addOwn((index: 4, run: 100), p);
    }
    syncFully(friend, owner);
    final reopened = TrailBook(); // memory lost; new run
    final later = walk(4, 40).skip(20).toList();
    for (final p in later) {
      reopened.addOwn((index: 4, run: 200), p);
    }
    syncFully(reopened, friend);
    syncFully(friend, reopened);
    expect(reopened.pathOf(4).length, 40);
    expect(friend.pathOf(4).length, 40);
    expect(friend.pathOf(4).first.at.isBefore(friend.pathOf(4).last.at), isTrue);
  });

  test('malformed pages are ignored', () {
    expect(TrailBook.parseRequest(Uint8List.fromList([1, 2, 3])), isNull);
    expect(TrailBook.parseResponse(Uint8List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 9])), isEmpty);
    expect(TrailBook.parseResponse(Uint8List(0)), isEmpty);
  });

  test('trail pages are encrypted with the group key', () async {
    const key = 'd4c3b2a1765890e1f2a3b4c5d6e7f80900112233445566778899aabbccddeeff';
    const other = '11223344556677889900aabbccddeeffd4c3b2a1765890e1f2a3b4c5d6e7f809';
    final a = TrailBook();
    for (final p in walk(1, 50)) {
      a.addOwn((index: 1, run: 1), p);
    }
    final plain = a.encodeResponse(const {}, maxBytes: RopeSecurity.maxRosterPlaintextBytes);
    final sealed = await RopeSecurity(key).encryptTrail(plain);
    expect(sealed.length, lessThanOrEqualTo(512));
    expect(await RopeSecurity(key).decryptTrail(sealed), orderedEquals(plain));
    expect(await RopeSecurity(other).decryptTrail(sealed), isNull);
    expect(await RopeSecurity(key).decryptRoster(sealed), isNull); // not interchangeable with rosters
  });

  test('group list keeps everyone\'s position for 10 and 16 members', () {
    for (final n in [10, 16]) {
      final snap = RosterSnapshot(
        sessionHash: 12345,
        code: 'ABC123',
        entries: [
          for (var i = 0; i < n; i++)
            RosterEntry(index: i, id: 'a1b2c3d4-0000-$i', name: 'Trekker Name $i', avatarId: 'char:hiker_$i', ageSec: 3, isOrganizer: i == 0, lat: 10.12345, lng: 76.12345, posAgeSec: 12),
        ],
        info: SessionInfo(adventureId: 'adv-athirappilly', adventureName: 'Athirappilly Falls Trek', groupName: 'Weekend Trekkers', date: t0, expectedStart: t0, plannedSize: n),
      );
      final bytes = snap.toBytes();
      expect(bytes.length, lessThanOrEqualTo(RosterSnapshot.maxBytes));
      final back = RosterSnapshot.fromBytes(bytes);
      if (n == 10) expect(back.entries.where((e) => e.lat != null).length, 10);
      expect(back.info, isNotNull);
    }
  });
}
