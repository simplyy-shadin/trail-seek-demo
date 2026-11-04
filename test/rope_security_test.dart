import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/data/models/group_session.dart';
import 'package:trailseek/features/rope/links/rope_security.dart';
import 'package:trailseek/features/rope/links/rope_control_frame.dart';

void main() {
  const a = 'd4c3b2a1765890e1f2a3b4c5d6e7f80900112233445566778899aabbccddeeff';
  const b = '11223344556677889900aabbccddeeffd4c3b2a1765890e1f2a3b4c5d6e7f809';
  final now = DateTime.utc(2026, 11, 4, 12);

  test('generate a random full-length group secret and reject malformed keys', () {
    final one = RopeSecurity.generateKey();
    final two = RopeSecurity.generateKey();
    expect(one, hasLength(64));
    expect(RopeSecurity.validKey(one), isTrue);
    expect(one, isNot(two));
    expect(RopeSecurity.validKey('ABC123'), isFalse);
    expect(() => RopeSecurity('short'), throwsArgumentError);
  });

  test('authenticated message arrives unchanged; tampering and wrong keys fail', () {
    final sender = RopeSecurity(a);
    final recipient = RopeSecurity(a);
    final outsider = RopeSecurity(b);
    final payload = Uint8List.fromList([0xA8, 2, 9, 7, 0, 1, 2, 3, 4, 5, 6, 7]);
    final wire = sender.signMessage(payload);
    expect(recipient.verifyMessage(wire), orderedEquals(payload));
    expect(outsider.verifyMessage(wire), isNull);
    final altered = Uint8List.fromList(wire)..[4] ^= 0x01;
    expect(recipient.verifyMessage(altered), isNull);
    expect(recipient.verifyMessage(payload), isNull);
    expect(wire.length, 29);
  });

  test('AES-GCM roster is confidential and authenticated', () async {
    final one = RopeSecurity(a);
    final two = RopeSecurity(a);
    final attacker = RopeSecurity(b);
    final roster = Uint8List.fromList('1|5678|SECRET\n0|id|Group Member|0|o|'.codeUnits);
    final encrypted = await one.encryptRoster(roster);
    expect(encrypted.first, RopeSecurity.rosterMagic);
    expect(encrypted.length, roster.length + RopeSecurity.encryptedRosterOverhead);
    expect(encrypted, isNot(containsAll(roster)));
    expect(await two.decryptRoster(encrypted), orderedEquals(roster));
    expect(await attacker.decryptRoster(encrypted), isNull);
    final changed = Uint8List.fromList(encrypted)..[22] ^= 0x80;
    expect(await two.decryptRoster(changed), isNull);
    expect(await two.decryptRoster(roster), isNull);
  });

  test('independent roster encryption uses a unique nonce', () async {
    final s = RopeSecurity(a);
    final plain = Uint8List.fromList([1, 2, 3, 4]);
    final first = await s.encryptRoster(plain);
    final second = await s.encryptRoster(plain);
    expect(first, isNot(orderedEquals(second)));
    expect(await s.decryptRoster(second), orderedEquals(plain));
  });

  test('control commands are versioned and expire; bad frames are rejected', () {
    final c = RopeControlFrame(
        type: RopeControlType.endGroup, originIndex: 0,
        sequence: 8, createdAt: now);
    expect(RopeControlFrame.fromBytes(c.toBytes(), now: now)?.type,
        RopeControlType.endGroup);
    expect(RopeControlFrame.fromBytes(c.toBytes(),
        now: now.add(const Duration(minutes: 5))), isNull);
    expect(RopeControlFrame.fromBytes(c.toBytes(),
        now: now.subtract(const Duration(minutes: 5))), isNull);
    final bad = Uint8List.fromList(c.toBytes())..[0] = 0;
    expect(RopeControlFrame.fromBytes(bad, now: now), isNull);
  });

  test('group session JSON does not leak the group secret', () {
    final s = GroupSession(
      id: 'g1', code: 'A1B2C3', name: 'Trek',
      adventureId: 'a', adventureName: 'Forest',
      date: now, expectedStart: now,
      plannedSize: 3, organizerId: 'me', members: const [],
      status: SessionStatus.lobby, simulated: false,
      securityKey: a,
    );
    final json = s.toJson();
    expect(json.containsKey('securityKey'), isFalse);
    expect(json.toString().contains(a), isFalse);
  });
}
