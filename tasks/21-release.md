# 21 · QA, store listing, closed beta

**Status:** todo · **Size:** M · **Depends on:** all above (minimum: 01–12, 16, 20)

## Goal
Ship a closed beta to the internal team and Hiker India, then decide on public MVP, following the product plan §14–17.

## Scope
- Test pass: widget tests for every tab root, integration test for sign up → avatar → record trek → summary → level up, rope engine suite, rules tests (16).
- Performance: cold start < 2 s on Pixel 8, no frame > 32 ms on Home/Explore scroll, APK < 40 MB.
- Accessibility: TalkBack labels on icon buttons, text scaling to 1.3× without overflow, reduced motion respected (14).
- Privacy: privacy policy + terms pages hosted (domain line in budget), data deletion flow, Play Data Safety form, Apple privacy labels.
- Store assets: 8 screenshots per platform in the neon style, feature graphic, short/long description (never "government-certified"; say "experimental companion tool").
- Play Console: internal testing track → closed testing (Hiker India emails) → staged rollout decision.
- Beta instrumentation: the metrics list from the product plan (time to first warning, false-alert rate, reconnect time, battery, group size, terrain) flowing from 18's logger into a simple dashboard (Sheets is fine).
- Go/no-go review after 20–50 real group sessions against §17 success criteria.

## Acceptance
- Closed beta build installed by ≥ 10 external testers with crash-free rate ≥ 99 %.
- Field-test report and beta metrics reviewed by the team; public MVP decision recorded in `docs/decisions/`.
