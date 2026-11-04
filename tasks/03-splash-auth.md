# 03 · Splash + Sign up / Log in

**Status:** done (2026-10-18; lands on avatar setup once task 04 exists, on region/home until then) · **Size:** M · **Depends on:** 01

## Goal
Match frames 1–2: a hero splash with "Explore · Track · Earn" and a real credentials form with
Log In / Sign Up tabs, Google and Apple buttons, and terms links.

## Scope
- Splash: full-bleed hero (placeholder gradient + mountain silhouette until licensed photo), logo mark,
  wordmark, tagline, neon "Get Started", "Already have an account? Log in".
- Intro pager stays optional behind a flag (`showIntro`), default off to match the mockup.
- Auth screen:
  - Segmented Log In / Sign Up at top.
  - Sign Up: Full name, Email, Password (with visibility toggle), Create Account, "or", Google, Apple (iOS only), terms line.
  - Log In: Email, Password, Forgot password, Log In, Google, Apple.
  - Inline validation (email format, password ≥ 8 chars), error banners, loading state on buttons.
- `AuthRepository` interface in `lib/data/repositories/auth_repository.dart` with methods
  `signUpWithEmail`, `signInWithEmail`, `signInWithGoogle`, `signInWithApple`, `sendPasswordReset`, `signOut`, `currentUser`, `authStateChanges()`.
  `LocalAuthRepository` implements it now (stores hashed password locally, for prototype only); Firebase implementation arrives in 16.
- `AppUser` gains `email`, `username` (auto-derived, editable later), `avatarId`, `createdAt`.

## Acceptance
- New user: Sign Up → lands on Avatar setup (04) with name prefilled.
- Returning user: Log In → Home.
- Wrong password shows an inline error, no crash, button re-enabled.
- `redirect` query param still returns the user to the interrupted flow.

## Implementation notes
- Replace `AuthController` body in `lib/app/providers.dart` to call the repository; keep the provider name.
- Password hashing for the local stub: `package:crypto` SHA-256 with a random salt. Clearly comment it is not production auth.
- Apple button only on iOS (`Theme.of(context).platform`), as today.
