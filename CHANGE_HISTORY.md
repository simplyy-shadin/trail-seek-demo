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
| Manual SOS/STOP/WAIT multi-hop fix | **Merged into `main`; automated checks passed** | [PR #3](https://github.com/simplyy-shadin/trail-seek-demo/pull/3) |
| BLE group authentication & privacy | Draft PR #4; not merged | [PR #4](https://github.com/simplyy-shadin/trail-seek-demo/pull/4) |
| Physical BLE / iOS lock-screen field tests | Pending | Automated unit tests are not hardware validation |

## 2026-11-04 — PR #4: BLE group authentication & encrypted GPS roster

- **Status:** Pushed to `fix/ble-group-auth-and-roster-privacy`; [draft PR #4](https://github.com/simplyy-shadin/trail-seek-demo/pull/4). **NOT merged into `main`.**
- **Why:** Nearby unknown devices could access an unauthenticated GATT roster containing GPS/member data, attempt unauthorized joins and send forged safety messages.
- **What changed:** Secure random 256-bit group credentials via private QR, iOS Keychain / Android secure storage, AES-256-GCM roster encryption, HMAC-protected GATT writes, authenticated group controls; advertising flags treated as untrusted sync hints. Legacy QR/share disabled; Delete Account now clears saved group keys.
- **Migration:** Old real groups have no secure secret and will be rejected by the new BLE transport. **Recreate the group and scan its new private QR.** Six-character code alone only works in demo mode.
- **Verification:** [Flutter analysis + cryptography + complete suite passed](https://github.com/simplyy-shadin/trail-seek-demo/actions/runs/41836895323). Android debug APK [compiled on a prior PR commit](https://github.com/simplyy-shadin/trail-seek-demo/actions/runs/41836510785), and unsigned iOS code [compiled after CI Pods repair](https://github.com/simplyy-shadin/trail-seek-demo/actions/runs/41837182104); **latest commit native checks still pending**. Physical multi-phone tests not run.
- **Limitations:** Group-level shared-secret authentication does not establish per-member identity or trustworthy BLE beacon liveness; native behavior and all-recipient message receipts need additional validation.
- **Full diff:** [PR #4 changed files](https://github.com/simplyy-shadin/trail-seek-demo/pull/4/files).

| Code file (current PR branch) | Changed lines (new PR side) | What changed |
| --- | --- | --- |
| [`.github/workflows/ios.yml`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/.github/workflows/ios.yml) | `L36-L37` | Analyze security code and tests; preserve iOS sideload steps |
| [`.github/workflows/native-pr-check.yml`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/.github/workflows/native-pr-check.yml) | `L1-L42` | NEW: Android installable debug APK + unsigned iOS compile checks on PRs |
| [`lib/app/links.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/lib/app/links.dart) | `L11-L19, L21-L33` | Private 256-bit QR/deep link, sensitive-invite sharing warning |
| [`lib/app/providers.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/lib/app/providers.dart) | `L8, L24, L369, L375-L378, L384-L397, L400-L401, L430, L505, L528-L533, L538-L543` | Generate group key; require secure QR; save to vault and preserve when roster changes |
| [`lib/app/router.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/lib/app/router.dart) | `L73-L78, L153` | Preserve private key in QR/deep-link navigation |
| [`lib/core/group_secret_vault.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/lib/core/group_secret_vault.dart) | `L1-L50` | NEW: Keychain / Android secure storage, account deletion wipe; never store group key in SharedPreferences |
| [`lib/data/models/group_session.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/lib/data/models/group_session.dart) | `L1-L2, L80, L106, L129-L132, L149, L172` | In-memory credential, excluded from JSON |
| [`lib/features/group/create_group_screen.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/lib/features/group/create_group_screen.dart) | `L56-L71, L73-L76` | Show secure key-storage errors and recover create-group UI. |
| [`lib/features/group/join_group_screen.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/lib/features/group/join_group_screen.dart) | `L11, L16, L25, L30, L50-L56, L59-L74, L78, L94, L104-L106, L120, L166-L172` | Scan secure QR, reject bare-code real joins, show errors |
| [`lib/features/group/lobby_screen.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/lib/features/group/lobby_screen.dart) | `L92-L93, L106, L108, L125, L129-L133, L135-L136, L145-L147, L156` | Secure QR/copy, disable old unprotected invites, and show migration warning |
| [`lib/features/rope/links/ble_peer_link.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/lib/features/rope/links/ble_peer_link.dart) | `L16, L18, L92-L96, L223-L229, L237, L298-L301, L416-L425, L440-L441, L453-L466, L468-L480, L485-L495, L501, L506, L525-L544, L670-L695, L703, L712, L717-L721, L723` | Encrypted GATT read, HMAC for writes, control authentication, untrusted advertisement hints |
| [`lib/features/rope/links/rope_control_frame.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/lib/features/rope/links/rope_control_frame.dart) | `L1-L60` | NEW: secure request-start/end event codec and expiry |
| [`lib/features/rope/links/rope_roster.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/lib/features/rope/links/rope_roster.dart) | `L99-L101` | Reserve 29 bytes AES-GCM overhead in 512-byte GATT attribute |
| [`lib/features/rope/links/rope_security.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/lib/features/rope/links/rope_security.dart) | `L1-L105` | NEW: AES-256-GCM roster confidentiality and HMAC-SHA256 message tags |
| [`lib/features/settings/ble_diagnostics_screen.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/lib/features/settings/ble_diagnostics_screen.dart) | `L2-L4, L109-L111, L122` | Bench-only key derivation, isolated from real group flow |
| [`lib/features/settings/settings_screen.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/lib/features/settings/settings_screen.dart) | `L11, L145-L154` | Erase Keychain/Keystore group credentials before Delete Account & Data. |
| [`lib/main.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/lib/main.dart) | `L10, L29-L36` | Load secure vault before saved sessions; fail closed if unavailable |
| [`pubspec.yaml`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/pubspec.yaml) | `L53-L54` | Crypto and platform secure storage dependencies |
| [`test/group_screens_test.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/test/group_screens_test.dart) | `L103-L107` | Scroll before checking lazy-built member row |
| [`test/join_code_test.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/test/join_code_test.dart) | `L16-L29` | Secure QR key extraction and bare-code rejection tests |
| [`test/links_test.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/test/links_test.dart) | `L7-L9` | Invitation text regression update |
| [`test/rope_security_test.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/fix/ble-group-auth-and-roster-privacy/test/rope_security_test.dart) | `L1-L89` | NEW: wrong-key, tampering, encryption, nonce, control expiry, session JSON tests |

## 2026-11-04 — PR #3: Multi-hop manual SOS / STOP / WAIT / I'M OKAY

- **Status:** **Merged into `main`** on 2026-11-04. [PR #3](https://github.com/simplyy-shadin/trail-seek-demo/pull/3) · [Merge commit `4f82980`](https://github.com/simplyy-shadin/trail-seek-demo/commit/4f82980ca4b852dbe40ea0ce41368b5ceaefa2b4).
- **Why:** Manual quick actions previously stopped at the first Bluetooth neighbour; an increasing heartbeat sequence was unsafe to forward.
- **Validation:** GitHub Actions [final passing run #41829663911](https://github.com/simplyy-shadin/trail-seek-demo/actions/runs/41829663911) **passed**: Flutter analyzer, action-relay tests and the full Flutter test suite. Physical iOS/Android multi-hop and locked-screen tests **not run**.
- **Known limitations:** A successful GATT write does not prove end-to-end delivery. Group authentication and recipient acknowledgements remain future work. iOS sideload workflow unchanged.
- **Full diff and commit history:** [PR #3 Files changed](https://github.com/simplyy-shadin/trail-seek-demo/pull/3/files).

| Code file (pinned to merged revision) | Changed lines (PR new side) | Purpose |
| --- | --- | --- |
| [`.github/workflows/ios.yml`](https://github.com/simplyy-shadin/trail-seek-demo/blob/4f82980ca4b852dbe40ea0ce41368b5ceaefa2b4/.github/workflows/ios.yml) | `L36-L37` | Focus the Flutter analyzer on manual BLE relay code; retain full test suite and existing iOS sideload build steps. |
| [`lib/features/rope/links/ble_peer_link.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/4f82980ca4b852dbe40ea0ce41368b5ceaefa2b4/lib/features/rope/links/ble_peer_link.dart) | `L15, L85-L86, L217-L220, L281-L282, L320-L327, L332, L339-L341, L350, L353-L354, L366, L433-L451, L472-L476, L517-L534, L638-L647` | Queue stable manual actions, send immediate BLE beacon, relay unseen GATT messages across neighbours and emit existing notifications. |
| [`lib/features/rope/links/rope_action_relay.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/4f82980ca4b852dbe40ea0ce41368b5ceaefa2b4/lib/features/rope/links/rope_action_relay.dart) | `L1-L168` | NEW: bounded 12-byte action frames, stable event IDs, hop cap, priority ordering, expiry and duplicate prevention. |
| [`lib/features/rope/links/rope_packet.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/4f82980ca4b852dbe40ea0ce41368b5ceaefa2b4/lib/features/rope/links/rope_packet.dart) | `L25, L47-L49, L69, L93` | Add v2 action marker to the existing eight-byte heartbeat without changing iOS/Android platform settings. |
| [`test/rope_action_relay_test.dart`](https://github.com/simplyy-shadin/trail-seek-demo/blob/4f82980ca4b852dbe40ea0ce41368b5ceaefa2b4/test/rope_action_relay_test.dart) | `L1-L138` | NEW: simulated 10-phone nine-hop relay; SOS priority; bad/expired packets; legacy compatibility, auto-alert bit coexistence, replay protection. |

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
