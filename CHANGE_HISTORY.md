# Trailseek — Change History (GitHub pushes)

> **One place to review changes.** This file records which code files changed, the purpose, changed line locations, test results, and source commit/PR links. Most recent merged changes are first.
>
> **How to read line numbers:** The `L...` ranges below refer to **new-side changed lines in that pull request's merged revision**, not permanent line numbers. Subsequent commits can shift positions. `~L...` indicates a deleted-only location in the PR diff. Open the linked PR **Files changed** tab to see exact additions and deletions; click the pinned commit file to inspect code as it existed on merge.
>
> **Updating policy:** On each **future push I make** to Trailseek, update this history alongside the code, including new/modified file names, changed lines, summary, test status and commit/PR references. Pushes made by other people are not captured automatically. Do not record untested code as field-tested.

## Latest status

| Item | Status | Reference |
| --- | --- | --- |
| Initial Flutter app | On `main` | [Baseline commit](https://github.com/simplyy-shadin/trail-seek-demo/commit/95c72293b5155f3d31533d5c7ee7f9a5802b026f) |
| GPS drift and real elevation fix | Merged into `main` | [PR #1](https://github.com/simplyy-shadin/trail-seek-demo/pull/1) |
| Automatic Bluetooth safety alerts | Merged into `main` | [PR #2](https://github.com/simplyy-shadin/trail-seek-demo/pull/2) |
| Adaptive GPS threshold experiment | Pushed on separate branch; **NOT merged** | [Branch](https://github.com/simplyy-shadin/trail-seek-demo/tree/fix/adaptive-gps-noise-thresholds) |
| Manual SOS/STOP/WAIT multi-hop draft | **Local draft only; NOT pushed** | Not yet part of GitHub |
| Physical BLE / iOS lock-screen field tests | Pending | Automated unit tests are not hardware validation |

## 2026-11-04 — PR #2: Automatic Bluetooth link-safety alerts & multi-hop relay

- **Status:** Merged to `main` on 2026-11-04.
- **Review:** [PR #2 / full diff](https://github.com/simplyy-shadin/trail-seek-demo/pull/2/files) · [Merge commit `3e5a8d9`](https://github.com/simplyy-shadin/trail-seek-demo/commit/3e5a8d99d186b7c737625d41eb29eb1ade0dd6c0) · [Passing GitHub Actions CI](https://github.com/simplyy-shadin/trail-seek-demo/actions/runs/41823565084).
- **Scope:** 10 changed files. Flutter analysis and automated tests passed. **Physical device/forest tests are not yet done.**

| Code file (pinned to merge revision) | Changed lines (PR new side) | What changed |
| --- | --- | --- |
| [`.github/workflows/ios.yml`](https://github.com/simplyy-shadin/trail-seek-demo/blob/3e5a8d99d186b7c737625d41eb29eb1ade0dd6c0/.github/workflows/ios.yml) | `L36-L37` | Focused analyzer + relay regression test commands; full suite retained. |
| [`lib/features/rope/engine/rope_config.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/3e5a8d99d186b7c737625d41eb29eb1ade0dd6c0/lib/features/rope/engine/rope_config.dart) | `L12, L30-L33` | Configurable RSSI jitter multiplier added. |
| [`lib/features/rope/engine/rope_engine.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/3e5a8d99d186b7c737625d41eb29eb1ade0dd6c0/lib/features/rope/engine/rope_engine.dart) | `L2, L94, L107, L116, L155-L172` | Adaptive signal-drop threshold and recovery hysteresis. |
| [`lib/features/rope/links/ble_peer_link.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/3e5a8d99d186b7c737625d41eb29eb1ade0dd6c0/lib/features/rope/links/ble_peer_link.dart) | `L15, L85-L86, L145-L164, L214, L274, L321, L330-L332, L388-L399, L443-L448, L468-L482, L577-L585, L687` | Safety event stream, BLE beacon path, GATT forwarding, deduplication and peer sync integration. |
| [`lib/features/rope/links/rope_packet.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/3e5a8d99d186b7c737625d41eb29eb1ade0dd6c0/lib/features/rope/links/rope_packet.dart) | `L4-L5, L25-L26, L46-L50, L62-L63, L65-L66, L78-L79, L84, L89-L90` | Early-warning bits added to compact heartbeat encoding/decoding. |
| [`lib/features/rope/links/rope_safety_relay.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/3e5a8d99d186b7c737625d41eb29eb1ade0dd6c0/lib/features/rope/links/rope_safety_relay.dart) | `L1-L140` | NEW: safety event format, identifiers, TTL, max hops, bounded forwarding store. |
| [`lib/features/rope/rope_alerts.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/3e5a8d99d186b7c737625d41eb29eb1ade0dd6c0/lib/features/rope/rope_alerts.dart) | `L15-L17, L75-L87, L91, L97-L98, L117-L118, L164` | Weak-link vibration, duplicate cooldown, recovery notification, notification behavior. |
| [`lib/features/rope/rope_controller.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/3e5a8d99d186b7c737625d41eb29eb1ade0dd6c0/lib/features/rope/rope_controller.dart) | `L18, L245-L263, L414-L430` | Detect and broadcast local state changes; display received multi-hop warnings. |
| [`test/rope_engine_test.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/3e5a8d99d186b7c737625d41eb29eb1ade0dd6c0/test/rope_engine_test.dart) | `L102-L134` | Regression tests for noisy RSSI trends and multi-heartbeat recovery. |
| [`test/rope_safety_relay_test.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/3e5a8d99d186b7c737625d41eb29eb1ade0dd6c0/test/rope_safety_relay_test.dart) | `L1-L98` | NEW: 10-phone simulated relay, packet round-trip, duplicate/expiry/recovery tests. |

## 2026-11-04 — PR #1: GPS indoor drift filtering & measured Group Trek stats

- **Status:** Merged to `main` on 2026-11-04.
- **Review:** [PR #1 / full diff](https://github.com/simplyy-shadin/trail-seek-demo/pull/1/files) · [Merge commit `3e7eb42`](https://github.com/simplyy-shadin/trail-seek-demo/commit/3e7eb423fae946029682bc2d906ba274ddf130e3) · [Passing GitHub Actions CI](https://github.com/simplyy-shadin/trail-seek-demo/actions/runs/41819178835).
- **Scope:** 6 changed files. Flutter analysis and automated tests passed. **Physical device/forest tests are not yet done.**

| Code file (pinned to merge revision) | Changed lines (PR new side) | What changed |
| --- | --- | --- |
| [`.github/workflows/ios.yml`](https://github.com/simplyy-shadin/trail-seek-demo/blob/3e7eb423fae946029682bc2d906ba274ddf130e3/.github/workflows/ios.yml) | `L18-L19, L21, L25-L39, L41` | Added pull-request Flutter analysis and regression/full-test CI jobs. |
| [`lib/features/rope/live_tracking_screen.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/3e7eb423fae946029682bc2d906ba274ddf130e3/lib/features/rope/live_tracking_screen.dart) | `L279` | Unknown real altitude displays — instead of a fabricated number. |
| [`lib/features/rope/rope_controller.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/3e7eb423fae946029682bc2d906ba274ddf130e3/lib/features/rope/rope_controller.dart) | `L39, L60, L83-L86, L103, L119, L138, L160, L332-L337, L339-L354, L362-L364, L446-L447, L478, L481, L518, ~L331 (deletion)` | Group GPS uses validated TrackRecorder; rejects jumps and uses measured distance/elevation. |
| [`lib/features/tracking/track_recorder.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/3e7eb423fae946029682bc2d906ba274ddf130e3/lib/features/tracking/track_recorder.dart) | `L54-L56, L58-L59, L68-L72, L84, L99-L102, L119-L136, L138-L140, L181, L196` | Coordinate validation; accuracy-aware stationary/noise filter; ignore counter; altitude median tuning. |
| [`test/booking_test.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/3e7eb423fae946029682bc2d906ba274ddf130e3/test/booking_test.dart) | `L52` | Replaced expired fixed booking fixture date with a future-relative date. |
| [`test/track_recorder_test.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/3e7eb423fae946029682bc2d906ba274ddf130e3/test/track_recorder_test.dart) | `L47, L77-L78, L91-L137, L146` | New indoor stationary, resumed movement and serialization regression coverage. |

## 2026-11-04 — Initial repository import

- **Status:** `main` initial baseline (the uploaded Flutter/Dart project; Android and iOS source).
- **Commit:** [`95c7229` — Initial Trailseek app baseline](https://github.com/simplyy-shadin/trail-seek-demo/commit/95c72293b5155f3d31533d5c7ee7f9a5802b026f).
- **Lines:** An initial import adds entire files, so individual lines were not manually edited within this commit. Use the commit's file diff for the imported source tree.

## Other pushed code not on main

### GPS adaptive threshold experiment — unmerged branch

- **Branch:** [`fix/adaptive-gps-noise-thresholds`](https://github.com/simplyy-shadin/trail-seek-demo/tree/fix/adaptive-gps-noise-thresholds)
- **Branch head:** [`2795ec7`](https://github.com/simplyy-shadin/trail-seek-demo/commit/2795ec7ee106196e53a0b0b8d49cabbe9cd8bc63).
- **Changed file:** [`lib/features/tracking/track_recorder.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/2795ec7ee106196e53a0b0b8d49cabbe9cd8bc63/lib/features/tracking/track_recorder.dart). Changes the adaptive movement/noise threshold according to consecutive reported movement. For exact changed lines, open the linked commit diff. **Not merged and not represented as a tested `main` feature.**

## Update template for every subsequent push

Copy this section above the existing latest entry, and replace the placeholders **before pushing**:

```markdown
## YYYY-MM-DD — PR #N: Short feature or fix name
- Status: draft / pushed branch / merged into main
- Commit: <SHA and link> | PR: <link>
- Why: <problem and user-visible behavior>
- Changed files and lines:
  - path/to/file.dart — L10-L25, L90-L100 — <exact logic changed>
  - test/example_test.dart — L15-L45 — <test coverage>
- Validation: flutter analyze [pass/fail/not run]; flutter test [pass/fail/not run]
- Device/field tests: pending / passed with device details
- Known limitations / follow-up: <notes>
```

**Rule:** Do not merge or mark field reliability as proven solely because a Dart simulation passes. Preserve the relevant PR/commit links so line ranges remain verifiable as source files evolve.
