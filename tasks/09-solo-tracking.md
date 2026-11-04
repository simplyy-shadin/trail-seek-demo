# 09 · Solo GPS live tracking (record a trek)

**Status:** done in code (2026-10-18). Still open: the real-walk, kill-and-restore and battery checks on the Pixel, and the stationary GPS back-off. · **Size:** L · **Depends on:** 01, 02

## Goal
Frame 8: "Trekking · Recording · 02:14:26" over a map, live route line, distance, elevation gain, current
altitude, pause/resume/stop. This produces the **verified** activities that drive XP (05).

## Scope
- `lib/features/tracking/`:
  - `TrackRecorder` (pure Dart): consumes `Position` samples → filters (accuracy > 25 m dropped, speed > 8 m/s dropped for hiking),
    smooths altitude (median of 5), computes distance (haversine), elevation gain (threshold 3 m), max altitude, moving time vs elapsed, pace.
  - `TrackingController` (Riverpod): states idle / recording / paused / finished; persists samples every 30 s to disk so a crash doesn't lose the trek.
  - Activity type picker: Trekking, Hiking, Forest Walk, Cycling, Kayaking, Trail Running (icons from `ActivityCategory`).
  - Optional link to a trail (`adventureId`) from Explore detail or Home "Start Trek".
- UI: map (flutter_map) with route polyline, position marker with heading, recenter + layers buttons, stat panel, big neon pause button, long-press to stop.
- Background recording:
  - Android: foreground service with `location` type (`flutter_foreground_task`), persistent notification with live distance.
  - iOS: `location` background mode (already in Info.plist), `allowsBackgroundLocationUpdates`, `pausesLocationUpdatesAutomatically = false`.
  - Battery: 1 Hz GPS while moving, back off to 0.2 Hz when stationary > 60 s.
- Permissions: ask "while in use" first, explain, then "always" only when the user starts a recording.
- On stop → Activity summary (10), `ActivityRecord` saved with `verified = true` when ≥ 80 % of samples had accuracy ≤ 25 m and track length ≥ 500 m.

## Acceptance
- A 20-minute walk recorded on the Pixel 8 with the screen locked keeps the full track; distance within 5 % of Google Fit / a reference app.
- Kill the app mid-recording, reopen: the recording resumes from persisted samples with a "Recording restored" toast.
- Unit tests for the recorder with a synthetic track (distance, gain, noise rejection).
- Battery drain under 8 % per hour on Pixel 8 with screen off (measure with `adb shell dumpsys batterystats`).

## Implementation notes
- Reuse `haversineMetres` and `Route` from `lib/features/rope/engine/geo.dart`.
- The Digital Rope controller already consumes GPS in BLE mode; share one `PositionStream` provider so both never open two GPS streams.
- Elevation from GPS is noisy; display "approx." and later blend with a DEM lookup (out of scope here).
