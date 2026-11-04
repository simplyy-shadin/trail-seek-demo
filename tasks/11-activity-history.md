# 11 · Activity history

**Status:** done (2026-10-18; CSV export lands with Settings, task 15; Profile embedding with task 06) · **Size:** S · **Depends on:** 09, 10

## Goal
Frame 13: "My Activities" list with All / Trekking / Cycling / Kayaking filters, thumbnail, name, date, km, duration, Verified tag.

## Scope
- `ActivityRepository` (local JSON now, Firestore in 16) listing `ActivityRecord`s newest first, paged by 20.
- Filter chips by activity type; empty state per filter.
- Row tap → summary (10). Swipe to delete with undo.
- Month headers ("April 2025") and a monthly total line (km, activities).
- Entry points: Home "My Activity", Profile History segment, Settings → Data export (CSV of activities, S).

## Acceptance
- 200 synthetic activities scroll smoothly (use `ListView.builder`).
- Deleting an activity recomputes XP/badges correctly (05 must support `revoke(activityId)`).
