# Trail Seek

**Explore · Plan · Go Together.** Kerala-first adventure discovery app with **Digital Rope**,
a phone-to-phone Bluetooth group-safety layer that warns a group before a member is truly lost.

- Product plan: `docs/MVP_Product_Launch_Plan.pdf`
- Technical plan and architecture: `PLAN.md`
- Brand assets and screen mockups: `docs/brand/` (target UI: `docs/brand/gamified-ui-mockup.jpeg`)
- **Task board for the gamified rebuild: `tasks/README.md`** (one markdown file per task)

## Stack

Flutter 3.47 / Dart 3.13 · Riverpod · go_router · flutter_map (OpenStreetMap) ·
`bluetooth_low_energy` (BLE central + peripheral on Android and iOS).

## Run

```bash
export PATH="$HOME/development/flutter/bin:$PATH"   # already in ~/.bashrc
flutter pub get
flutter run                 # picks the connected phone
flutter test                # Digital Rope state machine + packet codec tests
flutter analyze
```

## What works today (v0.2, 2026-10-18)

| Area | Status |
|---|---|
| Neon design system + `/gallery` debug route (task 01) | done |
| Five tabs: Home · Explore · Groups · Community · Profile (02) | done |
| Splash, sign up / log in with local hashed accounts, Google/Apple stubs (03) | done; Firebase in 16 |
| Avatar from your photo: AI-rendered trekker, 4 variants (22) | done client-side; run with `--dart-define=FAL_KEY=…` until the proxy ships |
| Avatar choose + customize + "Profile Created" (04) | done, procedural fallback |
| XP / levels / titles / badges / achievements engine (05) | done, unit-tested |
| Profile with Stats · Badges · Achievements · History (06) | done |
| Home dashboard, Explore with filters, Outside Kerala placeholder (07, 08) | done |
| Solo GPS recording with crash-safe restore, foreground service (09) | done; walk test pending |
| Activity summary: route map, elevation profile, share card PNG (10) | done |
| Activity history with filters, month totals, undo delete (11) | done |
| Groups guide view: avatar markers, participants, GPS-only distance, Digital Rope (12) | done; field test in 18 |
| Community feed, compose, likes, comments, hashtags, report/block (13) | local-first; cloud in 16 |
| Level Up screen, badge sheets, XP toasts (14) | done |
| Settings incl. units, CSV export, delete account (15) | done |
| Offline map tile cache + per-trail downloads (17) | done; needs a paid tile source before beta |
| 26 Kerala adventures, `verified: false` until research confirms (20) | pending Ashna |

Task board with per-task status, scope and acceptance: `tasks/README.md`.

## Not yet

Real backend/auth, foreground service + iOS background BLE path, offline map tiles,
payments, watch apps. See `PLAN.md` §6–7.

## Safety note

During beta Trail Seek is an experimental companion tool, not a primary safety device.
Manual headcounts and normal guide procedures continue.
