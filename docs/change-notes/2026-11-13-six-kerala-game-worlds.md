# 2026-11-13 — PR #12: six original Kerala game-map worlds

**Branch:** `feat/six-kerala-game-map-worlds` (base `main` after PR #11 merge `fc8390b`).

## Change overview
Four newly composed geographic vector-map palettes complement the existing Adventure RPG and Night Trek worlds. Classic remains a seventh, non-game basemap option. No proprietary MapShifter artwork, icons or code is copied.

The new worlds preserve the same source identifier (`openmaptiles`), layer IDs, Mapbox-style v8 expressions, destination/route coordinates and OpenStreetMap attribution as the validated original style. This allows current online OpenFreeMap tiles and the local MBTiles provider to be used as before; **real-device offline rendering is not yet verified**.

| World | Visual direction | Map style file |
| --- | --- | --- |
| Adventure RPG | Original parchment/forest | `adventure_rpg.json` (existing) |
| Night Trek | Original dark green/night | `night_trek.json` (existing) |
| Monsoon Mist | Rain-washed greens / cool teal water | `monsoon_mist.json` |
| Highland Quest | Warm ochre rock / hill meadows | `highland_quest.json` |
| Coastal Explorer | Aqua coast / sandy villages | `coastal_explorer.json` |
| Canopy Quest | Jungle green / amber expedition routes | `canopy_quest.json` |

## Per-file changes and references

- **New `assets/maps/styles/monsoon_mist.json` (L1–end)**: original cool monsoon palette; every vector layer, expression and attribution preserved.
- **New `assets/maps/styles/highland_quest.json` (L1–end)**: original warm hill palette; preserves required vector semantics.
- **New `assets/maps/styles/coastal_explorer.json` (L1–end)**: original blue/sand palette; preserves required vector semantics.
- **New `assets/maps/styles/canopy_quest.json` (L1–end)**: original dark forest/amber palette; preserves required vector semantics.
- **`lib/features/maps/explore_game_map.dart`**: expanded `ExploreMapTheme` enum, added per-world contrast accents; shared renderer handles all worlds without GPS or BLE code changes.
- **`lib/features/maps/map_theme_picker.dart`**: colored circular icon previews for the six game worlds + Classic, still scroll-safe and persistent.
- **`lib/features/explore/map_tab.dart`**: map-world-aware destination-pin color for contrast; existing highlighted-selected marker behavior preserved.
- **`test/explore_game_map_test.dart`**: verifies six distinct game styles + Classic, correct OpenFreeMap source and attribution, retained trail/symbol layers, unique background/trail colors and preference persistence.
- **`test/map_theme_picker_test.dart`**: new-world list and selection persistence regression test.
- **`README.md`, `changes.md`**: update daily TODO and pending device validation.

## Scope and acceptance
- [ ] Flutter analysis + full tests pass
- [ ] Android debug APK + unsigned iOS compilation pass
- [ ] iPhone / Android manual screenshots in Kerala pilot area at several zoom levels
- [ ] Check label contrast, roads/trails, destinations, route overlays, attribution and offline MBTiles with each style
- [ ] Monitor GPU/battery usage and ensure active Digital Rope safety overlays remain readable

**Deferred:** original animated route arrows, turn-by-turn navigation, voice, POI search, saved favorites, Fog of War achievements, signed distributions. Those stay explicitly pending in README. Game maps and Fog of War are visualization/gamification only, not a validated safety or navigation system.
