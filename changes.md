# Trailseek — Changes

## 2026-11-12 — Shared game maps across journey screens (new feature PR)

- Unified Adventure RPG, Night Trek and Classic selections across Explore, Solo Tracking, Digital Rope and the saved-activity route preview.
- Added reusable theme sheet, Classic Satellite/Standard/Terrain choices and two regression widget tests; route lines, member markers, GPS and BLE safety logic untouched.
- New files: `lib/features/maps/map_theme_picker.dart`, `test/map_theme_picker_test.dart`, `docs/change-notes/2026-11-12-shared-game-maps.md`.
- Updated: `lib/features/maps/{explore_game_map,map_tiles}.dart`, `lib/features/{explore/map_tab,tracking/tracking_screen,rope/live_tracking_screen,activity/activity_summary_screen}.dart`, `changes.md`.
- **Verification:** pending new PR CI and device tests; vector tile offline pre-download still out of scope.


## 2026-11-12 — Explore game-themed maps (feature PR)

- Added Adventure RPG + Night Trek geographic vector basemaps and a persisted theme picker in Explore; Classic remains default and fallback.
- New files: `assets/maps/styles/{adventure_rpg,night_trek}.json`, `lib/features/maps/explore_game_map.dart`, `test/explore_game_map_test.dart`, `docs/change-notes/2026-11-12-game-map-themes.md`.
- Updated: `lib/features/explore/map_tab.dart`, `pubspec.yaml`, `android/settings.gradle.kts`, `changes.md`. No edits to GPS tracking or Digital Rope.
- **Build compatibility:** bumped Android Gradle Plugin 9.1.0 → 9.1.1 after CI reported Flutter's newer minimum; the existing Gradle wrapper was already compatible.
- **Validation:** pending GitHub Actions; not field-tested. Detailed scope/line references in `docs/change-notes/2026-11-12-game-map-themes.md`.


## 2026-11-10 — PR #5 merged into `main`

