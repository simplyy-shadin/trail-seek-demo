# Trail Seek — Technical Plan

> Explore · Plan · Go Together
> Companion to `docs/MVP_Product_Launch_Plan.pdf` (product, monetization, budget, timeline).
> This file covers *how we build it*. Working document, October 2026.

## 1. Platform decision

**Requirement:** Android and iOS from day one, and an Android phone and an iPhone in the
same group must be able to see each other on the Digital Rope.

That single requirement decides most of the stack:

| Option | Verdict |
|---|---|
| Android Nearby Connections / Apple Multipeer | Rejected. Each is single-platform; they cannot interconnect. |
| Wi-Fi Direct / hotspot mesh | Rejected. iOS gives apps no control over Wi-Fi Direct. |
| **Bluetooth Low Energy (GATT + advertising)** | **Chosen.** Only radio layer both OSes expose to apps with background support, and it is cross-platform by spec. |

**App framework: Flutter** (stable 3.47, Dart 3.13).
One codebase for both platforms, and the `bluetooth_low_energy` package gives us both the
*central* (scanner) and *peripheral* (advertiser) roles on Android and iOS, which the chain
topology needs. All Digital Rope logic is pure Dart so it is unit-testable without a phone.

Rejected: React Native (BLE peripheral mode is immature), native twice (doubles the work for
a 3-person team).

## 2. Architecture

```
lib/
  app/            theme, router, bootstrap
  core/           shared widgets, utils, constants
  features/
    onboarding/   splash, intro pager, region select
    auth/         login / signup gate (stub provider now, Firebase later)
    discovery/    categories, adventure list, adventure detail
    plan/         solo vs group choice, saved, profile, milestones
    group/        create / join / lobby (QR + code), pre-start checklist
    rope/         Digital Rope: engine (pure Dart), peer links, live tracking UI, alerts
    summary/      session complete, share card
  data/
    models/       Adventure, Region, GroupSession, Member, RopeState, ...
    repositories/ interfaces + local implementations (JSON assets, shared_preferences)
assets/data/kerala_adventures.json   seed content (flag `verified: false` until Ashna signs off)
test/                                engine + state-machine tests, scripted scenarios
```

Principles:

- **Offline-first.** Discovery content ships in the app. Group create/join and the whole
  Digital Rope work with zero network; the backend (auth, sync, milestones) is additive.
- **Engine is UI-free.** `RopeEngine` takes peer observations in and emits member states out.
  It runs against a `PeerLink` interface with two implementations:
  `SimulatedPeerLink` (dev, emulator, tests, scripted "shoelace" scenario) and `BlePeerLink`.
- **Repositories behind interfaces.** `AdventureRepository`, `GroupRepository`,
  `AuthRepository`, `SessionHistoryRepository`. Local now; swap to Firebase/Supabase later
  without touching features.
- State management: Riverpod. Navigation: go_router. Maps: flutter_map (OpenStreetMap) to
  stay inside the ₹0–5,000 maps budget.

## 3. Digital Rope over BLE

### 3.1 Topology

Every phone is both a **peripheral** (advertises) and a **central** (scans). No pairing, no
connections for the heartbeat path; everything rides on advertisement packets, which are the
most robust thing BLE does in forest terrain.

```
Phone A <-> Phone B <-> Phone C <-> Phone D <-> Phone E
```

- Service UUID is fixed for the app (`7a5e0001-5eeb-...`) and is what both platforms
  filter scans on. The 8-byte heartbeat
  `sessionHash(2B) | memberIndex(1B) | seq(1B) | flags(1B) | gossip bitmap(2B) | reserved(1B)`
  is base64url-encoded into an 11-character **local name**. Reason: iOS centrals cannot read
  service data or manufacturer data from advertisements, and iOS peripherals cannot advertise
  them either. The local name is the one payload field both OSes can advertise *and* read
  in the foreground. (`lib/features/rope/links/rope_packet.dart`)
- `gossip bitmap` = "members I have directly heard in the last 10 s". That is the chain:
  A does not hear D, but A hears B and B's bitmap says D is alive, so D is
  *reachable via chain*, not *separated*.
- Quick actions ("I'm OK / Wait for me / Need help / Group alert / Stop group") ride in the
  `flags` byte for the next 8 heartbeats, so a dropped packet does not lose them. A GATT
  characteristic on the same service exists for the iOS-background path and for larger
  payloads (last-known GPS) later.

### 3.2 Per-member observation inputs

| Input | Source |
|---|---|
| `lastDirectSeen` | timestamp of last advertisement from that member |
| `rssiWindow` | ring buffer of last ~15 RSSI samples (≈30 s) |
| `lastChainSeen` | newest time any neighbour's gossip bitmap included that member |
| `missedHeartbeats` | consecutive expected 2 s slots with nothing heard |
| `lastKnownPosition` | last GPS received over GATT or self-reported |

**Engineering principle (from the product plan):** never show "43.7 m away". Distance is
estimated only as a *trend*, never a number. States are driven by time + misses + RSSI slope +
chain reachability.

### 3.3 State machine (initial thresholds, tune in beta)

