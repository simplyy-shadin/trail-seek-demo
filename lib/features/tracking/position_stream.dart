import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;

import 'ref_counted_broadcast_stream.dart';

/// The one GPS stream for the whole app. Solo tracking and the Digital Rope
/// share it so two sessions never open two location streams.
///
/// On Android this runs inside a foreground service with a persistent
/// notification while actively trekking. Balanced GPS requests avoid a
/// one-second/no-distance-filter busy stream and a permanent CPU wake lock.
/// Keep location active during a trek so safety doesn't depend on an app
/// waking from a GPS pause. Measure screen-locked reliability on real devices.
final positionStreamProvider = Provider<Stream<geo.Position>>((ref) {
  final settings = switch (defaultTargetPlatform) {
    TargetPlatform.android => geo.AndroidSettings(
        accuracy: geo.LocationAccuracy.high,
        // Balanced acquisition: short turns still reach the adaptive recorder
        // without requesting continuous 1 Hz GNSS updates while stationary.
        distanceFilter: 2,
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: const geo.ForegroundNotificationConfig(
          notificationTitle: 'Trail Seek is recording',
          notificationText: 'Keeping your track while the screen is off',
          notificationChannelName: 'Activity recording',
          // Foreground service remains; avoid holding a CPU lock for the
          // entire trek. Verify background behavior on each Android model.
          enableWakeLock: false,
          setOngoing: true,
          notificationIcon: geo.AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        ),
      ),
    TargetPlatform.iOS || TargetPlatform.macOS => geo.AppleSettings(
        // iPhone field testing is prioritized: preserve best GNSS precision
        // but allow the OS to coalesce sub-three-metre location noise.
        accuracy: geo.LocationAccuracy.best,
        distanceFilter: 3,
        activityType: geo.ActivityType.fitness,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      ),
    _ => const geo.LocationSettings(accuracy: geo.LocationAccuracy.best, distanceFilter: 3),
  };
  final shared = RefCountedBroadcastStream<geo.Position>(
    () => geo.Geolocator.getPositionStream(locationSettings: settings),
  );
  ref.onDispose(() { unawaited(shared.dispose()); });
  return shared;
});

/// Requests "while in use" location. Returns null when granted, else a
/// human-readable reason.
Future<String?> ensureLocationPermission() async {
  if (!await geo.Geolocator.isLocationServiceEnabled()) {
    return 'Turn on Location (GPS) to record a trek.';
  }
  var p = await geo.Geolocator.checkPermission();
  if (p == geo.LocationPermission.denied) p = await geo.Geolocator.requestPermission();
  return switch (p) {
    geo.LocationPermission.always || geo.LocationPermission.whileInUse => null,
    geo.LocationPermission.deniedForever => 'Location is blocked for Trail Seek. Allow it in system settings.',
    _ => 'Location permission is needed to record a trek.',
  };
}
