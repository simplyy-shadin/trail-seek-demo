# 2026-11-12 — PR #8 Offline game maps: local MBTiles pack import

**Branch:** `feat/offline-vector-mbtiles-packs`  
**Base:** `main` after PR #7 squash merge `54d887fb`.

## What this phase actually does

- Import a **user-provided, licensed, OpenMapTiles-compatible vector MBTiles** archive using the native iOS/Android file picker. Each file is copied in chunks to app support; a 1 GiB local import cap reduces accidental storage exhaustion.
- Verify the SQLite file signature, MBTiles schema and metadata format (PBF/MVT) before it is offered as a pack.
- Preserve an index and explicit active-pack selection in `LocalStore` / SharedPreferences; allow switching back online, and deleting imported archives.
- Substitute the local MBTiles tile provider for the `openmaptiles` source in the already-bundled Adventure RPG and Night Trek styles. Theme selector, route lines and Digital Rope overlays are unchanged.
- Show the pack's attribution and warn when the selected region does not cover the device location.

**Limitations:** This is an **import feature, not an in-app region downloader**. No pack is shipped, and nothing is guaranteed offline until a compatible pack is installed and activated. Missing regions/zoom levels will be blank; web browsers do not support this native MBTiles mode. Route planning, search, GPS and BLE have separate connectivity and platform constraints. UI/device testing is still outstanding.

## Files and changed-line locations

| File | Change |
| --- | --- |
| `lib/features/maps/offline_vector_packs.dart` | **New L1–end:** local pack model, validation, streaming import, persistent selection/deletion |
| `lib/features/maps/offline_vector_pack_section.dart` | **New L1–end:** import, selection, deletion and status in Offline Maps screen |
| `lib/features/maps/explore_game_map.dart` | **Modified imports, style loading and attribution:** swap the `openmaptiles` source for selected MBTiles, unchanged marker layers |
| `lib/features/maps/offline_maps_screen.dart` | **Modified imports, children + description:** separate offline game pack section from legacy raster download flow |
| `pubspec.yaml` | Added `flutter_map_vector_tiles_mbtiles` and `file_picker` |
| `test/offline_vector_packs_test.dart` | **New L1–end:** header validation, metadata serialization, selection persistence, corrupt index recovery |
| `README.md`, `changes.md` | Daily milestone, pending backlog, limitations and audit trail |

## Provider policy / risk review

- Public OpenStreetMap raster tiles must not be bulk-downloaded for offline packs; this PR does not expand that flow.
- OpenFreeMap's terms effective **14 Oct 2026** allow per-download limits of **3,000 tiles or 50 MB** and at most **4 parallel requests**, with a distinct app User-Agent: https://openfreemap.org/tos/. No such automatic download exists in this PR.
- Import only map packs whose redistribution and attribution terms you are authorized to use. Keep the archive's original attribution visible.
- Do not merge without Flutter tests, Android debug APK and unsigned iOS compile; physical phones must also verify file picker, SQLite native hook, airplane mode, map coverage, labels and resource usage before a production promise.

## Next after this PR

1. Validate a real Thrissur MBTiles archive for Athirappilly, Vazhachal and Chimmony; create the archive from authorized data or a compatible permitted source.
2. Add an in-app small-area region-pack downloader/manifest with tile count and byte limits, checksums, cancellation and explicit licence/source choice.
3. Test iPhone-to-iPhone/mixed platforms and airplane mode; keep independent navigation as a safety requirement.