| State | Enter when | Notes |
|---|---|---|
| `connected` | heard (direct or chain) ≤ 10 s ago, RSSI slope not steeply negative | normal |
| `weak` | heard ≤ 10 s ago but RSSI median fell > 12 dB over 30 s, **or** 2–4 missed heartbeats | silent UI hint only |
| `fallingBehind` | not heard 20–60 s **or** `weak` sustained 45 s | 20 s grace = shoelace. Member gets "Your group is moving away." Leader gets "1 member is falling behind." |
| `separated` | not heard direct **or** chain for > 60 s | last-known position + recovery actions shown |
| `critical` | `separated` for > 180 s with no reconnection | Stop Group / Locate Last Position / Send Group Alert become primary |

Recovery: three consecutive heartbeats return a member to `connected` (hysteresis to kill
flapping). All thresholds live in `RopeConfig` so beta tuning is a data change, not a code
change. The engine logs every transition as a `RopeEvent` (feeds the beta metrics list:
time-to-first-warning, time-to-leader-alert, false-alert rate, reconnect time).

### 3.4 Platform notes

- **Android:** foreground service with `connectedDevice` + `location` types; permissions
  `BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT`, `ACCESS_FINE_LOCATION`,
  `POST_NOTIFICATIONS`. Battery-optimisation exemption prompt in the pre-start checklist.
- **iOS:** background modes `bluetooth-central` and `bluetooth-peripheral`. In background iOS
  strips the local name from advertisements and moves the service UUID to the overflow area
  (visible only to other iOS centrals). So iOS-in-background → Android is invisible on the
  advertisement path and needs the GATT read path. This is the single biggest cross-platform
  risk and must be the first thing field-tested (screen-locked iPhone scenario in §14 of the
  product plan).
- Heartbeat 2 s advertising interval in foreground; back off to 5 s when the engine sees the
  whole group `connected` for > 2 min (battery).

## 4. Data model (summary)

- `Region` — id, name, state, cover, enabled (Kerala only at launch).
- `ActivityCategory` — trekking, hiking, forestWalk, mountaineering, rockClimbing, camping,
  cycling, mountainBiking, trailRunning, groupJogging, kayaking, rafting, waterfallTrail.
  MVP surfaces 5: trekking, hiking, forestWalk, camping, waterfallTrail.
- `Adventure` — overview, difficulty, distanceKm, durationHours, elevationM, terrain,
  bestSeason, fee/permit/guide, howToReach, parking, network, facilities, water,
  emergencyContacts, risks, dangerousSections, wildlife, gear, suitability, checklist,
  precautions, lat/lng, `verified` flag.
- `GroupSession` — code (6 chars), name, adventureId, date, start/end, plannedSize,
  organizer, members, status.
- `Member` — id, displayName, role (organizer | member), deviceId, memberIndex (0–15).
- `RopeMemberState` + `RopeEvent` — see §3.
- `Milestone` — completed session count → Explorer (3), Trail Keeper (5), Rope Guardian (10),
  Advanced (20+). Never labelled government-certified.

## 5. Screens

> **Direction change 2026-10-18:** the target UI is now the gamified "Trek Tracking" style in
> `docs/brand/gamified-ui-mockup.jpeg` (avatar, XP, levels, badges, five tabs, GPS-verified activities,
> community). The breakdown lives in `tasks/`. The original flow below remains valid for the group
> safety path, which moves into the Groups tab.

### 5.1 Original flow (`docs/brand/screen-flow-mockup.jpeg`)

1 Splash · 2 Intro · 3 Region select · 4 Categories · 5 Adventure list · 6 Adventure detail ·
7 Plan (solo / group) · 8 Create / join group · 9 Lobby with QR + code · 10 Pre-start checklist ·
11 Live tracking · 12 Falling-behind alert · 13 Session complete. Plus auth gate, saved, profile.

Auth gate fires on the first *meaningful* action (choosing a region or tapping Plan Adventure),
never on launch, and resumes the interrupted flow afterwards.

## 6. Build order

| Weeks | Work |
|---|---|
| 1–2 | Flutter skeleton, theme, navigation for all screens, Kerala seed data, discovery + plan flows, auth stub |
| 3–4 | Group create/join (code + QR), `RopeEngine` + `SimulatedPeerLink`, state machine tests, live tracking UI on simulated data |
| 5–6 | `BlePeerLink` on Android + iOS, foreground/background behaviour, alerts, last-known location, battery work |
| 7–8 | Internal field tests on 3–5 local routes, then Hiker India closed beta |
| 9–10 | Threshold tuning from beta metrics, store assets, policies, public MVP decision |

## 7. Open decisions

- Backend: Firebase (fastest, free tier covers beta) vs Supabase (Postgres, cheaper at scale).
  Not needed before week 5. Leaning Firebase for Auth + Firestore + FCM.
- Whether lobby join must work fully offline (BLE-only join) or requires one online handshake.
  Target: offline-capable, because trailheads have no signal.
- Map tiles offline: flutter_map tile caching vs. bundled MBTiles for the 20–30 locations.
