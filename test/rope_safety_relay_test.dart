import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/features/rope/links/rope_packet.dart';
import 'package:trailseek/features/rope/links/rope_safety_relay.dart';

void main() {
  final now = DateTime.utc(2026, 11, 4, 12);

  test('early heartbeat warning preserves manual action flags', () {
    const p = RopePacket(
      sessionHash: 0xCAFE, memberIndex: 7, seq: 42,
      flags: RopePacket.flagNeedHelp, gossip: 0xA55A,
      starting: true, requestStart: true,
      safetySubjectIndex: 9, safetySignal: SafetySignal.weak,
    );
    final bytes = p.encode();
    expect(bytes.length, 11);
    final q = RopePacket.decode(bytes)!;
    expect(q.flags, RopePacket.flagNeedHelp);
    expect(q.gossip, 0xA55A);
    expect(q.starting, isTrue);
    expect(q.requestStart, isTrue);
    expect(q.safetySubjectIndex, 9);
    expect(q.safetySignal, SafetySignal.weak);
    expect(q.seq, 42);
  });

  test('event remains exactly 12 bytes and retains reporter and hop', () {
    final alert = SafetyAlert(
      sessionHash: 0xCAFE, reporterIndex: 9, subjectIndex: 8,
      sequence: 123, signal: SafetySignal.fallingBehind,
      createdAt: now, hops: 3,
    );
    final encoded = alert.toBytes();
    expect(encoded.length, lessThanOrEqualTo(20));
    final decoded = SafetyAlert.fromBytes(encoded)!;
    expect(decoded.id, alert.id);
    expect(decoded.signal, SafetySignal.fallingBehind);
    expect(decoded.createdAt.isAtSameMomentAs(now), isTrue);
    expect(decoded.hops, 3);
  });

  test('ten phones deliver one warning across nine hops without duplicates', () {
    final nodes = List.generate(10, (_) => SafetyAlertRelay(sessionHash: 0xCAFE));
    final issued = nodes[9].create(
      reporterIndex: 9, subjectIndex: 9, signal: SafetySignal.weak, now: now,
    );
    expect(nodes[9].localBeacon(now)?.id, issued.id);
    for (var i = 9; i > 0; i--) {
      final relayAt = now.add(Duration(seconds: 2 * (9 - i)));
      final outgoing = nodes[i].outgoing(relayAt);
      expect(outgoing, hasLength(1));
      final frame = SafetyAlert.fromBytes(outgoing.single.toBytes())!;
      expect(nodes[i - 1].accept(frame, now: relayAt), isTrue);
      expect(nodes[i - 1].accept(frame, now: relayAt), isFalse);
    }
    expect(nodes[0].outgoing(now.add(const Duration(seconds: 20))).single.hops, 10);
    expect(nodes[0].localBeacon(now), isNull); // Forwarded, not locally reported.
  });

  test('multiple paths do not create a warning storm', () {
    final a = SafetyAlertRelay(sessionHash: 0xCAFE);
    final b = SafetyAlertRelay(sessionHash: 0xCAFE);
    final c = SafetyAlertRelay(sessionHash: 0xCAFE);
    a.create(reporterIndex: 2, subjectIndex: 3,
        signal: SafetySignal.separated, now: now);
    final frame = a.outgoing(now).single;
    expect(b.accept(frame, now: now), isTrue);
    expect(c.accept(frame, now: now), isTrue);
    expect(c.accept(b.outgoing(now).single, now: now), isFalse);
    expect(a.accept(c.outgoing(now).single, now: now), isFalse);
  });

  test('expired, future-dated and wrong-session events are discarded', () {
    final relay = SafetyAlertRelay(sessionHash: 0xCAFE);
    SafetyAlert event(int hash, DateTime time) => SafetyAlert(
      sessionHash: hash, reporterIndex: 2, subjectIndex: 3,
      sequence: 5, signal: SafetySignal.critical, createdAt: time,
    );
    expect(relay.accept(event(0xDEAD, now), now: now), isFalse);
    expect(relay.accept(event(0xCAFE, now.subtract(const Duration(minutes: 4))), now: now), isFalse);
    expect(relay.accept(event(0xCAFE, now.add(const Duration(minutes: 2))), now: now), isFalse);
    expect(SafetyAlert.fromBytes(Uint8List(2)), isNull);
  });

  test('recovery is a new event and stops local beacon after twenty seconds', () {
    final relay = SafetyAlertRelay(sessionHash: 0xCAFE);
    final weak = relay.create(reporterIndex: 1, subjectIndex: 2,
        signal: SafetySignal.weak, now: now);
    final recoveryAt = now.add(const Duration(seconds: 15));
    final ok = relay.create(reporterIndex: 1, subjectIndex: 2,
        signal: SafetySignal.recovered, now: recoveryAt);
    expect(ok.id, isNot(weak.id));
    expect(relay.localBeacon(recoveryAt)?.signal, SafetySignal.recovered);
    expect(relay.localBeacon(recoveryAt.add(const Duration(seconds: 21))), isNull);
  });
}
