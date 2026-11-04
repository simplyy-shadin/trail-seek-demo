# 18 · Digital Rope BLE field test + background path

**Status:** todo · **Size:** L · **Depends on:** 12 · **Carry-over from PLAN.md §3.4 and the product plan §14**

## Goal
Prove the Bluetooth transport between real phones, including Android ↔ iPhone, screen locked, in forest terrain,
and tune the thresholds from measured data.

## Built ahead of the field test (2026-10-18)
- Roster sync over GATT (`rope_roster.dart`, `ble_peer_link.dart`): compact ≤512 B table of members +
  seconds-since-heard, read from 1–2 nearby phones every ~10 s; ages are added on transfer, so
  reachability relays over many hops with no loops (what the "dynamic mesh" picture asks for).
- Offline join: joiner advertises with index 255, writes a join request to the organizer's phone,
  organizer assigns the next free index; lobby shows sync status; everyone taps Start on their own phone.
- Alerts: vibration + sound + system notification on falling behind / separated / critical,
  "your group is moving away", and incoming group messages (`rope_alerts.dart`).
- None of this has run between two real phones yet. First bench test should cover: join flow with
  2 then 3 phones, roster convergence time, heartbeat loss, relay through a middle phone, and the
  iOS-in-background case.

## Bench results 2026-10-18 (Pixel 8 / Android 17 as host, Infinix X689 / Android 11 as member, same room)
- Join by code over BLE, no internet: **13 s** to "Joined as #1". Relaunch rejoins the same slot.
- Heartbeats both ways ≈ 2/s at −45…−75 dBm across the room.
- Quick messages (needHelp) delivered both directions within 3 s.
- Member app killed: Weak immediately, **Falling Behind after ~20 s, Separated after ~60 s** (RopeConfig defaults), 4 notifications on the host, reconnect **10 s** after relaunch.
- Bugs found and fixed by this test: late joiners were judged from session start (instant "separated"); "group moving away" fired at exactly half quiet; the BLE plugin's `authorize()` hangs when permissions are already granted (worked around); simultaneous GATT connects collide (now staggered + retried).
- Still untested: range in forest, three phones (relay through the middle), iPhone, battery over an hour.

## Bench procedure (Settings → Bluetooth diagnostics)
1. Phone A: Host on, code `TEST01`, Start radio. Phone B: Host off, same code, Start radio.
2. Within ~10 s B should log `SYNC Joining…` then `Joined as #1`; A's roster shows `#1 <name>`.
3. Both: "Packets heard" climbs ~1 per 2 s per peer; rssi around −50 at 1 m, −80 at 20 m.
4. Walk apart until "heard … ago" grows past 20 s: that is radio range for those two models.
5. Add phone C; place B midway: A should keep seeing C via chain (observations "via chain") after A↔C direct is lost.
6. Lock the iPhone (if any) and repeat 3: records whether the GATT path keeps it alive.
7. Share the log from the top-right button into the field-test notes.

## Scope
- Bench tests (two phones on a desk): discovery time, heartbeat loss rate, RSSI distribution at 1 / 5 / 10 / 30 m, gossip bitmap correctness with three phones in a line.
- Background behaviour:
  - Android foreground service for the rope (`connectedDevice` + `location` types), Doze exemption prompt in the checklist.
  - iOS: verify local-name stripping in background; implement the GATT read path (`heartbeatCharacteristicUuid` already exists) so an Android central can poll a backgrounded iPhone's heartbeat; measure interval achievable.
- Metrics logger: **built (v0.3.3)**. Every session's state transitions and messages are saved; Settings → Export Digital Rope logs produces `trailseek-rope-sessions.csv` (one row per session: seconds to first warning, falling-behind / separated / critical counts, short-lived alerts ≤45 s as a false-alarm proxy, median reconnect seconds, group size, mode, platform) and `trailseek-rope-events.csv` (one row per transition).
- Scenario scripts (from the product plan): one person waits behind, two people separate, screen locked, phone in pocket, battery saver on/off, open hill, forest.
- Threshold tuning: fit `RopeConfig` values to measured time-to-first-warning and false-alert rate; document the chosen values and why in `PLAN.md`.
- Battery measurement per phone model.

