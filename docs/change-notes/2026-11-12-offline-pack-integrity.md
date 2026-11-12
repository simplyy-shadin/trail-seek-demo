# 2026-11-12 — Offline map file verification and coverage clarity

**Branch:** `fix/offline-map-pack-integrity-coverage` (PR #10 planned).  
**Base:** `main` after PR #9 squash merge `a8f897e`.

## Purpose

Avoid presenting a missing, damaged, empty or geographically limited offline archive as dependable navigation data. This is a **file-validation and transparency step**, not a proof that a trek is safely navigable offline.

## Changes by file

| File | Scope / line references |
| --- | --- |
| `lib/features/maps/offline_vector_pack_audit.dart` | **New L1–end:** parse MBTiles bounds, run SQLite `PRAGMA quick_check(1)`, validate PBF/MVT metadata, tile presence and zoom range using an isolated Dart worker so the UI stays responsive |
| `lib/features/maps/offline_vector_pack_section.dart` | **Modified imports, new verify method, pack actions:** an explicit Verify button shows the archive's structural status, declared bounding box and zoom range. Reassures *only* about file structure, not complete trail coverage |
| `lib/features/maps/offline_vector_packs.dart` | **Changed `select`:** refuse to activate a pack whose file has been deleted or moved, with an actionable exception |
| `lib/features/maps/offline_vector_region_download.dart` | **Changed MBTiles writer commit/cleanup:** remove a partial file whenever the database never successfully committed, including failures after the final tile |
| `test/offline_vector_pack_audit_test.dart` | **New L1–end:** valid/invalid bounds, missing files, corrupt SQLite, empty tiles, valid MBTiles structure |
| `test/offline_vector_region_download_test.dart` | **Added late-error case:** no archive survives failure after writing the last tile |
| `test/offline_vector_packs_test.dart` | **Added missing-file activation case** |
| `README.md`, `changes.md` | Update daily work, pending tasks, linked PR status and test limits |

## Review and acceptance

- [ ] Flutter analysis and tests green
- [ ] Android debug APK and iOS unsigned compilation green
- [ ] Verify action works on both physical platforms, including corrupt, missing and large files
- [ ] Confirm archive bounds and actual map coverage in airplane mode at Thrissur pilot sites
- [ ] Measure audit duration/battery and ensure Digital Rope controls remain responsive

**Known limitations:** SQLite `quick_check` proves internal database consistency, **not** that map features are accurate, current, georeferenced as claimed or complete. Bounds are publisher-supplied metadata. Some vector tile layers or labels may still be missing offline. Audits run only when selected by the user; this does not continuously monitor file health. GPS, BLE messaging, SOS and notifications are unmodified.

**Background:** PR #9 merged in `a8f897e`; OpenFreeMap's 3,000-tile/50 MB rules remain unchanged: https://openfreemap.org/tos/
