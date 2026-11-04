import 'session_summary.dart';

/// Pure-Dart activity type (mirrors [ActivityCategory] names without Flutter).
enum ActivityType { trekking, hiking, forestWalk, mountaineering, rockClimbing, camping, cycling, mountainBiking, trailRunning, groupJogging, kayaking, rafting, waterfallTrail, other }

/// One completed outing. Produced by the GPS recorder (solo) or a Digital Rope
/// session (group). This is what XP, badges, history and sync all consume.
class ActivityRecord {
  const ActivityRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.startedAt,
    required this.endedAt,
    required this.distanceM,
    required this.elevationGainM,
    required this.maxAltitudeM,
    required this.verified,
    this.trailId,
    this.district,
    this.groupSessionId,
    this.memberCount = 1,
    this.separations = 0,
    this.simulated = false,
  });

  factory ActivityRecord.fromJson(Map<String, dynamic> j) => ActivityRecord(
        id: j['id'] as String,
        type: ActivityType.values.firstWhere((t) => t.name == j['type'], orElse: () => ActivityType.other),
        title: j['title'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        endedAt: DateTime.parse(j['endedAt'] as String),
        distanceM: (j['distanceM'] as num).toDouble(),
        elevationGainM: (j['elevationGainM'] as num).toInt(),
        maxAltitudeM: (j['maxAltitudeM'] as num).toInt(),
        verified: j['verified'] as bool? ?? false,
        trailId: j['trailId'] as String?,
        district: j['district'] as String?,
        groupSessionId: j['groupSessionId'] as String?,
        memberCount: j['memberCount'] as int? ?? 1,
        separations: j['separations'] as int? ?? 0,
        simulated: j['simulated'] as bool? ?? false,
      );

  /// Adapter for sessions recorded before activities existed.
  factory ActivityRecord.fromSessionSummary(SessionSummary s, {ActivityType type = ActivityType.trekking, String? district}) =>
      ActivityRecord(
        id: 'session-${s.sessionId}',
        type: type,
        title: s.adventureName,
        startedAt: s.endedAt.subtract(Duration(seconds: s.durationSeconds)),
        endedAt: s.endedAt,
        distanceM: s.distanceKm * 1000,
        elevationGainM: s.elevationGainM,
        maxAltitudeM: s.maxElevationM,
        verified: !s.simulated && s.distanceKm * 1000 >= ActivityRecord.minVerifiedDistanceM && s.durationSeconds >= ActivityRecord.minVerifiedSeconds,
        trailId: s.adventureId,
        district: district,
        groupSessionId: s.sessionId,
        memberCount: s.memberCount,
        separations: s.separationEvents,
        simulated: s.simulated,
      );

  final String id;
  final ActivityType type;
  final String title;
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceM;
  final int elevationGainM;
  final int maxAltitudeM;

  /// GPS-verified by the app (see task 09 thresholds). Never means officially certified.
  final bool verified;

  /// Below both of these an activity is a test tap, not an outing: no XP, no badges.
  static const minVerifiedDistanceM = 300.0;
  static const minVerifiedSeconds = 300;
  bool get isTrivial => distanceM < minVerifiedDistanceM && endedAt.difference(startedAt).inSeconds < minVerifiedSeconds;
  final String? trailId;
  final String? district;
  final String? groupSessionId;
  final int memberCount;
  final int separations;
  final bool simulated;

  Duration get duration => endedAt.difference(startedAt);
  double get distanceKm => distanceM / 1000;
  bool get isGroup => groupSessionId != null && memberCount > 1;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'distanceM': distanceM,
        'elevationGainM': elevationGainM,
        'maxAltitudeM': maxAltitudeM,
        'verified': verified,
        'trailId': trailId,
        'district': district,
        'groupSessionId': groupSessionId,
        'memberCount': memberCount,
        'separations': separations,
        'simulated': simulated,
      };
}
