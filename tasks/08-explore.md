# 08 · Explore redesign

**Status:** done (2026-10-18; Outside Kerala shows a coming-soon state until task 20 adds content) · **Size:** M · **Depends on:** 01, 02

## Goal
Frame 7: search bar, Kerala / Outside Kerala chips, filter button, trek cards with heart. Detail page restyled.

## Scope
- Search across name, district, town, category; debounce 200 ms.
- Region chips: Kerala (enabled) · Outside Kerala (shows coming-soon state until content exists, 20).
- Filter sheet: category multi-select, difficulty (Easy / Moderate / Very Difficult), distance range, duration range, "Saved only", "Group friendly", "Beginner friendly".
- Difficulty: rename `hard` label to "Very Difficult" to match mockup; colours from 01.
- `TrekCard` from 01 replaces `AdventureCard`.
- Detail page: keep the four sections, restyle header with neon pills, sticky bottom "Start Trek" (solo, → 09) and "Plan with Group" (→ 12).
- Saved: heart toggles persist (existing `savedProvider`), saved filter chip.

## Acceptance
- Typing "wayanad" returns 7 cards (count from seed data test).
- Filter sheet state survives tab switch (kept in a `Notifier`).
- Detail "Start Trek" starts a GPS recording pre-linked to that trail (09).

## Implementation notes
- Rework `adventure_list_screen.dart` into `explore_tab.dart` (the tab root is the list now, no separate categories grid; categories become filter chips).
- Keep `AdventureQuery` provider family; extend with the new filters.
