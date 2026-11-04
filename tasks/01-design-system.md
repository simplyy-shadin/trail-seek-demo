# 01 · Neon design system

**Status:** done (2026-10-18; device check pending until the Pixel is reconnected) · **Size:** M · **Depends on:** — · **Unblocks:** everything visual

## Goal
Replace the orange/green theme with the mockup's neon-green-on-black game style, and ship the reusable
components every other screen needs, so later tasks only compose.

## Mockup reference
All 15 frames. Key traits: near-black background, dark green-grey cards with 1 px border, one neon accent,
white headings, grey captions, pill chips, rounded 16–20 px cards, hexagonal badge tiles, thin XP bar.

## Scope
- Tokens in `lib/app/theme.dart`:
  - `bg #070A07`, `surface #0F150F`, `surfaceHigh #162016`, `outline #1F2B1F`
  - `neon #9DFF1E` (primary), `neonDeep #7ED321`, `textPrimary #F4F7F2`, `textMuted #8FA08C`
  - semantic: `success` = neon, `warning #FFC53D`, `danger #FF4D4D`, `info #3DA5FF`
  - difficulty: Easy neon, Moderate amber, Very Difficult red
- Typography: keep system font for now; heading weights 800, body 400/600. Add `TsText` style helpers.
- Components in `lib/core/widgets/` (one file each, with a widgetbook-style `gallery_screen.dart` behind a debug route):
  - `NeonButton` (filled neon, black text), `GhostButton` (outlined), `IconPillButton`
  - `TsCard` (surface + border + radius), `StatCard` (icon, value, label)
  - `XpBar` (level label left, `520 / 1,000 XP` right, neon progress)
  - `LevelChip` (shield icon + "Level 3")
  - `HexBadge` (hexagon with icon, locked/unlocked state, label under)
  - `TrekCard` (thumbnail, title, place, difficulty pill, distance, duration, heart)
  - `AvatarRing` (circular avatar with neon ring + edit pencil)
  - `SegmentTabs` (pill segmented control: Stats · Badges · Achievements · History)
  - `SectionHeader` (title + "View All")
  - `TsBottomNav` (five items, neon selected icon + label)
- Placeholder imagery: keep `CoverArt` gradient but shift hues to the mockup's greens/teals; add a subtle
  mountain-silhouette overlay asset (`assets/images/mountain_silhouette.png`).
- Dark status bar and nav bar colours set in `main.dart`.

## Acceptance
- A debug route `/gallery` renders every component in both states (enabled/disabled, locked/unlocked).
- Existing screens still compile and pick up the new palette without per-screen edits.
- Contrast: neon on black and white on surface pass WCAG AA for text ≥ 14 px (check with a contrast tool).
- No hard-coded colours remain outside `theme.dart` (`grep -rn "Color(0x" lib/features` returns nothing).

## Implementation notes
- `TsColors` is already the single colour source; keep the name so call sites don't churn.
- `FilledButton` theme becomes neon with black foreground; the Digital Rope "End" button stays red via
  an explicit `danger` style helper, not an inline colour.
- Hexagon: `ClipPath` with a 6-point path, 2 px neon stroke when unlocked, `outline` stroke + lock icon when locked.

## Out of scope
Custom font licensing, animations beyond simple fades (see 14), light theme.
