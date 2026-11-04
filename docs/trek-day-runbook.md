# Trek-day runbook (organizer)

For the first real group test. Assumes everyone installed the app from the invite link and the
bench test in `tasks/18-ble-field-test.md` passed with at least two phones.

## The night before
- Everyone: install the latest build, open it once, sign up, create an avatar (optional), and keep
  Bluetooth + Location on. Battery full; a power bank for the organizer.
- Organizer: Groups → Create Group, Demo mode **off**, correct trek and date. Share the invite
  (Share icon in the lobby) so people can pre-install.
- Organizer: open the trek, "Download map for offline" on Wi-Fi. Ask members to do the same.

## At the trailhead (needs no signal)
1. Organizer opens the group lobby. Members: Groups → Join → code (or scan the QR).
2. Members stand within a few metres of the organizer until their screen says **Joined as #n**.
   The organizer's lobby fills up. Nobody should still show "Waiting for the organizer…".
3. Organizer: Start Adventure → checklist (allow location, Bluetooth, notifications) → Start Tracking.
4. **Every member taps Start Adventure → Start Tracking on their own phone too.** Each phone runs
   its own safety engine; a phone that did not start is invisible to the rope.
5. Headcount out loud. The app is a companion, not the count.

## On the trail
- Keep phones in pockets, app running, screen can be off (Android). iPhones: known limit, keep the
  screen on or check the bench-test result first.
- Alerts: vibration + notification when someone is **falling behind** (after ~20 s quiet), **separated**
  (~60 s), **critical** (~3 min). The member sees "Your group is moving away" on their own phone.
- Quick actions: I'm OK · Wait for me · Need help (members); Send Reminder · Stop Group · Locate (guide).
- Everyone stops when the guide says stop. Alerts tell you *who* and *roughly when*, never an exact distance.

## Controlled scenarios to run (from the product plan §14)
1. One member waits behind at a bend (shoelace). Time from stopping to the guide's alert: ______ s
2. Two members separate together. Did both show, and did "via chain" keep them visible while a
   third person was between? ______
3. Screen locked / phone in pocket for 5 minutes. Did heartbeats continue? ______
4. Battery saver on for one phone. Any difference? ______
5. Battery drop per hour, per phone model: ______

## After
- Everyone: End session → the summary shows separations caught and XP.
- Organizer: Settings → Export activities (CSV) and, if anything looked wrong, Settings → Bluetooth
  diagnostics → share the log. Note phone models and Android/iOS versions.
