import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/features/rope/engine/rope_config.dart';
import 'package:trailseek/features/rope/engine/rope_engine.dart';
import 'package:trailseek/features/rope/engine/rope_models.dart';
import 'package:trailseek/features/rope/links/rope_packet.dart';

void main() {
  final t0 = DateTime(2026, 10, 25, 6);
  const config = RopeConfig();

  RopeEngine engine({List<String> members = const ['rahul', 'anu', 'joseph']}) =>
      RopeEngine(selfId: 'leader', memberIds: ['leader', ...members], startedAt: t0, config: config);

  /// Feed direct heartbeats for everyone except [silent] from [from] to [to].
  void walk(RopeEngine e, DateTime from, DateTime to, {Set<String> silent = const {}, Set<String> chainOnly = const {}, int rssi = -60}) {
    var t = from;
    while (!t.isAfter(to)) {
      for (final id in e.memberIds) {
        if (silent.contains(id)) continue;
        if (chainOnly.contains(id)) {
          e.observe(PeerObservation(memberId: id, at: t, viaChain: true, hops: 1));
        } else {
          e.observe(PeerObservation(memberId: id, at: t, rssi: rssi));
        }
      }
      e.tick(t);
      t = t.add(config.heartbeatInterval);
    }
  }

  group('RopeEngine', () {
    test('everyone connected while heartbeats flow', () {
      final e = engine();
      walk(e, t0, t0.add(const Duration(seconds: 30)));
      expect(e.latest!.worst, RopeState.connected);
      expect(e.events, isEmpty);
    });

    test('shoelace: grace, then falling behind, then separated, then recovery', () {
      final e = engine();
      walk(e, t0, t0.add(const Duration(seconds: 30)));
      final stop = t0.add(const Duration(seconds: 30));

      // 10 s of silence is inside the grace period: at worst "weak".
      walk(e, stop, stop.add(const Duration(seconds: 10)), silent: {'rahul'});
      expect(e.latest!.members['rahul']!.state.isAlerting, isFalse);

      // 25 s of silence: falling behind.
      walk(e, stop, stop.add(const Duration(seconds: 25)), silent: {'rahul'});
      expect(e.latest!.members['rahul']!.state, RopeState.fallingBehind);
      final firstWarning = e.events.firstWhere((ev) => ev.to == RopeState.fallingBehind);
      expect(firstWarning.at.difference(stop), lessThanOrEqualTo(const Duration(seconds: 22)));

      // 65 s of silence: separated.
      walk(e, stop, stop.add(const Duration(seconds: 65)), silent: {'rahul'});
      expect(e.latest!.members['rahul']!.state, RopeState.separated);
      expect(e.latest!.connectedCount, 2);

      // Rahul catches up. One heartbeat is not enough (hysteresis)...
      final back = stop.add(const Duration(seconds: 66));
      e.observe(PeerObservation(memberId: 'rahul', at: back, rssi: -70));
      e.tick(back);
      expect(e.latest!.members['rahul']!.state, RopeState.separated);

      // ...three are.
      walk(e, back, back.add(const Duration(seconds: 6)));
      expect(e.latest!.members['rahul']!.state, RopeState.connected);
    });

    test('critical after the escalation window with no reconnection', () {
      final e = engine();
      walk(e, t0, t0.add(const Duration(seconds: 10)));
      final stop = t0.add(const Duration(seconds: 10));
      walk(e, stop, stop.add(const Duration(seconds: 239)), silent: {'anu'});
      expect(e.latest!.members['anu']!.state, RopeState.separated);
      walk(e, stop, stop.add(const Duration(seconds: 242)), silent: {'anu'});
      expect(e.latest!.members['anu']!.state, RopeState.critical);
    });

    test('a member heard only through the chain stays connected', () {
      final e = engine();
      walk(e, t0, t0.add(const Duration(seconds: 90)), chainOnly: {'joseph'});
      expect(e.latest!.members['joseph']!.state, RopeState.connected);
      expect(e.latest!.members['joseph']!.viaChainOnly, isTrue);
    });

    test('steady RSSI drop marks a member weak before any heartbeat is missed', () {
      final e = engine();
      var t = t0;
      for (var rssi = -55; rssi >= -85; rssi -= 2) {
        e.observe(PeerObservation(memberId: 'anu', at: t, rssi: rssi));
        for (final id in ['rahul', 'joseph']) {
          e.observe(PeerObservation(memberId: id, at: t, rssi: -58));
        }
        e.tick(t);
        t = t.add(config.heartbeatInterval);
      }
      expect(e.latest!.members['anu']!.state, RopeState.weak);
      expect(e.latest!.members['rahul']!.state, RopeState.connected);
    });

    test('when most of the group goes quiet, it is us who fell behind', () {
      final e = engine();
      walk(e, t0, t0.add(const Duration(seconds: 20)));
      final stop = t0.add(const Duration(seconds: 20));
      walk(e, stop, stop.add(const Duration(seconds: 30)), silent: {'rahul', 'anu', 'joseph'});
      expect(e.latest!.selfIsolated, isTrue);
      // Two of three quiet is still a strict majority.
      final e2 = engine();
      walk(e2, t0, t0.add(const Duration(seconds: 20)));
      walk(e2, stop, stop.add(const Duration(seconds: 30)), silent: {'rahul', 'anu'});
      expect(e2.latest!.selfIsolated, isTrue);
    });
  });

  group('RopeEngine late joiners and majority', () {
    test('a member added mid-session is not separated at the moment of joining', () {
      final e = engine(members: ['rahul']);
      walk(e, t0, t0.add(const Duration(seconds: 120)));
      final joinAt = t0.add(const Duration(seconds: 120));
      e.addMember('late', at: joinAt);
      final snap = e.tick(joinAt.add(const Duration(seconds: 2)));
      expect(snap.members['late']!.state, RopeState.connected);
      // ...but is flagged if they then stay silent.
      final later = e.tick(joinAt.add(const Duration(seconds: 25)));
      expect(later.members['late']!.state, RopeState.fallingBehind);
    });

    test('exactly half of two others being quiet is not self-isolation', () {
      final e = engine(members: ['a', 'b']);
      walk(e, t0, t0.add(const Duration(seconds: 20)));
      final stop = t0.add(const Duration(seconds: 20));
      walk(e, stop, stop.add(const Duration(seconds: 70)), silent: {'a'});
      expect(e.latest!.members['a']!.state, RopeState.separated);
      expect(e.latest!.selfIsolated, isFalse);
      walk(e, stop.add(const Duration(seconds: 70)), stop.add(const Duration(seconds: 100)), silent: {'a', 'b'});
      expect(e.latest!.selfIsolated, isTrue);
    });
  });

  group('RopePacket', () {
    test('round-trips through the 11-char local name', () {
      const p = RopePacket(sessionHash: 0xBEEF, memberIndex: 7, seq: 200, flags: RopePacket.flagNeedHelp, gossip: 0x0A5);
      final name = p.encode();
      expect(name.length, 11);
      final q = RopePacket.decode(name)!;
      expect(q.sessionHash, 0xBEEF);
      expect(q.memberIndex, 7);
      expect(q.seq, 200);
      expect(q.flags, RopePacket.flagNeedHelp);
      expect(q.hears(0), isTrue);
      expect(q.hears(1), isFalse);
      expect(q.hears(7), isTrue);
    });

    test('rejects foreign device names', () {
      expect(RopePacket.decode('Pixel 8'), isNull);
      expect(RopePacket.decode(null), isNull);
      expect(RopePacket.decode('AAAAAAAAAAAA'), isNull);
    });

    test('session hash is stable and 16-bit', () {
      expect(RopePacket.hashCode16('TRS8A3'), RopePacket.hashCode16('TRS8A3'));
      expect(RopePacket.hashCode16('TRS8A3'), lessThan(0x10000));
      expect(RopePacket.hashCode16('TRS8A3'), isNot(RopePacket.hashCode16('TRS8A4')));
    });
  });
}