## Acceptance
- Android ↔ Android and Android ↔ iPhone, foreground: falling-behind warning within 30 s of a 40 m separation in open terrain, 0 false alerts over a 30-minute walk together.
- Screen-locked iPhone remains visible to an Android guide via the GATT path with ≤ 10 s heartbeat interval, or the limitation is documented with a mitigation (e.g. "keep iPhone screen on" prompt).
- Results written to `docs/field-tests/YYYY-MM-DD-<route>.md` with the CSVs attached.

## Out of scope
Mesh relaying of GPS positions over multiple hops, satellite.

## Real app flow, two phones (2026-10-18 evening, Pixel 8 organizer + Infinix X689 joiner)

Create Group on the Pixel (demo off) → lobby code → `trailseek://join/CODE` on the Infinix → joiner lobby.
What it exposed, all fixed in 0.3.6:

- Joiner never finished joining. The sync loop had GATT calls with no timeout (`requestMTU`,
  `getMaximumWriteLength`, `disconnect`); one wedged call left `_syncing` true forever and the lobby
  silently stuck on "Waiting to be added by the organizer…". Now every call has a timeout and a whole
  exchange is capped at 30 s, after which the next round retries.
- Lobby started the radio twice (initState + first build) → two BlePeerLinks on one phone. Coalesced.
- Organizer showed nothing while a joiner was nearby but had not written yet. Now "1 phone nearby joining…".
- Both phones signed in with the stub default name showed as two "Trail Seeker"s. Duplicates are now
  suffixed by member index ("Trail Seeker 2") identically on every phone.
- Lobby info banner was hidden under the bottom bar; scroll padding fixed.
- `[LOBBY]`, `[ROPE]`, `[BLE]` lines are mirrored to logcat in the real flow, like `[BLEDIAG]` in the bench tool.

Still owed: the same flow again with both phones on 0.3.6 (Infinix dropped off adb mid-test, so the
joiner-side fix is verified by code and the organizer-side behaviour, not yet end to end), then three phones.

## Second real-flow run (2026-10-18, 21:51, both phones on 0.3.6)

- Join over BLE worked end to end: Infinix opened `trailseek://join/SDGUTP`, wrote its join request on the
  third attempt (two 8 s connect timeouts first), organizer assigned #1, both lobbies showed 2 members.
  Time from joiner start to "Joined as #1": 26 s. Connect reliability to the organizer is the next thing to tune.
- Bugs found and fixed in 0.3.7:
  - Joiner never learned the adventure/date/name of the group (placeholder "Adventure · today"), and the
    checklist fell back to the first adventure in the list. The roster head now carries the organizer's
    session details and the joiner applies them (lobby and live).
  - Live-screen map was grey on both phones: the tile layer threw "Cannot modify unmodifiable map" (const
    headers map in CachedTileProvider). Fixed.
  - Lobby radio and rope radio shared one Bluetooth stack; the lobby's stop() tore down the rope's scan,
    advertising and GATT service when the lobby closed after the rope started. A link now only tears down
    the radio if it is still the newest owner. Also the lobby's delayed first-sync timer could fire after
    stop() ("Cannot add new events after calling close"); cancelled on stop.
  - A 1-minute, 0 km session was recorded as a Verified trek with +220 XP and a badge. Sessions under
    300 m and 5 min are now "Too short to count": not verified, no XP, no badges.
- Not finished: Start on both phones → live screen → messages/alerts. The Infinix USB link dropped
  (kernel: USB disconnect 21:52:09, needs another cable/port; adb also needed ADB_LIBUSB=0 to see it) and
  the Pixel locked. Redo with both phones unlocked and plugged in.
