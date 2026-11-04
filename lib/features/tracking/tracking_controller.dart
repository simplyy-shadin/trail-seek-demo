import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../data/models/activity_record.dart';
import '../../data/models/adventure.dart';
import '../rope/engine/geo.dart';
import 'position_stream.dart';
import 'track_recorder.dart';

enum TrackingStatus { idle, recording, paused, finished }

@immutable
class TrackingState {
  const TrackingState({
    this.status = TrackingStatus.idle,
    this.type = ActivityType.trekking,
    this.adventureId,
    this.adventureName,
    this.district,
    this.startedAt,
    this.elapsed = Duration.zero,
    this.distanceM = 0,
    this.gainM = 0,
    this.currentAltitudeM,
    this.maxAltitudeM,
    this.points = const [],
    this.lastPosition,
    this.accuracyM,
    this.error,
    this.restored = false,
    this.finishedActivityId,
    this.stationaryFor = Duration.zero,
  });

  final TrackingStatus status;
  final ActivityType type;
  final String? adventureId;
  final String? adventureName;
  final String? district;
  final DateTime? startedAt;
  final Duration elapsed;
  final double distanceM;
  final int gainM;
  final double? currentAltitudeM;
  final double? maxAltitudeM;
  final List<GeoPoint> points;
  final GeoPoint? lastPosition;
  final double? accuracyM;
  final String? error;

  /// True when this session was restored after the app was killed.
  final bool restored;
  final String? finishedActivityId;

  /// How long the phone has not moved (speed < 0.5 m/s). Shown as "Resting"
  /// after 2 minutes; recording continues, so nothing is lost.
  final Duration stationaryFor;
  bool get isResting => status == TrackingStatus.recording && stationaryFor >= const Duration(minutes: 2);

  bool get isActive => status == TrackingStatus.recording || status == TrackingStatus.paused;
  double get distanceKm => distanceM / 1000;

  TrackingState copyWith({
    TrackingStatus? status,
    Duration? elapsed,
    double? distanceM,
    int? gainM,
    double? currentAltitudeM,
    double? maxAltitudeM,
    List<GeoPoint>? points,
    GeoPoint? lastPosition,
    double? accuracyM,
    String? error,
    bool clearError = false,
    bool? restored,
    String? finishedActivityId,
    Duration? stationaryFor,
  }) =>
      TrackingState(
        status: status ?? this.status,
        type: type,
        adventureId: adventureId,
        adventureName: adventureName,
        district: district,
        startedAt: startedAt,
        elapsed: elapsed ?? this.elapsed,
        distanceM: distanceM ?? this.distanceM,
        gainM: gainM ?? this.gainM,
        currentAltitudeM: currentAltitudeM ?? this.currentAltitudeM,
        maxAltitudeM: maxAltitudeM ?? this.maxAltitudeM,
        points: points ?? this.points,
        lastPosition: lastPosition ?? this.lastPosition,
        accuracyM: accuracyM ?? this.accuracyM,
        error: clearError ? null : (error ?? this.error),
        restored: restored ?? this.restored,
        finishedActivityId: finishedActivityId ?? this.finishedActivityId,
        stationaryFor: stationaryFor ?? this.stationaryFor,
      );
}

/// Owns one solo recording. Persists a snapshot every 30 s so a crash or a
/// system kill does not lose the trek; the next launch restores it paused.
class TrackingController extends Notifier<TrackingState> {
  TrackRecorder _recorder = TrackRecorder();
  StreamSubscription<geo.Position>? _sub;
  Timer? _ticker;
  Timer? _persist;
  Duration _pausedAccum = Duration.zero;
  DateTime? _resumedAt;

  static const _snapshotKey = 'active_track';

  @override
  TrackingState build() {
    ref.onDispose(_cancelStreams);
    return _restore() ?? const TrackingState();
  }