- **Pull request:** https://github.com/simplyy-shadin/trail-seek-demo/pull/5
- **Squash merge:** [`91c9b20c`](https://github.com/simplyy-shadin/trail-seek-demo/commit/91c9b20cdae195983324d37fad2fdbdfb87b06a2)
- **Merged source changes:** 52 files (15 additions, 37 modifications); PR #5 includes the uploaded ZIP changes and follow-up SmartTrace improvements. The standalone `changes.md` file and `CHANGE_HISTORY.md` are updated separately after merge.
- **PR source commits:** `1848ab8` (ZIP import + BLE/GPS safeguards), `d6e26f6` (SmartTrace battery-balanced GPS).
- **Validation at final PR head `d6e26f6`:** Flutter analysis/test workflow **passed** (https://github.com/simplyy-shadin/trail-seek-demo/actions/runs/42795276685); Android debug APK and unsigned iOS compilation **passed** (https://github.com/simplyy-shadin/trail-seek-demo/actions/runs/42795276526). The SDK/device power/accuracy measurements were not performed locally.
- **Field testing:** **PENDING.** Do not represent BLE multi-hop, critical alerts, iPhone silent-mode bypass, exact distance measurements, GPS indoor path, or battery savings as proven.

### User-visible changes

1. **Group trail recording and sharing:** encrypted multi-hop breadcrumb pages, per-member stored tracks, group route lines and route summary improvements; new trail-learning modules produce candidate shared walking paths.
2. **Bluetooth safety improvements:** prioritizes urgent SOS/safety traffic over optional trail transfer, enhances BLE operation serialization/background recovery, optional faster *field-test* thresholds, conservative GPS-spacing advisories and lower notification/haptic sequencing latency.
3. **GPS and battery controls:** restartable reference-counted native location stream; 2-second Android GPS request with 2-metre filter and without an explicit CPU wake lock; iOS best-accuracy 3-metre filter during active tracking; stationary live marker anchored to accepted positions; better small-turn sampling when GNSS reports <=6m accuracy.
4. **Other app work:** changes to group lobby, activity summary, home, discovery, community, profile, navigation, Supabase schema and web public documents.
5. **Tests:** group breadcrumb, trail learner, trail store, distance safety monitor, GPS lifecycle and recorder regression coverage.

### Limits and follow-up

- Built-in GNSS works without cellular internet, but **indoor/forest precision cannot be guaranteed**; 2.5m acceptance only applies with sufficiently good GNSS, not generally.
- **BLE RSSI is not a reliable metre-scale ranging device**; group spacing uses estimated GPS distance with age/uncertainty constraints, not a missing-person verdict. No mandatory SOS fires solely because of a GPS gap.
- iPhone locked-screen BLE delivery and silent-mode audible alerts are constrained by iOS. Critical Alerts require Apple entitlement and user permission; no such bypass is claimed.
- iPhone-to-iPhone, iPhone-to-Android, Android-to-Android, long-trek battery usage, false-alarm rate and actual SOS latency need device/forest tests.

### Changed source files and changed-line references

New-side PR #5 diff hunk ranges are approximate edit locations (including diff context); additions and deletions are visible in [Files changed](https://github.com/simplyy-shadin/trail-seek-demo/pull/5/files). The ranges refer to the PR's merged revision, not permanent line numbers.

#### GPS / SmartTrace / tracking

| File | PR changed lines |
|---|---|
| [`lib/features/tracking/position_stream.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/tracking/position_stream.dart) | L1–41, L45–55 |
| [`lib/features/tracking/ref_counted_broadcast_stream.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/tracking/ref_counted_broadcast_stream.dart) | L1–62 |
| [`lib/features/tracking/track_recorder.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/tracking/track_recorder.dart) | L44–78, L82–92, L132–167, L191–198 |
| [`lib/features/tracking/tracking_controller.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/tracking/tracking_controller.dart) | L10–17, L184–194, L200–208, L272–283 |
| [`lib/features/tracking/tracking_screen.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/tracking/tracking_screen.dart) | L10–16, L65–71 |

#### Bluetooth / Digital Rope / group route

| File | PR changed lines |
|---|---|
| [`lib/features/group/lobby_screen.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/group/lobby_screen.dart) | L14–20, L186–192, L196–202 |
| [`lib/features/group/lobby_sync.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/group/lobby_sync.dart) | L120–128 |
| [`lib/features/rope/engine/distance_safety_monitor.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/rope/engine/distance_safety_monitor.dart) | L1–98 |
| [`lib/features/rope/engine/rope_config.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/rope/engine/rope_config.dart) | L49–66 |
| [`lib/features/rope/group_trails.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/rope/group_trails.dart) | L1–75 |
| [`lib/features/rope/links/ble_peer_link.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/rope/links/ble_peer_link.dart) | L3–9, L16–22, L43–49, L60–68, L79–90, L117–136, L148–161, L172–191, L207–216, L247–278, L300–310, L313–324, L331–354, L363–371, L380–393, L396–409, L424–437, L461–485, L511–517, L548–554, L557–625, L629–642, L678–690, L697–703, L707–742, L752–762, L772–780, L784–797, L805–821, L827–837, L847–875, L880–890, L900–949, L1016–1026 |
| [`lib/features/rope/links/rope_roster.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/rope/links/rope_roster.dart) | L137–149 |
| [`lib/features/rope/links/rope_security.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/rope/links/rope_security.dart) | L15–21, L68–100, L103–109 |
| [`lib/features/rope/links/rope_trail.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/rope/links/rope_trail.dart) | L1–184 |
| [`lib/features/rope/live_tracking_screen.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/rope/live_tracking_screen.dart) | L11–18, L34–54, L91–108, L121–144, L154–186, L286–302, L792–799, L815–821, L853–871, L898–919 |
| [`lib/features/rope/rope_alerts.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/rope/rope_alerts.dart) | L1–5, L74–85, L101–109, L113–148 |
| [`lib/features/rope/rope_controller.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/rope/rope_controller.dart) | L10–32, L164–176, L182–188, L199–225, L262–268, L314–330, L377–390, L398–419, L427–433, L438–469, L578–606, L637–644 |

#### Maps / community trail learning

| File | PR changed lines |
|---|---|
| [`lib/features/activity/activity_summary_screen.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/activity/activity_summary_screen.dart) | L13–19, L41–47, L93–101, L224–247, L255–277, L282–306 |
| [`lib/features/trails/trail_layer.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/trails/trail_layer.dart) | L1–33 |
| [`lib/features/trails/trail_learner.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/trails/trail_learner.dart) | L1–267 |
| [`lib/features/trails/trail_store.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/trails/trail_store.dart) | L1–157 |

#### UI / discovery / community / profile

| File | PR changed lines |
|---|---|
| [`lib/app/links.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/app/links.dart) | L1–14 |
| [`lib/app/router.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/app/router.dart) | L107–122 |
| [`lib/core/widgets/big_cards.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/core/widgets/big_cards.dart) | L127–140 |
| [`lib/core/widgets/ts_bottom_nav.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/core/widgets/ts_bottom_nav.dart) | L30–45 |
| [`lib/features/community/character_sheet_view.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/community/character_sheet_view.dart) | L10–22, L41–57 |
| [`lib/features/community/community_tab.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/community/community_tab.dart) | L10–16, L58–71, L75–84, L123–129, L205–210 |
| [`lib/features/community/explorers.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/community/explorers.dart) | L72–82 |
| [`lib/features/discovery/adventure_detail_screen.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/discovery/adventure_detail_screen.dart) | L3–10, L31–43, L395–408, L416–428, L439–461 |
| [`lib/features/discovery/adventure_list_screen.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/discovery/adventure_list_screen.dart) | L136–142 |
| [`lib/features/explore/explore_tab.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/explore/explore_tab.dart) | L1–4, L55–68 |
| [`lib/features/explore/home_banners.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/explore/home_banners.dart) | L1–42 |
| [`lib/features/profile/profile_tab.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/profile/profile_tab.dart) | L49–55, L85–91 |
| [`lib/features/progress/progress_engine.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/progress/progress_engine.dart) | L27–34 |

#### Platform / security / database / web

| File | PR changed lines |
|---|---|
| [`android/app/src/main/kotlin/com/trailseek/trailseek/MainActivity.kt`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/android/app/src/main/kotlin/com/trailseek/trailseek/MainActivity.kt) | L1–45 |
| [`lib/features/settings/settings_screen.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/lib/features/settings/settings_screen.dart) | L41–56, L81–87 |
| [`pubspec.lock`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/pubspec.lock) | L209–222, L427–480 |
| [`pubspec.yaml`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/pubspec.yaml) | L16–22 |
| [`supabase/schema.sql`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/supabase/schema.sql) | L277–306 |
| [`web/app/layout.tsx`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/web/app/layout.tsx) | L15–25 |
| [`web/public/privacy.html`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/web/public/privacy.html) | L1–12 |
| [`web/public/terms.html`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/web/public/terms.html) | L1–11 |
| [`web/scripts/sync-data.mjs`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/web/scripts/sync-data.mjs) | L18–34 |

#### Tests and documentation

| File | PR changed lines |
|---|---|
| [`CHANGE_HISTORY.md`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/CHANGE_HISTORY.md) | L6–21, L146–185 |
| [`test/app_smoke_test.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/test/app_smoke_test.dart) | L46–65, L83–93, L117–128 |
| [`test/distance_safety_monitor_test.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/test/distance_safety_monitor_test.dart) | L1–56 |
| [`test/links_test.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/test/links_test.dart) | L9–15 |
| [`test/ref_counted_broadcast_stream_test.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/test/ref_counted_broadcast_stream_test.dart) | L1–42 |
| [`test/rope_trail_test.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/test/rope_trail_test.dart) | L1–182 |
| [`test/track_recorder_test.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/test/track_recorder_test.dart) | L2–8, L146–218 |
| [`test/trail_learner_test.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/test/trail_learner_test.dart) | L1–119 |
| [`test/trail_store_test.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/91c9b20cdae195983324d37fad2fdbdfb87b06a2/test/trail_store_test.dart) | L1–56 |

### Documentation policy

Maintain this file for each future feature/fix push, linking the relevant commit/PR, changed files/lines, test status and field-test evidence. Historical detailed PR #1–#4 entries remain in [CHANGE_HISTORY.md](CHANGE_HISTORY.md).
