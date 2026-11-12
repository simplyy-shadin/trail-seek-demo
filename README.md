# Trailseek — Kerala Adventure Platform

**One Kerala. Every Adventure. One App.**  
Discover Kerala adventures, plan a trip, record actual journeys, share achievements, and stay aware of group members with **Digital Rope**, an experimental phone-to-phone Bluetooth safety companion.

> **Project status (updated 12 November 2026):** Active Flutter app under development. Code and CI success do **not** establish reliable forest GPS, background BLE mesh operation, real-device navigation performance, or emergency-alert delivery.

## Today — Thursday, 12 November 2026

This is the **working to-do list**, not a list of completed functionality. Tick items only after evidence is recorded, and roll unfinished items into the next dated update.

- [x] **Review and merge [PR #6](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/6)** — Adventure RPG and Night Trek Explore map styles. Flutter tests, Android debug APK and unsigned iOS compilation passed; squash merged as [`85a107c`](https://github.com/simplyy-shadin/trailseek-adventure-platform/commit/85a107cc5f4df0831e1929479f92f7cc33500c5b). **Real-device rendering remains untested.**
- [x] **Create [PR #7](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/7)** — share game-themed maps across Explore, Solo Tracking, Digital Rope and Activity Summary; preserve the route and safety overlays. Open as **draft**, not merged.
- [x] **Run Flutter analysis and automated tests for PR #7** — [CI run](https://github.com/simplyy-shadin/trailseek-adventure-platform/actions/runs/43216910789) succeeded.
- [x] **Verify PR #7 native builds** — [Android debug APK and unsigned iOS compilation](https://github.com/simplyy-shadin/trailseek-adventure-platform/actions/runs/43216910777) both **passed**. App installation, visual rendering and runtime behavior still require device checks.
- [ ] **Verify Adventure RPG and Night Trek on physical iPhone and Android** — confirm roads/trails align with GPS and destination pins; verify labels, attribution, camera stability and theme persistence.
- [ ] **Review PR #7 on devices before merge** — during Solo Tracking and Digital Rope sessions, confirm route lines, current/remote positions, weak-connection banners and SOS actions are never hidden by map styling. CI is green; hardware acceptance and merge remain pending.
- [ ] **Document offline map source/provider decision** — use approved providers or properly licensed/self-hosted data; no bulk offline downloading from the public OSM raster tile service.

## Current status at a glance

| Area | Repository / CI status | Still unverified or incomplete |
| --- | --- | --- |
| Game maps in Explore | **Merged in PR #6**: Adventure RPG, Night Trek, Classic fallback; vector map styles | Real-device cartography, performance, offline behavior |
| Game maps across journeys | **PR #7 draft**: themes on Solo Tracking, Digital Rope and saved activity maps; automated tests + both platform builds passed | Manual map/GPS/BLE overlay testing and merge |
| Solo GPS / SmartTrace | Tracking, adaptive sampling/filtering and saved routes exist in code; previous CI passed | Trail curvature, indoor/forest accuracy, stopping lifecycle and battery **field** measurements |
| Digital Rope BLE | Group safety engine, BLE transport, route markers and warnings are implemented in code | iOS locked/background behavior, multi-hop reliability, mixed iPhone/Android groups, alert latency and real battery use |
| Offline maps | Raster tile cache and per-adventure download UI exist | Source licensing/provider, guaranteed offline **vector** map packs, airplane-mode coverage |
| Explorer experience | Discovery, adventure history, XP, badges, certificates/share-oriented flows are in progress | Content verification, end-to-end workflows and real user QA |
| Backend / releases | Supabase-related code and GitHub CI/build workflows present | Production auth/sync security review, complete device distribution, signed builds and closed beta readiness |

**Status terms:** *Merged* means code is on `main`; *CI passed* means automated checks passed; *field-tested* requires evidence from real devices. Do not treat any one of these as proof of the other two.

## Pending — prioritized backlog

| Priority | Task | Completion evidence |
| --- | --- | --- |
| **P0** | Review PR #7 (CI green) and validate on-device map and overlays before merge | iPhone/Android screenshots or test notes, zero map-related safety regressions |
| **P0** | Digital Rope field testing: iPhone↔iPhone, iPhone↔Android, Android↔Android, multi-hop, reconnection, locked-screen and weak-link alerts | Measured delays, false alerts, group reachability, battery and documented platform limitations |
| **P0** | GPS SmartTrace real-world validation in forests, switchbacks, indoor/poor-GNSS areas, and start/pause/stop | Comparison with walked path and recorded accuracy, observed battery and lifecycle behavior |
| **P1** | Authorized **offline vector maps** and style assets for Athirappilly, Vazhachal and Chimmony | Download, restart, offline/airplane-mode navigation and licensing checks |
| **P1** | Map polish: readable trails/labels, theme iconography, fallback and low-power performance | Screenshots and profile results on both platforms |
| **P1** | Backend/auth, community sync, guide/booking access controls and privacy/security review | End-to-end tests and security checks rather than stub/demo behavior |
| **P1** | Thrissur pilot destination data, access rules, permissions, guide and program information | Verified source-backed entries; unverified items remain labelled |
| **P2** | More game themes, Fog of War, adventure unlocks and explorer passport enhancements | Product review, working prototypes, UX/device validation |
| **P2** | Release readiness: signed builds, device distribution, app-store requirements, monitoring and beta QA | Repeatable release checklist, tester feedback, launch decision |

**Pilot geography:** Thrissur district — **Athirappilly, Vazhachal, Chimmony**.

## Recent milestones and pull requests

| Date | Change | Status |
| --- | --- | --- |
| **12 Nov 2026** | [PR #7 — shared game maps](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/7) | **Open draft**; Flutter tests, Android APK and iOS compile passed; device review pending |
| **12 Nov 2026** | [PR #6 — game-themed Explore maps](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/6) | **Merged**; CI passed; physical-device verification pending |
| **10 Nov 2026** | [PR #5 — imported changes + SmartTrace/BLE safeguards](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/5) | **Merged**; CI passed; field performance unverified |

See [`changes.md`](changes.md), [`CHANGE_HISTORY.md`](CHANGE_HISTORY.md) and [`docs/change-notes/`](docs/change-notes/) for more detailed changes, known limits and file-level references.

## Stack and developer setup

- **Flutter / Dart** (`pubspec.yaml` declares app version **0.6.1+28**), Riverpod and go_router.
- **Maps:** `flutter_map`, OpenStreetMap-linked raster sources, `flutter_map_vector_tiles`, MapLibre-style JSON, OpenFreeMap-hosted vector data. Some online and offline sources have separate attribution and use limits.
- **GPS:** geolocator and in-app tracking/filtering logic.
- **Group safety:** Bluetooth Low Energy; iOS/Android background restrictions apply.
- **Data:** local stores and Supabase integrations; production security and release readiness require validation.

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Build checks: [GitHub Actions](https://github.com/simplyy-shadin/trailseek-adventure-platform/actions). `flutter build apk --debug` creates an Android debug APK; unsigned iOS compilation requires macOS/Xcode and does not produce an App Store-ready signed release.

### Product and technical references

- [Technical plan](PLAN.md)
- [Task board](tasks/README.md) — historical task files may contain older snapshots; use **this README's dated status** for the current work plan.
- [MVP launch plan](docs/MVP_Product_Launch_Plan.pdf)
- [Design and brand assets](docs/brand/)

## Required upkeep — every PR, every workday

**From 12 November 2026 onward, this README is the source of truth for current work and pending tasks.**

1. **Before opening/updating a PR:** update **Today** (date, completed actions, active work) and **Pending** (new work, priorities, blockers). Distinguish proposed, committed, merged, CI-passed and device-tested.
2. **For every code change:** update [`changes.md`](changes.md) with date, PR/branch, affected files/lines, verification and limitations; add a detailed note in `docs/change-notes/` for multi-file features.
3. **When CI or hardware testing changes a result:** replace the old status, cite the relevant Actions run or field-test evidence, and keep blockers explicit.
4. **After a PR merges:** move its status to *merged*, link the commit, remove completed items from the active to-do section, and carry unfinished checks forward.
5. **Before ending a work session:** confirm the README accurately lists what is done **today**, what is **in progress**, and what is **pending next**. Use the [PR checklist](.github/pull_request_template.md) for consistency.

## Safety and reliability notice

Trailseek's Digital Rope and navigation are **experimental companion features** during development, **not primary emergency or navigation equipment**. Use independent offline maps, guides, manual headcounts and normal rescue procedures. GPS uncertainty, forest obstructions, Bluetooth signal variability and iOS background/critical-alert restrictions cannot be eliminated by visual styling or by passing CI.
