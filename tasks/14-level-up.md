# 14 · Level up + reward moments

**Status:** done (2026-10-18) · **Size:** S · **Depends on:** 05, 06

## Goal
Frame 15: full-screen "Level Up! You've reached Level 4", +XP, new badge, next reward, Continue. Plus lighter
moments for badges and XP.

## Scope
- Listen to `progressEvents` (05) at app root; queue overlays so several events play one after another.
- Level Up screen: neon mountain mark, haptic, confetti (simple particle `CustomPainter`, no package), three tiles: XP gained, new badge, next unlock. Continue returns to where the user was.
- Badge unlocked: bottom sheet with `HexBadge` flip animation and the rule it satisfied.
- XP toast: "+272 XP" chip animating up from the summary stat strip.
- Respect reduced-motion accessibility setting (skip particles, keep content).

## Acceptance
- Completing an activity that crosses a level shows XP toast → Level Up → badge sheet in that order, once.
- Events that fire while the app is in background are shown on next resume.
- No overlay appears during an active recording or Digital Rope session (deferred until it ends).
