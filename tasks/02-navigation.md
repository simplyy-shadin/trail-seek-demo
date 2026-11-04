# 02 · Five-tab navigation

**Status:** done (2026-10-18; avatar redirect in splash arrives with task 04) · **Size:** S · **Depends on:** 01

## Goal
Switch the shell from Explore · Saved · Trails · Profile to the mockup's Home · Explore · Groups · Community · Profile,
and re-home the old tabs without losing any route.

## Mockup reference
Bottom bar on frames 5–14.

## Scope
- `lib/app/router.dart`: `StatefulShellRoute` with five branches: `/home`, `/explore`, `/groups`, `/community`, `/profile`.
- Saved → a heart filter chip and a "Saved" section inside Explore (task 08) and a shortcut on Profile.
- Trails → "My Activity" quick action on Home and the History tab on Profile (task 11).
- Deep links keep working: `/adventure/:id`, `/group/:id/*`, `/activity/:id`, `/auth`.
- Splash decides: not onboarded → `/intro`; no account → `/auth`; no avatar → `/avatar`; else `/home`.
- Auth gate: still only on meaningful actions (Start Trek, Groups, Community post, Profile edit).

## Acceptance
- Tapping each tab preserves that tab's own navigation stack (indexed stack).
- Back button on a root tab goes to Home first, then exits (Android behaviour).
- All existing widget tests pass with the new initial routes (update `test/app_smoke_test.dart`).

## Implementation notes
- `HomeShell` in `lib/features/discovery/home_shell.dart` moves to `lib/app/home_shell.dart` and uses `TsBottomNav` from 01.
- Tab icons: home, search, groups, forum/people, person (outlined + filled pairs).
