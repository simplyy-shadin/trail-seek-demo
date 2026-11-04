import '../../data/models/activity_record.dart';

/// XP awarded per completed activity. All numbers are beta hypotheses; keep
/// them here so tuning never touches the engine.
class XpRules {
  const XpRules({
    this.base = 100,
    this.perKm = 10,
    this.per100mGain = 5,
    this.groupBonus = 50,
    this.firstTimeOnTrailBonus = 25,
    this.unverifiedFactor = 0.25,
    this.cap = 1500,
  });

  final int base;
  final int perKm;
  final int per100mGain;
  final int groupBonus;
  final int firstTimeOnTrailBonus;
  final double unverifiedFactor;
  final int cap;

  int xpFor(ActivityRecord r, {required bool firstTimeOnTrail}) {
    var xp = base + (r.distanceKm * perKm).floor() + (r.elevationGainM ~/ 100) * per100mGain;
    if (r.isGroup) xp += groupBonus;
    if (firstTimeOnTrail && r.trailId != null) xp += firstTimeOnTrailBonus;
    if (!r.verified) xp = (xp * unverifiedFactor).round();
    return xp.clamp(0, cap);
  }
}
