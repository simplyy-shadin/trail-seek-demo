# 05 · Gamification engine (XP, levels, badges, achievements)

**Status:** done (2026-10-18) · **Size:** M · **Depends on:** — (pure Dart)

## Goal
One tested module that turns completed activities into XP, levels, titles, badges and achievements,
and emits events the UI turns into "Level Up" and "New Badge" moments (14).

## Scope
`lib/features/progress/` (pure Dart, no Flutter imports in the engine):
- `XpRules`: XP for a completed, verified activity =
  `100 base + 10 per km + 5 per 100 m elevation gain + 50 if group session + 25 if first time on this trail`.
  Unverified (no GPS track) activities earn 25 % of that. Cap 1,500 XP per activity. All numbers in one config class.
- `LevelTable`: XP to go from level n to n+1 = `500, 750, 1000, 1250, …` (+250 each level), max level 50.
  Titles by level band: 1–2 Trail Rookie, 3–5 Adventure Seeker, 6–9 Pathfinder, 10–14 Ridge Walker, 15–24 Summit Keeper, 25+ Mountain Legend.
- `BadgeCatalog` (id, title, icon key, rule): First Trek Completed, Mountain Explorer (3 peaks > 1,500 m),
  Forest Walker (3 forest walks), Cycling Enthusiast (3 rides), Kayaking Beginner (1 paddle), Early Bird (start before 6 AM),
  Rope Guardian (10 Digital Rope sessions with 0 separations), Trail Keeper (5 group sessions), Night Owl (finish after 7 PM).
  Keep the existing milestone ladder (3/5/10/20 sessions) as achievements.
- `Achievement` = progress counter with target (e.g. 12 treks, 100 km, 5,000 m gain, 5 districts).
- `ProgressEngine.apply(ActivityRecord) -> ProgressDelta { xpGained, newLevel?, newBadges, achievementsCompleted }`.
- `ProgressState` persisted via `LocalStore` (`progress.json`); provider `progressProvider`.
- Events stream for UI: `progressEvents` (levelUp, badgeUnlocked, achievementCompleted).

## Acceptance
- Unit tests: XP maths, level thresholds (incl. multi-level jump), each badge rule, idempotency (applying the same activity id twice awards nothing).
- A completed 8.6 km / 720 m group trek awards 100+86+36+50 = 272 XP (+25 if first time) in a test.
- `flutter test` runs the suite in under 2 s.

## Implementation notes
- `ActivityRecord` is the shared model used by 09/10/11/12: id, type, trailId?, startedAt, endedAt, distanceM, elevationGainM, maxAltitudeM, verified, groupSessionId?, separations.
- Replace `SessionSummary` usage in `historyProvider` with `ActivityRecord` (keep a `fromSessionSummary` adapter so old local data still loads).
- Never label anything "government-certified"; "Verified" means GPS-verified by the app only.
