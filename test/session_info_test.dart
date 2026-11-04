import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/data/models/activity_record.dart';
import 'package:trailseek/data/models/session_summary.dart';
import 'package:trailseek/features/rope/links/rope_roster.dart';

void main() {
  test('roster head carries the group details and older heads parse without them', () {
    final info = SessionInfo(
      adventureId: 'meesapulimala',
      adventureName: 'Meesapulimala',
      groupName: 'Bench | two',
      date: DateTime(2026, 10, 30, 6),
      expectedStart: DateTime(2026, 10, 30, 6, 30),
      plannedSize: 6,
    );
    final snap = RosterSnapshot(sessionHash: 1234, code: 'M8KS6N', info: info, entries: const [
      RosterEntry(index: 0, id: 'org-1', name: 'Shad', ageSec: 0, isOrganizer: true),
      RosterEntry(index: 1, id: 'mem-2', name: 'Amalu', ageSec: 3),
    ]);
    final back = RosterSnapshot.fromBytes(snap.toBytes());
    expect(back.code, 'M8KS6N');
    expect(back.entries.length, 2);
    expect(back.info, isNotNull);
    expect(back.info!.adventureId, 'meesapulimala');
    expect(back.info!.groupName, 'Bench | two');
    expect(back.info!.date, DateTime(2026, 10, 30, 6));
    expect(back.info!.expectedStart, DateTime(2026, 10, 30, 6, 30));
    expect(back.info!.plannedSize, 6);

    final old = RosterSnapshot(sessionHash: 1234, code: 'M8KS6N', entries: snap.entries);
    expect(RosterSnapshot.fromBytes(old.toBytes()).info, isNull);
  });

  test('a one-minute zero-distance group session is neither verified nor counted', () {
    final s = SessionSummary(
      sessionId: 's1',
      adventureId: 'chembra-peak',
      adventureName: 'Chembra Peak',
      endedAt: DateTime(2026, 10, 18, 21, 49),
      durationSeconds: 60,
      distanceKm: 0,
      elevationGainM: 0,
      maxElevationM: 0,
      memberCount: 2,
      separationEvents: 0,
      fallingBehindEvents: 0,
      simulated: false,
    );
    final r = ActivityRecord.fromSessionSummary(s);
    expect(r.verified, isFalse);
    expect(r.isTrivial, isTrue);
  });
}
