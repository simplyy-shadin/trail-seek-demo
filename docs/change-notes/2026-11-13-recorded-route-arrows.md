# 2026-11-13 — PR #13: directional chevrons on recorded route paths

**Branch:** `feat/recorded-route-direction-arrows` (base `main` after PR #12 `e0991b4`).

## Feature
Render small, static Trailseek-branded direction chevrons on existing **solo recorded GPS routes** and their completed-activity map previews. This helps explain which direction an explorer **already travelled**; it is **not** turn-by-turn navigation, a safe-trail recommendation, or directions toward a destination.

- Geometry samples recorded points approximately every 150 m. On long recordings spacing scales up to a maximum of **24** chevrons. Invalid/duplicate points, anti-meridian discontinuities and any single segment over **2 km** are ignored for arrows.
- Compass bearings use the spherical initial-bearing formula and markers follow the geographic recorded route positions. The renderer is static and pointer-transparent; it uses no animation timer, no additional GPS, network, BLE or camera subscriptions.
- Rendering goes **above** route polylines but **below** the live solo GPS pin / activity start-end pins. Digital Rope's live group map (with its SOS/member overlays) is untouched.
- Route coordinates and sampled arrow geometry are cached across the 1-second solo timer tick, reducing repeated projection and trigonometry; the cache invalidates when SmartTrace accepts new points.

## Files and line scopes
| File | Changes |
| --- | --- |
| `lib/features/maps/recorded_route_arrows.dart` | **New L1–end:** validating and sampling route-direction geometry, compass bearings and hard marker cap |
| `lib/features/maps/recorded_route_arrow_layer.dart` | **New L1–end:** visual decorative markers with cached sampling and touch transparency |
| `lib/features/tracking/tracking_screen.dart` | **Modified `_TrackingScreenState` and map-layer section:** reuse accepted route LatLng conversion, render arrows between path polyline and live GPS marker |
| `lib/features/activity/activity_summary_screen.dart` | **Modified imports/map-layer section:** render saved-activity solo route arrows below start/end markers |
| `test/recorded_route_arrows_test.dart` | **New L1–end:** north/east bearings, short/invalid routes, GPS teleport/dateline gap, marker cap and bad params |
| `README.md`, `changes.md` | Daily TODO, pending QA and per-file change summary |

## Acceptance and limits
- [ ] Flutter analyzer and complete test suite success
- [ ] Android debug APK compile and unsigned iOS compile success
- [ ] iPhone/Android route preview tests: curved trails, large tracks, zoom and map-rotation alignment, accessibility/legibility, battery
- [ ] Verify no new UI covers Digital Rope live SOS/group tracking; code keeps that map entirely unchanged

The arrows describe **historic direction travelled**, not a licensed road/trail navigation graph. Animated arrows, turn-by-turn/voice instructions, multipoint routing, POI discovery and real phone QA remain pending. Orientation against manually rotated map cameras needs visual validation. No changes to SmartTrace filtering or Digital Rope BLE/alert engines.
