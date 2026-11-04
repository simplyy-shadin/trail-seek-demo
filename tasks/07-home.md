# 07 · Home dashboard

**Status:** done (2026-10-18; Start Trek opens the solo plan until the GPS recorder from task 09 replaces it) · **Size:** M · **Depends on:** 01, 02, 05

## Goal
Frame 6: "Good morning, FayazFF", level chip, XP bar, featured trek carousel, four quick actions,
upcoming group trek.

## Scope
- Greeting by time of day + username; `LevelChip` top-right; "New trails. New stories." sub-line; `XpBar`.
- Featured carousel: 5 adventures (rotate daily, deterministic by date), page dots, difficulty pill, km, hrs. Tap → detail.
- Quick actions: Start Trek (→ 09 picker), Find Treks (→ Explore), Groups (→ Groups tab), My Activity (→ History 11).
- Upcoming: next lobby/checklist session from `groupProvider`, with date/time; "View All" → Groups.
- Active session banner (Digital Rope running or solo recording in progress) pinned at top.
- Pull to refresh (no-op until 16).

## Acceptance
- Renders in < 1 frame of jank on Pixel 8 with 26 adventures (no sync JSON decode in build).
- Quick actions all navigate; "Start Trek" from Home opens the trek picker with "Free trek (no trail)" option.
- Smoke test: returning user lands on Home and sees the greeting.

## Implementation notes
- New `lib/features/home/home_tab.dart`; retire `explore_tab.dart`'s promo and active banner (moved here).
- Featured selection: `adventures[(dayOfYear + i * 5) % adventures.length]`.
