# 2026-11-12 — PR #9: bounded vector region downloads

**Branch:** `feat/bounded-offline-vector-region-download`; based on `main` after [PR #8](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/8) squash merge `25772c4`.

## Implemented

- Downloads a user-confirmed **3 km-radius** map around a destination from the bundled Thrissur programme data; zoom levels 12–16.
- Uses the documented OpenFreeMap vector endpoint `/planet/latest/{z}/{x}/{y}.pbf`, not the public OpenStreetMap raster tile server.
- Enforces the OpenFreeMap offline-download policy: **no more than 3,000 tiles and 50,000,000 bytes per download**, a single network request at a time (below the four-request cap), and `Trailseek/0.6.1` User-Agent. Per-tile cap 2 MB, timeout and HTTP status checks.
- Generates a local SQLite **MBTiles** archive with `metadata` and `tiles` tables, TMS row conversion, PBF format and data attribution. An error or cancellation removes the partial file.
- Installs the resulting MBTiles as a regular selectable Trailseek offline vector pack, automatically switches to it, and uses Adventure RPG / Night Trek styles without changes to the recorded routes or Digital Rope alerts.
- Disables the previous user-facing **public-OSM raster bulk-download action**, pending a separately licensed source.
- Adds tests that use fake tile data and SQLite (without downloading public tiles).

## Files changed and line ranges

| File | Changed lines / meaning |
| --- | --- |
| `lib/features/maps/offline_vector_region_download.dart` | New L1–end: limits, URL, XYZ/TMS tile geometry, HTTP streaming, MBTiles writing, progress/cancel/state |
| `lib/features/maps/offline_vector_region_section.dart` | New L1–end: destination picker, estimated count, explicit confirmation, progress/cancel |
| `lib/features/maps/offline_vector_packs.dart` | Modified: new `installGeneratedPack` method to adopt locally generated archives and persist pack metadata |
| `lib/features/maps/offline_maps_screen.dart` | Modified imports and Offline Maps screen: new section, disable raster bulk-download entry point |
| `pubspec.yaml` | Added direct `sqlite3: ^3.5.2` dependency |
| `test/offline_vector_region_download_test.dart` | New L1–end: plan, provider URL, MBTiles TMS row, SQLite content and cancellation tests |
| `README.md` and `changes.md` | Daily tracker, pending field work, new feature and validation log |
| `docs/change-notes/2026-11-12-bounded-vector-region-download.md` | This feature note |

## Verified limits and unfinished work

- Provider source: OpenFreeMap TOS (updated 14 Oct 2026): https://openfreemap.org/tos/. Their terms permit offline downloads up to 3,000 tiles or 50 MB, no more than four parallel requests and an identifying User-Agent. This code enforces **both** size/count caps and downloads sequentially.
- Source URL: https://github.com/hyperknot/openfreemap/blob/main/README.md confirms `/planet/latest/{z}/{x}/{y}.pbf`.
- This is a **small-area pack**, not complete forest navigation coverage. Missing tiles or areas outside the selected bounding box may be empty. The center is a destination reference point, not an officially verified trail trace.
- The library's SQLite writes are synchronous and currently run on the calling isolate; **device tests must evaluate UI responsiveness** during a lengthy download before production use.
- The current implementation is intentionally conservative: no multi-region background download scheduling, no unlimited full-area scraping and no unrestricted arbitrary source URLs.
- CI must pass Flutter `pub get`, analyzer + tests, Android APK and iOS unsigned compilation. Device tests must check server content, pack labels, route overlays, map appearance, airplane mode, storage cost, cancellation and battery.
- Existing GPS/SmartTrace/Digital Rope engines are unchanged.
- A definitive signed build, on-device archive validation, long-trek accuracy and BLE safety reliability remain outside scope.
