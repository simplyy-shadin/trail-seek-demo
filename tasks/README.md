# Trail Seek — Task Board

Target: rebuild the app in the **gamified "Trek Tracking" style** (`docs/brand/gamified-ui-mockup.jpeg`):
neon green on black, avatar + XP + levels + badges, five tabs (Home · Explore · Groups · Community · Profile),
GPS-verified activities, and the Digital Rope living inside the Groups tab.

One file per task. Each has: status, size, dependencies, goal, scope, acceptance criteria, implementation notes.
Sizes: **S** ≤ half a day · **M** 1–2 days · **L** 3–5 days. Status: `todo` · `in-progress` · `blocked` · `done`.

## Where things stand (2026-10-18)

- **Done in code:** 01–12, 14, 15, 17, plus the local half of 13 and the client half of 22 (photo avatar; needs a `FAL_KEY` define until the proxy exists). 76 passing tests, `flutter analyze` clean.
- **Needs hardware / accounts / people:** 16 backend (Firebase project), 18 BLE field test (two phones), 19 iOS (Mac + Apple account), 20 content (Ashna), 21 release (all of the above).
- **Device checks still owed** because the Pixel was offline for most of the day: gallery and new screens on the phone, a real GPS walk with kill-and-restore and battery, 12-participant demo at 60 fps, offline tiles in airplane mode, share-card look in WhatsApp/Instagram.
- Latest test build for anyone: https://github.com/C00LPIXER/trailseek/releases/latest/download/trailseek.apk (34 MB, arm64). Release flow: `flutter build apk --release --split-per-abi`, verify it starts on the Pixel, `gh release create vX.Y.Z trailseek.apk`.
- Bench-test the mesh before the 30 Oct trek: Settings → Bluetooth diagnostics, procedure in task 18.

### v0.1 skeleton (2026-10-17)

- Flutter project, Android build + install on Pixel 8, launcher icon
- 26 Kerala adventures (`assets/data/kerala_adventures.json`, flagged `verified: false`)
- Digital Rope engine (5 states, chain reachability, hysteresis) + simulated and BLE transports

## Build order

| # | Task | Size | Depends on | Status |
|---|------|------|-----------|--------|
| 01 | [Neon design system](01-design-system.md) | M | — | done |
| 02 | [Five-tab navigation](02-navigation.md) | S | 01 | done |
| 03 | [Splash + Sign up / Log in](03-splash-auth.md) | M | 01 | done |
| 04 | [Avatar setup + customization](04-avatar.md) | L | 01, 03 | done |
| 05 | [Gamification engine (XP, levels, badges)](05-gamification-engine.md) | M | — | done |
| 06 | [Profile tab (XP, badges, achievements)](06-profile.md) | M | 01, 04, 05 | done |
| 07 | [Home dashboard](07-home.md) | M | 01, 02, 05 | done |
| 08 | [Explore redesign](08-explore.md) | M | 01, 02 | done |
| 09 | [Solo GPS live tracking](09-solo-tracking.md) | L | 01, 02 | done |
| 10 | [Activity summary + share card](10-activity-summary.md) | M | 09, 05 | done |
| 11 | [Activity history](11-activity-history.md) | S | 09, 10 | done |
| 12 | [Groups tab (guide view + Digital Rope)](12-groups-guide-view.md) | L | 01, 02, 09 | done |
| 13 | [Community feed](13-community.md) | L | 01, 02, 16 | in-progress |
| 14 | [Level up + reward moments](14-level-up.md) | S | 05, 06 | done |
| 15 | [Settings](15-settings.md) | S | 01, 02 | done |
| 16 | [Firebase backend + sync](16-backend.md) | L | 03, 05 | todo |
| 17 | [Offline maps](17-offline-maps.md) | M | 09 | done |
| 18 | [Digital Rope BLE field test](18-ble-field-test.md) | L | 12 | todo |
| 19 | [iOS build + TestFlight](19-ios-build.md) | M | 01 | todo |
| 20 | [Content verification + photos](20-content.md) | M | — (Ashna) | todo |
| 21 | [QA, store listing, closed beta](21-release.md) | M | all | todo |
| 22 | [Photo avatar (AI render from selfie)](22-photo-avatar.md) | M | 04, 16 | in-progress |
| 23 | [Thrissur pivot: Forest Department programmes](23-thrissur-pivot.md) | L | 16, 19 | in-progress |

## UX audit (2026-10-18, 35 findings)
Fixed by v0.3.2: 1–6, 8–20, 22–24, 27–29, 33, 35. Open: 7 photos (needs licensed images), 21 Malayalam
(needs a translator; ~400 strings), 25/26 layout nits, 30 reviews and 31 reminders (backend), 32 light theme,
34 password reset (backend).

## Suggested sprints

- **Sprint 1 (week 1):** 01, 02, 05, 03 — the look, the tabs, the XP rules, the entry flow.
- **Sprint 2 (week 2):** 07, 08, 09, 10 — home, explore, and a real GPS-recorded trek with a summary.
- **Sprint 3 (week 3):** 04, 06, 11, 14, 15 — avatar, profile, history, rewards, settings.
- **Sprint 4 (week 4):** 12, 16, 17 — groups with Digital Rope, backend, offline maps.
- **Sprint 5 (weeks 5–6):** 13, 18, 19, 20, 21 — community, field tests, iOS, content, beta.

## Rules of the road

- Mockup is the spec for layout; `PLAN.md` is the spec for architecture (offline-first, repositories behind interfaces, rope engine pure Dart).
- No fabricated safety content: anything unverified stays flagged and labelled in the UI.
- Never say "government-certified". Never show a precise distance between phones from Bluetooth; show trends.
- Every task ends with `flutter analyze` clean and `flutter test` green, run on the Pixel 8.
- Update the status column here when you pick up or finish a task.
