# 16 · Firebase backend + sync

**Status:** todo · **Size:** L · **Depends on:** 03, 05

## Goal
Real accounts, cloud copies of profiles / activities / groups / progress, photos, and push. Everything stays
offline-first: the app must work on a trail with no signal and reconcile later.

## Scope
- Firebase project (dev + prod), Android + iOS apps registered, `flutterfire configure`.
- Auth: Email/Password, Google, Apple (iOS). `FirebaseAuthRepository` implements the interface from 03.
- Firestore schema:
  - `users/{uid}`: profile, avatar, progress snapshot (xp, level, badges), settings
  - `users/{uid}/activities/{id}`: `ActivityRecord` + compressed track (polyline-encoded) in Storage `tracks/{uid}/{id}.json.gz`
  - `groups/{id}`: session doc, `members` subcollection; join by code = query on `code` (indexed, 6-char, expires after the trek date + 2 days)
  - `posts`, `follows`, `reports` (13)
  - `xpEvents/{uid}/{activityId}`: server-side idempotency for XP
- Security rules + unit tests with the rules emulator.
- Sync layer: outbox queue in `LocalStore` → Firestore when online; conflict policy = last-write-wins per field except progress, which is recomputed server-side by a Cloud Function from activities (prevents client XP tampering).
- Cloud Functions: `onActivityCreated` (recompute progress, award badges), `onReportCreated` (hide after 3), weekly summary push.
- FCM push for group alerts fallback (when both phones have data) and community notifications.
- Analytics + Crashlytics with user consent toggle.

## Acceptance
- Sign up on Pixel, log in on iPhone: same profile, activities, badges.
- Record an activity in airplane mode, go online: it appears in Firestore within 10 s, XP matches the client's.
- Rules tests: a user cannot read another user's tracks, cannot write their own XP.
- Monthly cost projection for 1,000 users on the free tier documented in `docs/backend-costs.md` (stays inside the ₹0–6,000 budget line).

## Implementation notes
- Keep `LocalStore` as the cache; repositories get a `remote` + `local` pair and a `SyncService`.
- Group join must keep working with no network: BLE match on code hash already exists; Firestore only enriches the roster.
