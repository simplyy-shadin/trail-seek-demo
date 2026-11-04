# 06 · Profile tab (XP, badges, achievements, history)

**Status:** done (2026-10-18) · **Size:** M · **Depends on:** 01, 04, 05

## Goal
Frame 12 (and the header of frame 5): the player card. Avatar, username, title, level, XP bar, then
Stats · Badges · Achievements · History segments.

## Scope
- Header: `AvatarRing` (tap → edit avatar, 04), username, title from `LevelTable`, `XpBar`, settings gear → 15.
- Stats segment: treks, total km, elevation gain, longest trek, districts visited, group sessions, Digital Rope separations caught.
- Badges segment: `HexBadge` grid, unlocked in neon, locked greyed with lock icon, tap → sheet with rule and progress, "More to come…" tile.
- Achievements segment: list with progress bars and target.
- History segment: embeds the activity list from 11 (first 5 + "View all").
- Sign out and "Experimental companion tool" notice move to Settings (15).

## Acceptance
- Profile reflects a newly completed activity (XP, stats, badges) without restart.
- Locked badge sheet shows exactly what is missing (e.g. "2 more forest walks").
- Works for a user with zero activities (empty states, no NaN).

## Implementation notes
- Replace `lib/features/plan/profile_tab.dart`; move the folder to `lib/features/profile/`.
- Saved adventures shortcut lives here too (chip with count → Explore saved filter).
