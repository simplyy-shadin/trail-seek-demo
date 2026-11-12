# 2026-11-12 — Shared game maps on active journeys

**Branch:** `feat/shared-game-maps-tracking-rope`  
**Base:** `main` after PR #6 squash merge `85a107cc`

## Purpose

Make PR #6's game-styled basemaps selectable in Explore, live solo recording, live Digital Rope group tracking and saved activity route previews while keeping route shapes, participant markers and safety banners above the basemap.

## Changes and line-level scope

| Path | Lines / change |
| --- | --- |
| `lib/features/maps/map_theme_picker.dart` | **New L1–end:** shared, scroll-safe map world picker with Classic satellite/standard/terrain options |
| `lib/features/maps/explore_game_map.dart` | **Modified imports/comment + appended `ThemedMapBaseLayer` and `ThemedMapAttribution`:** shared world provider and attribution, classic raster fallback, unchanged vector-style loader |
| `lib/features/maps/map_tiles.dart` | **MapStyleController:** `select(MapStyle)` to choose Classic layer precisely; old `toggle()` remains |
| `lib/features/explore/map_tab.dart` | **MapTab:** remove local duplicated picker; use shared picker, shared basemap + attribution; destination markers unchanged |
| `lib/features/tracking/tracking_screen.dart` | **imports, FlutterMap base/attribution, map button:** selectable shared map worlds; track GPS data and polyline logic unchanged |
| `lib/features/rope/live_tracking_screen.dart` | **imports, FlutterMap base/attribution, map button:** live route and member marker overlays untouched, alert banners outside map untouched |
| `lib/features/activity/activity_summary_screen.dart` | **imports + route preview:** saved track preview uses same selected map world; no edits to GPX route geometry or social share renderer |
| `test/map_theme_picker_test.dart` | **New L1–end:** shared picker saves Night Trek, Classic terrain restores raster world |
| `changes.md` | Summary entry for this change |

## Important scope boundaries

- No change to position filters, recording controller, BLE mesh transport, geofence/spacing alerts, SOS, notifications or warning sounds.
- Map theme preference is shared across these screens using the existing `explore_map_theme` key, so PR #6 users' preference is preserved. Classic raster source is session-wide as before.
- Vector tiles rely on network or existing visited tile cache; this PR does **not** implement guaranteed offline vector area downloads, or improve satellite/terrain tile licensing.
- Splash/sharing graphics are unchanged. The map preview only changes its base tiles.
- Safety indicators stay outside and above the basemap. Manual hardware testing is required to evaluate map readability under active alerts and low connectivity.

## Validation

- Flutter analysis and automated tests must pass after this change.
- Android debug APK and unsigned iOS compile must pass in GitHub Actions.
- iPhone/Android on-device test: Explore → Night Trek → Solo Track → Digital Rope → Activity Summary, checking basemap, overlays, attribution, selector persistence, camera stability and battery consumption.
- Do not merge into `main` until CI green and a review is complete.
