import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/features/rope/engine/rope_models.dart';
import 'package:trailseek/features/rope/links/rope_action_relay.dart';
import 'package:trailseek/features/rope/links/rope_packet.dart';
import 'package:trailseek/features/rope/links/rope_safety_relay.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 4, 12);

  test('manual SOS reaches the first phone through nine simulated hops', () {
    final phones = List.generate(
      10, (_) => RopeActionRelay(sessionHash: 0xBEEF),
    );
    final origin = phones[9].create(
      originIndex: 9, type: RopeMessageType.needHelp, now: t0,
    );
    for (var i = 9; i > 0; i--) {
      final now = t0.add(Duration(seconds: 2 * (9 - i)));
      final outgoing = phones[i].pending(now).single;
      final received = RopeActionFrame.fromBytes(outgoing.toBytes())!;
      expect(phones[i - 1].accept(received, now: now), isTrue);
      expect(phones[i - 1].accept(received, now: now), isFalse);
      expect(received.id, origin.id);
    }
    expect(
      phones[0].pending(t0.add(const Duration(seconds: 20))).single.hops, 10,
    );
  });

  test('SOS and STOP take priority over ordinary messages', () {
    final relay = RopeActionRelay(sessionHash: 0xBEEF);
    relay.create(originIndex: 0, type: RopeMessageType.imOk, now: t0);
    relay.create(originIndex: 0, type: RopeMessageType.needHelp, now: t0);
    relay.create(originIndex: 0, type: RopeMessageType.stopGroup, now: t0);
    relay.create(originIndex: 0, type: RopeMessageType.waitForMe, now: t0);
    expect(relay.pending(t0).map((e) => e.type).toList(), [
      RopeMessageType.needHelp, RopeMessageType.stopGroup,
      RopeMessageType.waitForMe, RopeMessageType.imOk,
    ]);
  });

  test('malformed, wrong-group, expired and future frames are ignored', () {
    final relay = RopeActionRelay(sessionHash: 0xBEEF);
    RopeActionFrame event(int hash, DateTime date) => RopeActionFrame(
      sessionHash: hash, originIndex: 3, sequence: 3,
      type: RopeMessageType.waitForMe, sentAt: date,
    );
    expect(
      relay.accept(event(0xBEEF, t0.subtract(const Duration(minutes: 6))), now: t0),
      isFalse,
    );
    expect(
      relay.accept(event(0xBEEF, t0.add(const Duration(minutes: 2))), now: t0),
      isFalse,
    );
    expect(relay.accept(event(42, t0), now: t0), isFalse);
    expect(RopeActionFrame.fromBytes(Uint8List(2)), isNull);
    expect(RopeActionFrame.fromBytes(Uint8List(12)), isNull);
    final invalid = event(0xBEEF, t0).toBytes();
    invalid[5] = 0xFF;
    expect(RopeActionFrame.fromBytes(invalid), isNull);
  });

  test('v2 advertisement marks stable sequence; legacy remains readable', () {
    const updated = RopePacket(
      sessionHash: 123, memberIndex: 3, seq: 7,
      flags: RopePacket.flagWaitForMe, gossip: 0, actionV2: true,
    );
    const legacy = RopePacket(
      sessionHash: 123, memberIndex: 3, seq: 8,
      flags: RopePacket.flagWaitForMe, gossip: 0,
    );
    final updatedBytes = updated.encode();
    expect(updatedBytes.length, 11);
    expect(RopePacket.decode(updatedBytes)!.actionV2, isTrue);
    expect(RopePacket.decode(legacy.encode())!.actionV2, isFalse);
  });

  test('automatic safety signal and manual action bits coexist in packet', () {
    const p = RopePacket(
      sessionHash: 0xBEEF, memberIndex: 4, seq: 99,
      flags: RopePacket.flagNeedHelp, gossip: 0xAF,
      actionV2: true, safetySubjectIndex: 9,
      safetySignal: SafetySignal.weak,
      starting: true, requestStart: true, ending: true,
    );
    final result = RopePacket.decode(p.encode())!;
    expect(result.actionV2, isTrue);
    expect(result.safetySubjectIndex, 9);
    expect(result.safetySignal, SafetySignal.weak);
    expect(result.flags, RopePacket.flagNeedHelp);
    expect(result.gossip, 0xAF);
    expect(result.starting, isTrue);
    expect(result.requestStart, isTrue);
    expect(result.ending, isTrue);
  });

  test('all five predefined messages fit 12-byte GATT write', () {
    for (final type in RopeMessageType.values.where(RopeActionFrame.isAction)) {
      final event = RopeActionFrame(
        sessionHash: 0xBEEF, originIndex: 5,
        sequence: 42, type: type, sentAt: t0,
      );
      expect(event.toBytes().length, 12);
      expect(RopeActionFrame.fromBytes(event.toBytes())!.type, type);
    }
  });

  test('duplicate return path does not rebroadcast; hop limit applies', () {
    final a = RopeActionRelay(sessionHash: 0xBEEF);
    final b = RopeActionRelay(sessionHash: 0xBEEF);
    a.create(originIndex: 1, type: RopeMessageType.stopGroup, now: t0);
    expect(b.accept(a.pending(t0).single, now: t0), isTrue);
    expect(a.accept(b.pending(t0).single, now: t0), isFalse);
    final max = RopeActionFrame(
      sessionHash: 0xBEEF, originIndex: 1, sequence: 100,
      type: RopeMessageType.stopGroup, sentAt: t0,
      hops: RopeActionFrame.maxHops,
    );
    expect(b.accept(max, now: t0), isTrue);
    expect(b.pending(t0).map((e) => e.sequence), isNot(contains(100)));
  });

  test('sequence wrapping within expiry window is rejected, not replayed', () {
    final relay = RopeActionRelay(sessionHash: 0xBEEF);
    for (var i = 0; i < 256; i++) {
      relay.create(originIndex: 0, type: RopeMessageType.imOk, now: t0);
    }
    expect(
      () => relay.create(
        originIndex: 0, type: RopeMessageType.needHelp, now: t0,
      ),
      throwsStateError,
    );
  });
}
