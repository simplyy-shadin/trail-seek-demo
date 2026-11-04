# 12 · Groups tab (guide view + Digital Rope)

**Status:** done in code (2026-10-18). Deviation: members see the whole roster, not just the guide, because hiding peers reduces safety; they lose the guide-only controls instead. 60 fps check with 12 participants pending on the Pixel. · **Size:** L · **Depends on:** 01, 02, 09

## Goal
Frame 10: "My Group · 12 Participants · Live", map with avatar markers along the route, participants list
with online/offline and distance from the guide. This is where the existing Digital Rope lives from now on.

## Scope
- Groups tab root: active group (live card) · upcoming groups · past groups · Create / Join buttons.
- Restyle existing create / join / lobby / checklist screens with 01 components; keep flows and QR.
- Live view = existing `LiveTrackingScreen`, restyled:
  - avatar markers (`AvatarView`) with state-coloured rings (connected neon, weak amber, falling behind orange, separated/critical red).
  - participants list: avatar, name, Online / Offline (Digital Rope state mapped: connected/weak → Online, else Offline with "last heard Xs ago"),
    "distance" shown as a **trend word and GPS-based estimate only when both GPS fixes are fresh**, never from Bluetooth RSSI.
  - guide controls: Send Reminder, Stop Group, Locate Last Position; member controls: I'm OK, Wait for me, Need help.
- Guide's own GPS track is recorded with 09's recorder, so a group session also produces a verified activity for every member.
- Group roles: Guide (organizer), Member. Guide sees everyone's state; members see their own + guide.
- Post-session: summary (10) with group section; XP group bonus (05).

## Acceptance
- Demo mode: 12 simulated participants render on the map and list at 60 fps on Pixel 8.
- Shoelace scenario shows the amber alert within the configured grace period and clears on recovery.
- A member who leaves Bluetooth range but still has GPS shows as Offline with a last-known position.
- All existing rope engine tests still pass; add a widget test for the participants list state mapping.

## Implementation notes
- Keep `RopeController`/`RopeEngine` untouched; only presentation changes. New file `lib/features/group/participants_sheet.dart`.
- Distance estimate: haversine between guide's and member's latest GPS positions, shown only if both are < 30 s old, formatted coarse ("~2 km", "< 500 m").
