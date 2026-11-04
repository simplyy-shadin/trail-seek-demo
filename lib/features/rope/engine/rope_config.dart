/// Tunable thresholds for the Digital Rope state machine.
///
/// Every number here is a beta hypothesis. The product plan's metrics
/// (time-to-first-warning, false-alert rate, reconnect time) are what we
/// tune these against. Changing them must never require a code change
/// elsewhere.
class RopeConfig {
  const RopeConfig({
    this.heartbeatInterval = const Duration(seconds: 2),
    this.weakMissedHeartbeats = 2,
    this.weakRssiDropDb = 12,
    this.rssiJitterMultiplier = 2.5,
    this.rssiWindow = const Duration(seconds: 30),
    this.fallingBehindAfter = const Duration(seconds: 20),
    this.weakSustainedForFallingBehind = const Duration(seconds: 45),
    this.separatedAfter = const Duration(seconds: 60),
    this.criticalAfter = const Duration(seconds: 180),
    this.recoveryHeartbeats = 3,
  });

  /// How often each phone advertises a heartbeat.
  final Duration heartbeatInterval;

  /// Consecutive missed heartbeats before a member is marked weak.
  final int weakMissedHeartbeats;

  /// RSSI median drop across [rssiWindow] that marks a member weak.
  final int weakRssiDropDb;

  /// Raise the weak-signal threshold when RSSI measurements fluctuate.
  /// Prevents random reflections/phone orientation from causing alert spam.
  final double rssiJitterMultiplier;

  /// Window over which the RSSI trend is evaluated.
  final Duration rssiWindow;

  /// Grace period (the "shoelace" allowance) before falling behind fires.
  final Duration fallingBehindAfter;

  /// Sustained weak signal that escalates to falling behind.
  final Duration weakSustainedForFallingBehind;

  /// Silence (direct or via chain) before a member is separated.
  final Duration separatedAfter;

  /// Time in separated with no reconnection before critical.
  final Duration criticalAfter;

  /// Heartbeats required to recover from an alerting state (hysteresis).
  final int recoveryHeartbeats;

  /// Faster thresholds for demos and widget tests.
  static const demo = RopeConfig(
    heartbeatInterval: Duration(seconds: 1),
    fallingBehindAfter: Duration(seconds: 8),
    weakSustainedForFallingBehind: Duration(seconds: 15),
    separatedAfter: Duration(seconds: 20),
    criticalAfter: Duration(seconds: 40),
  );
}
