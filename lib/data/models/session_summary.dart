/// What we keep after a Digital Rope session ends. Feeds history,
/// milestones and the beta metrics list in the product plan.
class SessionSummary {
  const SessionSummary({
    required this.sessionId,
    required this.adventureId,
    required this.adventureName,
    required this.endedAt,
    required this.durationSeconds,
    required this.memberCount,
    required this.distanceKm,
    required this.maxElevationM,
    required this.elevationGainM,
    required this.separationEvents,
    required this.fallingBehindEvents,
    required this.simulated,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> j) => SessionSummary(
        sessionId: j['sessionId'] as String,
        adventureId: j['adventureId'] as String,
        adventureName: j['adventureName'] as String,
        endedAt: DateTime.parse(j['endedAt'] as String),
        durationSeconds: j['durationSeconds'] as int,
        memberCount: j['memberCount'] as int,
        distanceKm: (j['distanceKm'] as num).toDouble(),
        maxElevationM: j['maxElevationM'] as int,
        elevationGainM: j['elevationGainM'] as int,
        separationEvents: j['separationEvents'] as int,
        fallingBehindEvents: j['fallingBehindEvents'] as int? ?? 0,
        simulated: j['simulated'] as bool? ?? true,
      );

  final String sessionId;
  final String adventureId;
  final String adventureName;
  final DateTime endedAt;
  final int durationSeconds;
  final int memberCount;
  final double distanceKm;
  final int maxElevationM;
  final int elevationGainM;
  final int separationEvents;
  final int fallingBehindEvents;
  final bool simulated;

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'adventureId': adventureId,
        'adventureName': adventureName,
        'endedAt': endedAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        'memberCount': memberCount,
        'distanceKm': distanceKm,
        'maxElevationM': maxElevationM,
        'elevationGainM': elevationGainM,
        'separationEvents': separationEvents,
        'fallingBehindEvents': fallingBehindEvents,
        'simulated': simulated,
      };
}

/// Milestone ladder from the product plan. Never labelled as
/// government-certified.
class Milestone {
  const Milestone(this.sessions, this.title, this.reward);
  final int sessions;
  final String title;
  final String reward;

  static const ladder = [
    Milestone(3, 'Digital Rope Explorer', 'Digital badge and share card'),
    Milestone(5, 'Trail Keeper', 'Digital badge'),
    Milestone(10, 'Rope Guardian', 'Sponsor coupon where available'),
    Milestone(20, 'Summit Circle', 'Limited sponsor-funded patch'),
  ];

  static Milestone? current(int completed) {
    Milestone? best;
    for (final m in ladder) {
      if (completed >= m.sessions) best = m;
    }
    return best;
  }

  static Milestone? next(int completed) {
    for (final m in ladder) {
      if (completed < m.sessions) return m;
    }
    return null;
  }
}
