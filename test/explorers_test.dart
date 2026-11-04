import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/features/community/explorers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every demo explorer has a real face, a history and a character sheet', () async {
    final dir = await ExplorerDirectory.load();
    expect(dir.people.length, 12);
    for (final p in dir.people) {
      expect(p.avatar, startsWith('asset:assets/images/people/'));
      expect(File(p.avatar.substring(6)).existsSync(), isTrue, reason: p.avatar);
      final records = dir.activities[p.id]!;
      expect(records, isNotEmpty, reason: p.id);
      final sheet = CharacterSheet(records);
      // The stored leaderboard XP matches what the app's engine computes.
      expect(sheet.state.totalXp, p.xp, reason: p.username);
      expect(sheet.skills.first.count, greaterThan(0));
    }
  });

  test('the leaderboard leader is a seasoned trekker with badges and records', () async {
    final dir = await ExplorerDirectory.load();
    final top = ([...dir.people]..sort((a, b) => b.xp.compareTo(a.xp))).first;
    final sheet = CharacterSheet(dir.activities[top.id]!);
    expect(sheet.state.level, greaterThanOrEqualTo(6));
    expect(sheet.state.badgeCount, greaterThanOrEqualTo(4));
    expect(sheet.highest!.maxAltitudeM, greaterThanOrEqualTo(2000));
    expect(sheet.archetype, isNotEmpty);
  });
}
