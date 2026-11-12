# 2026-11-12 — Explore game-themed vector maps

**Branch:** `feat/explore-game-map-themes` (PR pending at authoring time)  
**Scope:** Explore map only. No changes to location collection, GPS tracking, Digital Rope, or its safety warning logic.

## Functional changes

- Add two real geography-linked vector styles: **Adventure RPG** (parchment/forest/trails) and **Night Trek** (dark terrain/high-contrast paths).
- Add a bottom-sheet theme picker in the Explore map; retain **Classic** as the default and fallback.
- Persist theme choice through the existing `LocalStore` / SharedPreferences.
- Reuse `flutter_map` and its destination markers; switching theme does not reset the FlutterMap camera.
- Load locally bundled MapLibre styles through `flutter_map_vector_tiles`, using OpenFreeMap/OpenMapTiles geographic data.
- Fall back to existing tiles while a vector style loads or if its style reader fails; vector tile request failure is handled internally by the package.
- Preserve visible map-data attribution. Vector tile view is online-first; the existing raster offline downloader was **not** modified or claimed compatible.

## Files / changed-line references

| File | Change |
| --- | --- |
| `assets/maps/styles/adventure_rpg.json` | New file L1–end: vector cartography for forests, water, roads, footpaths, place names |
| `assets/maps/styles/night_trek.json` | New file L1–end: dark vector cartography with bright paths and place names |
| `lib/features/maps/explore_game_map.dart` | New file L1–end: theme enum, preference provider, loaded vector basemap |
| `lib/features/explore/map_tab.dart` | Modified: imports, new bottom-sheet picker, Explore basemap selection and attribution |
| `pubspec.yaml` | Modified: `flutter_map_vector_tiles` dependency and new asset directory |
| `test/explore_game_map_test.dart` | New file L1–end: style schema/assets, persistent selection and unknown-value fallback |
| `android/settings.gradle.kts` | Changed AGP plugin version from 9.1.0 to 9.1.1 (Flutter CI compatibility) |
| `changes.md` | Summary entry for this feature |

## Verification and boundaries

- Initial Flutter test/analysis workflow passed; initial Android smoke build failed on the pre-existing AGP 9.1.0 mismatch, now bumped to 9.1.1 for recheck.
- Tests to run in PR CI: `flutter pub get`, `flutter analyze`, `flutter test`, plus Android APK and iOS unsigned compile.
- Real devices have **not** yet verified tile styling, map FPS, battery use, weak coverage or offline behaviour.
- The existing `pubspec.lock` is not manually edited: `flutter pub get` must regenerate package resolutions.
- OpenFreeMap public tiles are for initial proof-of-concept and require attribution; honor the provider terms for offline download. No bulk download or offline tile migration in this PR.
- This does not reproduce any proprietary game's artwork, logos, or UI.
