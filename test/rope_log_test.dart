import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trailseek/data/repositories/local_store.dart';
import 'package:trailseek/features/rope/engine/rope_models.dart';
import 'package:trailseek/features/rope/rope_log.dart';

void main() {
  final t0 = DateTime(2026, 10, 30, 6);
  RopeEvent ev(int sec, String m, RopeState from, RopeState to) => RopeEvent(at: t0.add(Duration(seconds: sec)), memberId: m, from: from, to: to);

  final log = RopeSessionLog.capture(
    sessionId: 's1',
    groupName: 'Test',
    adventureName: 'Meesapulimala',
    startedAt: t0,
    endedAt: t0.add(const Duration(minutes: 90)),
    memberCount: 10,
    simulated: false,
    events: [
      ev(130, 'u2', RopeState.connected, RopeState.fallingBehind),
      ev(160, 'u2', RopeState.fallingBehind, RopeState.connected), // 30 s blip → short-lived
      ev(600, 'u3', RopeState.connected, RopeState.fallingBehind),
      ev(650, 'u3', RopeState.fallingBehind, RopeState.separated),
      ev(900, 'u3', RopeState.separated, RopeState.connected), // 300 s real separation
    ],
    messages: [RopeMessage(type: RopeMessageType.waitForMe, fromMemberId: 'u3', at: t0.add(const Duration(seconds: 620)))],
    memberNames: {'u2': 'Riya', 'u3': 'Arjun'},
  );

  test('derives the beta metrics', () {
    expect(log.secondsToFirstWarning, 130);
    expect(log.fallingBehindCount, 2);
    expect(log.separatedCount, 1);
    expect(log.shortLivedAlerts(), 1);
    expect(log.medianReconnectSeconds, anyOf(30, 300));
    expect(log.events.first.member, 'Riya');
  });

  test('CSV exports have headers and one row per session / per event', () {
    final s = RopeSessionLog.summaryCsv([log]).trim().split('\n');
    expect(s.length, 2);
    expect(s.first, startsWith('session_id,group,trail'));
    expect(s[1], contains('"Meesapulimala"'));
    expect(s[1], contains(',bluetooth,'));
    final e = RopeSessionLog.eventsCsv([log]).trim().split('\n');
    expect(e.length, 6);
    expect(e[1], contains('"Riya",connected,fallingBehind'));
  });

  test('store round-trips and keeps newest first', () async {
    SharedPreferences.setMockInitialValues({});
    final store = RopeLogStore(LocalStore(await SharedPreferences.getInstance()));
    await store.save(log);
    final second = RopeSessionLog.fromJson(log.toJson());
    await store.save(RopeSessionLog(
      sessionId: 's2', groupName: second.groupName, adventureName: second.adventureName, startedAt: t0, endedAt: t0,
      memberCount: 3, simulated: true, events: const [], messages: const [], platform: 'test',
    ));
    final all = store.all();
    expect(all.map((l) => l.sessionId), ['s2', 's1']);
    expect(all.last.secondsToFirstWarning, 130);
  });
}
