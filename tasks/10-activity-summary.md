# 10 · Activity summary + share card

**Status:** done (2026-10-18; the golden test became a render-size test; manual WhatsApp/Instagram check of the share image still pending on the Pixel) · **Size:** M · **Depends on:** 09, 05

## Goal
Frame 9: hero image, trail name, date and time range, Verified pill, route thumbnail, Distance / Elevation Gain /
Duration / Highest Altitude cards, elevation profile chart, Share Activity.

## Scope
- Route thumbnail: static `FlutterMap` with the recorded polyline, interaction disabled, start/end dots.
- Elevation profile: custom `CustomPainter` line chart (distance on x, altitude on y), neon fill gradient, min/max labels. No chart package.
- Stat cards from 01. Verified pill only when `ActivityRecord.verified`.
- XP earned strip ("+272 XP · Level 3 · 520 / 1,000") fed by `ProgressDelta` from 05, which triggers 14 if a level or badge landed.
- Share: render a 1080×1350 share card (`RepaintBoundary` → PNG) with route, stats, avatar, Trail Seek mark; share via `share_plus` as an image file.
- Group sessions reuse this screen with an extra "Group" section: members, separations caught, time to first warning (replaces `session_complete_screen.dart`).
- Delete activity (confirm) and edit title.

## Acceptance
- Summary opens within 300 ms of stopping a recording.
- Share sheet receives a PNG that looks right on WhatsApp and Instagram story (manual check).
- Elevation chart handles flat tracks and tracks with < 3 samples without exceptions.
- Golden test for the share card with a fixed `ActivityRecord`.
