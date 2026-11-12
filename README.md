# Trailseek — Kerala Adventure Platform

**One Kerala. Every Adventure. One App.**  
Discover Kerala adventures, plan a trip, record actual journeys, share achievements, and stay aware of group members with **Digital Rope**, an experimental phone-to-phone Bluetooth safety companion.

> **Project status (updated 13 November 2026):** Active Flutter app under development. Code and CI success do **not** establish reliable forest GPS, background BLE mesh operation, real-device navigation performance, or emergency-alert delivery.

## Today — Friday, 13 November 2026

This is the **working to-do list**, not a list of completed functionality. Tick items only after evidence is recorded, and roll unfinished items into the next dated update.

- [x] **Review and merge [PR #6](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/6)** — Adventure RPG and Night Trek Explore map styles. Flutter tests, Android debug APK and unsigned iOS compilation passed; squash merged as [`85a107c`](https://github.com/simplyy-shadin/trailseek-adventure-platform/commit/85a107cc5f4df0831e1929479f92f7cc33500c5b). **Real-device rendering remains untested.**
- [x] **Create [PR #7](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/7)** — share game-themed maps across Explore, Solo Tracking, Digital Rope and Activity Summary; preserve the route and safety overlays. **Merged into `main`**, squash commit [`54d887f`](https://github.com/simplyy-shadin/trailseek-adventure-platform/commit/54d887fb39493a080e6a222a2535c683b5f05880).
- [x] **Run Flutter analysis and automated tests for PR #7** — [CI run](https://github.com/simplyy-shadin/trailseek-adventure-platform/actions/runs/43216910789) succeeded.
- [x] **Verify PR #7 native builds** — [Android debug APK and unsigned iOS compilation](https://github.com/simplyy-shadin/trailseek-adventure-platform/actions/runs/43216910777) both **passed**. App installation, visual rendering and runtime behavior still require device checks.
- [ ] **Verify Adventure RPG and Night Trek on physical iPhone and Android** — confirm roads/trails align with GPS and destination pins; verify labels, attribution, camera stability and theme persistence.
- [ ] **Field-test merged PR #7 on devices** — during Solo Tracking and Digital Rope sessions, confirm route lines, current/remote positions, weak-connection banners and SOS actions remain visible. CI passed; hardware acceptance is outstanding.
- [x] **Research offline vector archive support and provider policy** — local MBTiles can supply map vectors without network. OpenFreeMap permits bounded downloads under its current terms; public OSM raster bulk downloads remain prohibited.
- [x] **Merge [PR #8](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/8)** — offline MBTiles import, validation, theme integration and regression tests; Flutter, Android and iOS CI passed. Squash commit [`25772c4`](https://github.com/simplyy-shadin/trailseek-adventure-platform/commit/25772c4609568ae350b2fe852adc47ad6cbbbb95).
- [x] **Merge [PR #9](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/9)** — bounded Thrissur vector-region downloads; Flutter, Android and iOS checks passed. Squash commit [`a8f897e`](https://github.com/simplyy-shadin/trailseek-adventure-platform/commit/a8f897e1ebd7b2ab3928573fd51f8ab328d51960). Device QA remains pending.
- [x] **Merge [PR #10](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/10)** — offline MBTiles audit and declared coverage, missing-file guard, failure cleanup; Flutter/Android/iOS CI passed, merged as [`5c72c8a`](https://github.com/simplyy-shadin/trailseek-adventure-platform/commit/5c72c8a8252a3ea4cc84b982233b3a6668fa5b65). On-device checks pending.
- [x] **Merge [PR #11](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/11)** — opt-in local Fog of War from accepted solo GPS fixes, privacy controls and tests. Flutter, Android and iOS CI passed; squash merged as [`fc8390b`](https://github.com/simplyy-shadin/trailseek-adventure-platform/commit/fc8390b3e5d0b8fab8e6591548431e902b678e7e). Device QA pending.
- [x] **Merge [PR #12](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/12)** — six original game vector worlds + Classic, theme previews, marker colours and tests. Flutter, Android APK and unsigned iOS checks passed; squash commit [`e0991b4`](https://github.com/simplyy-shadin/trailseek-adventure-platform/commit/e0991b47491d0020979264fc7a8053c5614a2776). Device QA pending.
- [x] **Merge [PR #13](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/13)** — recorded solo route-direction chevrons (not navigation), at most 24 markers, cached geometry, saved-route preview and regression tests. Flutter/Android/iOS passed; squash merged as [`f5e20a8`](https://github.com/simplyy-shadin/trailseek-adventure-platform/commit/f5e20a88ec954afe40bc31abb41e1e0ae8f2abed). Device QA pending.
- [ ] **Next: PR #14 themed destination/POI markers** — conservative category icons from verified/visible destination metadata; map collision, accessible labels and map performance checks first.
- [ ] **Field-test the imported offline pack on devices** — after passing Flutter/Android/iOS CI, verify a real licensed MBTiles file, restart and airplane mode on both iPhone and Android.

## Current status at a glance

| Area | Repository / CI status | Still unverified or incomplete |
| --- | --- | --- |
| Game maps in Explore | **PR #12 merged**: six original vector worlds (Adventure RPG, Night Trek, Monsoon Mist, Highland Quest, Coastal Explorer, Canopy Quest) + Classic | iPhone/Android cartographic/label contrast, offline rendering and battery checks |
| Game maps across journeys | **Merged in PR #7**: themed maps on Explore, Solo Tracking, Digital Rope and saved activity; **PR #11 merged**: opt-in Fog of War on Explore + Solo only | Physical-device Fog paint/zoom/pan and GPS/BLE safety overlay verification |
| Solo GPS / SmartTrace | Tracking, adaptive sampling/filtering and saved routes exist; **PR #13 merged** static historical-direction route chevrons with geometry/CI tests | Trail curvature, indoor/forest accuracy, stopping lifecycle, route-map camera rotation and battery **field** measurements |
| Digital Rope BLE | Group safety engine, BLE transport, route markers and warnings are implemented in code | iOS locked/background behavior, multi-hop reliability, mixed iPhone/Android groups, alert latency and real battery use |
| Offline maps | **PRs #8–#10 merged**: MBTiles import, bounded downloads, structural audits and declared coverage; CI green | iPhone/Android airplane-mode and actual coverage/battery tests; audit cannot prove map completeness |
| Explorer experience | Discovery, adventure history, XP, badges, certificates/share-oriented flows are in progress | Content verification, end-to-end workflows and real user QA |
| Backend / releases | Supabase-related code and GitHub CI/build workflows present | Production auth/sync security review, complete device distribution, signed builds and closed beta readiness |

**Status terms:** *Merged* means code is on `main`; *CI passed* means automated checks passed; *field-tested* requires evidence from real devices. Do not treat any one of these as proof of the other two.

## Pending — prioritized backlog

| Priority | Task | Completion evidence |
| --- | --- | --- |
| **P0** | Field-test merged PR #7 game map overlays and fallback on physical devices | iPhone/Android screenshots or test notes, zero map-related safety regressions |
| **P0** | Digital Rope field testing: iPhone↔iPhone, iPhone↔Android, Android↔Android, multi-hop, reconnection, locked-screen and weak-link alerts | Measured delays, false alerts, group reachability, battery and documented platform limitations |
| **P0** | GPS SmartTrace real-world validation in forests, switchbacks, indoor/poor-GNSS areas, and start/pause/stop | Comparison with walked path and recorded accuracy, observed battery and lifecycle behavior |
| **P1** | Validate merged PR #8 using licensed MBTiles pilot files in Athirappilly, Vazhachal and Chimmony | On-device import, persistence/restart, offline coverage, correct attribution and storage measurements |
| **P1** | Field-test merged PR #9 provider-compliant vector region downloader | Actual download, size limit, cancellation, archive coverage and airplane mode on iPhone and Android |
| **P1** | Validate PR #10 merged archive health/coverage audit on physical phones | Large-pack audit responsiveness, missing/corrupted file notices, offline coverage truthfulness |
| **P1** | Map polish: readable trails/labels, theme iconography, fallback and low-power performance | Screenshots and profile results on both platforms |
| **P1** | Backend/auth, community sync, guide/booking access controls and privacy/security review | End-to-end tests and security checks rather than stub/demo behavior |
| **P1** | Thrissur pilot destination data, access rules, permissions, guide and program information | Verified source-backed entries; unverified items remain labelled |
| **P1** | Field-test merged PR #11 Fog of War on iPhone/Android | Local persistence, privacy opt-out/reset, fog repaint alignment and battery QA |
| **P2** | Field-test PR #12 six original game worlds and themed destination pins | Flutter/Android/iOS CI green; physical devices' roads/trails, label contrast, attribution and offline coverage still pending |
| **P2** | Field-test merged PR #13 recorded-direction chevrons on solo and activity maps | Flutter/Android/iOS CI passed; manual camera rotation, path accuracy and battery QA outstanding; not navigation |
| **P2** | Next PR #14 game-themed destination/POI marker icons | Conservative destination metadata mapping, accessibility labels, collision handling, Flutter/native CI and device QA |
| **P2** | Advanced animated icons and live navigation graphics | Design review, map collision control, SOS-safe performance and approved routing sources |
| **P2** | Original exploration enhancements: adventure unlocks, Fog of War rewards, explorer passport and achievement polish | Product review, stored unlock data, UX/device validation |
| **P2** | Turn-by-turn routes, voice guidance, alternate routes and multi-stop planning | Grounded routing provider/license, navigation tests and safety/accuracy evaluation |
| **P2** | Place/landmark/business search and saved map locations | Verified place index, full search, favorites and privacy controls |
| **P3** | Investigate CarPlay, watch companion and home-screen widgets | Platform entitlement/API review, scoped prototypes and device approval tests |
| **P2** | Release readiness: signed builds, device distribution, app-store requirements, monitoring and beta QA | Repeatable release checklist, tester feedback, launch decision |

**Pilot geography:** Thrissur district — **Athirappilly, Vazhachal, Chimmony**.

## MapShifter-inspired game-map TODO — Trailseek's original implementation

This is a **feature-comparison backlog**, not a claim of copying another product's proprietary graphics or code. Distinguish existing map themes from advanced navigation features, and never imply navigation reliability from CI alone.

- [x] **Classic / Adventure RPG / Night Trek selectable basemaps** — PRs #6–#7, theme selection applies to Explore, tracking, Digital Rope and activity previews; device polish pending.
- [x] **Initial offline vector map packs** — PRs #8–#10; local MBTiles import, bounded download and file-health checks merged, device tests pending.
- [x] **Fog of War / explored terrain — PR #11 merged** — opt-in local-only reveal from accepted solo GPS fixes, reset/history controls, no extra GPS, group safety map untouched; phone tests pending.
- [x] **At least six original game-world styles — PR #12 merged** — six vector styles (four new worlds beyond Adventure RPG/Night Trek), Classic separate. Flutter/Android/iOS CI passed, physical offline/contrast QA pending.
- [x] **Historic route-direction chevrons — PR #13 merged** — solo/saved routes only, capped/static/cached; Flutter/Android/iOS CI passed; map rotation and battery device QA pending.
- [ ] **Game-inspired POI markers and route animations — PR #14 next** — map destination categories and accessible marker designs; animated navigation still pending; group SOS map remains untouched.
- [ ] **Turn-by-turn directions and voice guidance** — licensed routing and voice/navigation flow; not yet implemented.
- [ ] **Alternate route suggestions and multi-stop trip planning** — source-verified routing and trail permission checks.
- [ ] **Full places / restaurants / landmarks search and favorites** — distinguish verified Trailseek adventures from general POI data.
- [ ] **Exploration rewards, Fog of War achievements and explorer-passport polish** — build on existing XP/badges/certificates, not claim full parity.
- [ ] **CarPlay, Apple Watch and home-screen widget feasibility** — platform entitlement and battery review before development.

**Physical-test gates remain open:** iPhone↔Android Digital Rope alerts, SmartTrace GPS curve/indoor/forest accuracy, offline map coverage, voice/SOS sound restrictions and battery budgets.

## Recent milestones and pull requests

| Date | Change | Status |
| --- | --- | --- |
| **13 Nov 2026** | PR #14 — contextual destination/POI marker icons | **Next planned milestone**; design and CI not started |
| **13 Nov 2026** | [PR #13 — recorded-route direction chevrons](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/13) | **Merged** (`f5e20a8`); Flutter/Android/iOS CI passed, device QA pending |
| **13 Nov 2026** | [PR #12 — six game worlds](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/12) | **Merged** (`e0991b4`); Flutter/Android/iOS checks passed, device QA pending |
| **13 Nov 2026** | [PR #11 — opt-in Fog of War](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/11) | **Merged** (`fc8390b`); Flutter/Android/iOS CI passed, hardware QA pending |
| **12 Nov 2026** | [PR #10 — offline MBTiles integrity and coverage](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/10) | **Merged** (`5c72c8a`); Flutter/Android/iOS CI passed, device QA pending |
| **12 Nov 2026** | [PR #9 — bounded vector region downloads](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/9) | **Merged** (`a8f897e`); Flutter/Android/iOS checks passed, device QA pending |
| **12 Nov 2026** | [PR #8 — offline MBTiles pack import](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/8) | **Merged** (`25772c4`); Flutter/Android/iOS CI passed; device validation pending |
| **12 Nov 2026** | [PR #7 — shared game maps](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/7) | **Merged** (`54d887f`); Flutter tests, Android APK and iOS compile passed; device review pending |
| **12 Nov 2026** | [PR #6 — game-themed Explore maps](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/6) | **Merged**; CI passed; physical-device verification pending |
| **10 Nov 2026** | [PR #5 — imported changes + SmartTrace/BLE safeguards](https://github.com/simplyy-shadin/trailseek-adventure-platform/pull/5) | **Merged**; CI passed; field performance unverified |

See [`changes.md`](changes.md), [`CHANGE_HISTORY.md`](CHANGE_HISTORY.md) and [`docs/change-notes/`](docs/change-notes/) for more detailed changes, known limits and file-level references.

## Stack and developer setup

- **Flutter / Dart** (`pubspec.yaml` declares app version **0.6.1+28**), Riverpod and go_router.
- **Maps:** `flutter_map`, OpenStreetMap-linked raster sources, `flutter_map_vector_tiles`, MapLibre-style JSON and OpenFreeMap-hosted vector data. PRs #8–#10 merged MBTiles import, small-region downloads, SQLite audit and attribution; device/offline coverage remains unverified.
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
