/// Level thresholds and titles.
///
/// XP needed to go from level n to n+1 grows by 250 each level:
/// 1→2: 500, 2→3: 750, 3→4: 1,000, 4→5: 1,250 …
class LevelTable {
  const LevelTable({this.firstStep = 500, this.increment = 250, this.maxLevel = 50});

  final int firstStep;
  final int increment;
  final int maxLevel;

  int xpToNext(int level) => firstStep + increment * (level - 1);

  /// Cumulative XP required to *reach* [level].
  int xpToReach(int level) {
    var total = 0;
    for (var l = 1; l < level; l++) {
      total += xpToNext(l);
    }
    return total;
  }

  LevelPosition positionFor(int totalXp) {
    var level = 1;
    var remaining = totalXp < 0 ? 0 : totalXp;
    while (level < maxLevel && remaining >= xpToNext(level)) {
      remaining -= xpToNext(level);
      level++;
    }
    final forLevel = level >= maxLevel ? xpToNext(level) : xpToNext(level);
    return LevelPosition(level: level, xpInLevel: level >= maxLevel ? forLevel : remaining, xpForLevel: forLevel, totalXp: totalXp);
  }

  static String titleFor(int level) {
    if (level >= 25) return 'Mountain Legend';
    if (level >= 15) return 'Summit Keeper';
    if (level >= 10) return 'Ridge Walker';
    if (level >= 6) return 'Pathfinder';
    if (level >= 3) return 'Adventure Seeker';
    return 'Trail Rookie';
  }
}

class LevelPosition {
  const LevelPosition({required this.level, required this.xpInLevel, required this.xpForLevel, required this.totalXp});
  final int level;
  final int xpInLevel;
  final int xpForLevel;
  final int totalXp;
  String get title => LevelTable.titleFor(level);
  double get fraction => xpForLevel == 0 ? 1 : (xpInLevel / xpForLevel).clamp(0, 1);
}