  TrackingState? _restore() {
    final raw = ref.read(localStoreProvider).rawString(_snapshotKey);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _recorder = TrackRecorder.fromJson(j['recorder'] as Map<String, dynamic>);
      _pausedAccum = Duration(milliseconds: j['elapsedMs'] as int);
      return TrackingState(
        status: TrackingStatus.paused,
        type: ActivityType.values.firstWhere((t) => t.name == j['type'], orElse: () => ActivityType.trekking),
        adventureId: j['adventureId'] as String?,
        adventureName: j['adventureName'] as String?,
        district: j['district'] as String?,
        startedAt: DateTime.parse(j['startedAt'] as String),
        elapsed: _pausedAccum,
        distanceM: _recorder.distanceM,
        gainM: _recorder.gainM,
        currentAltitudeM: _recorder.currentAltitudeM,
        maxAltitudeM: _recorder.maxAltitudeM,
        points: _recorder.downsample().map((p) => p.geo).toList(),
        lastPosition: _recorder.last?.geo,
        restored: true,
      );
    } catch (_) {
      ref.read(localStoreProvider).removeRaw(_snapshotKey);
      return null;
    }
  }

  Future<String?> start({required ActivityType type, Adventure? adventure}) async {
    final denied = await ensureLocationPermission();
    if (denied != null) return denied;
    await _cancelStreams();
    _recorder = TrackRecorder();
    _pausedAccum = Duration.zero;
    state = TrackingState(
      status: TrackingStatus.recording,
      type: type,
      adventureId: adventure?.id,
      adventureName: adventure?.name,
      district: adventure?.district,
      startedAt: DateTime.now(),
    );
    _listen();
    return null;
  }

  void _listen() {
    _resumedAt = DateTime.now();
    _sub = ref.read(positionStreamProvider).listen(_onPosition, onError: (Object e) {
      state = state.copyWith(error: 'Location error: $e');
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _persist = Timer.periodic(const Duration(seconds: 30), (_) => _save());
  }

  DateTime? _movingAt;

  void _onPosition(geo.Position p) {
    if (state.status != TrackingStatus.recording) return;
    final moving = !p.speed.isNaN && p.speed >= 0.5;
    if (moving || _movingAt == null) _movingAt = p.timestamp;
    final point = TrackPoint(
      lat: p.latitude,
      lng: p.longitude,
      at: p.timestamp,
      altitudeM: p.altitude.isNaN ? null : p.altitude,
      accuracyM: p.accuracy,
      speedMps: p.speed.isNaN ? null : p.speed,
    );
    final accepted = _recorder.add(point);
    state = state.copyWith(
      lastPosition: point.geo,
      accuracyM: p.accuracy,
      distanceM: _recorder.distanceM,
      gainM: _recorder.gainM,
      currentAltitudeM: _recorder.currentAltitudeM,
      maxAltitudeM: _recorder.maxAltitudeM,
      points: accepted ? [...state.points, point.geo] : null,
      stationaryFor: _movingAt == null ? Duration.zero : p.timestamp.difference(_movingAt!),
      clearError: true,
    );
  }

  void _tick() {
    final r = _resumedAt;
    if (state.status != TrackingStatus.recording || r == null) return;
    state = state.copyWith(elapsed: _pausedAccum + DateTime.now().difference(r));
  }

  Future<void> pause() async {
    if (state.status != TrackingStatus.recording) return;
    final r = _resumedAt;
    if (r != null) _pausedAccum += DateTime.now().difference(r);
    _resumedAt = null;
    await _sub?.cancel();
    _sub = null;
    _ticker?.cancel();
    state = state.copyWith(status: TrackingStatus.paused, elapsed: _pausedAccum);
    await _save();
  }

  Future<String?> resume() async {
    if (state.status != TrackingStatus.paused) return null;
    final denied = await ensureLocationPermission();
    if (denied != null) return denied;
    state = state.copyWith(status: TrackingStatus.recording, restored: false);
    _listen();
    return null;
  }

  /// Finishes the recording, stores the activity and its track, and returns the id.
  Future<String> stop() async {
    if (state.status == TrackingStatus.recording) {
      final r = _resumedAt;
      if (r != null) _pausedAccum += DateTime.now().difference(r);
    }
    await _cancelStreams();
    final s = state;
    final id = const Uuid().v4();
    final startedAt = s.startedAt ?? DateTime.now();
    final endedAt = startedAt.add(_pausedAccum);
    final record = ActivityRecord(
      id: id,
      type: s.type,
      title: s.adventureName ?? _defaultTitle(s.type, startedAt),
      startedAt: startedAt,
      endedAt: endedAt.isAfter(startedAt) ? endedAt : startedAt.add(const Duration(seconds: 1)),
      distanceM: _recorder.distanceM,
      elevationGainM: _recorder.gainM,
      maxAltitudeM: (_recorder.maxAltitudeM ?? 0).round(),
      verified: _recorder.verified,
      trailId: s.adventureId,
      district: s.district,
    );
    final store = ref.read(localStoreProvider);
    await store.setRaw('track_$id', jsonEncode({
      'points': _recorder.downsample(2).map((p) => p.toJson()).toList(),
      'movingMs': _recorder.movingTime.inMilliseconds,
      'accuracyRatio': _recorder.accuracyRatio,
    }));
    await store.removeRaw(_snapshotKey);
    await ref.read(activitiesProvider.notifier).add(record);
    state = TrackingState(status: TrackingStatus.finished, type: s.type, finishedActivityId: id);
    return id;
  }

  /// Throws away the current recording without saving.
  Future<void> discard() async {
    await _cancelStreams();
    await ref.read(localStoreProvider).removeRaw(_snapshotKey);
    state = const TrackingState();
  }

  void reset() {
    if (state.status == TrackingStatus.finished) state = const TrackingState();
  }

  Future<void> _save() async {
    final s = state;
    if (!s.isActive) return;
    final elapsed = s.status == TrackingStatus.recording && _resumedAt != null
        ? _pausedAccum + DateTime.now().difference(_resumedAt!)
        : _pausedAccum;
    await ref.read(localStoreProvider).setRaw(
        _snapshotKey,
        jsonEncode({
          'type': s.type.name,
          'adventureId': s.adventureId,
          'adventureName': s.adventureName,
          'district': s.district,
          'startedAt': (s.startedAt ?? DateTime.now()).toIso8601String(),
          'elapsedMs': elapsed.inMilliseconds,
          'recorder': _recorder.toJson(),
        }));
  }

  Future<void> _cancelStreams() async {
    await _sub?.cancel();
    _sub = null;
    _ticker?.cancel();
    _ticker = null;
    _persist?.cancel();
    _persist = null;
  }

  static String _defaultTitle(ActivityType t, DateTime at) {
    final name = switch (t) {
      ActivityType.trekking => 'Trek',
      ActivityType.hiking => 'Hike',
      ActivityType.forestWalk => 'Forest walk',
      ActivityType.cycling || ActivityType.mountainBiking => 'Ride',
      ActivityType.kayaking || ActivityType.rafting => 'Paddle',
      ActivityType.trailRunning || ActivityType.groupJogging => 'Run',
      _ => 'Activity',
    };
    final part = at.hour < 12 ? 'Morning' : (at.hour < 17 ? 'Afternoon' : 'Evening');
    return '$part $name';
  }
}

final trackingProvider = NotifierProvider<TrackingController, TrackingState>(TrackingController.new);
