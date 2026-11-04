# 20 · Content verification + photos (owner: Ashna)

**Status:** todo · **Size:** M · **Depends on:** — · **Blocks:** public beta

## Goal
Turn the 26 seeded adventures from "plausible" into "verified", add real photography, and seed the first
"Outside Kerala" set so that chip isn't empty.

## Scope
- For each record in `assets/data/kerala_adventures.json`: confirm with the forest office / operator the fee, permit process, guide rule, timings, emergency phone numbers, trail status (e.g. Chembra beyond the heart lake, Meenmutty closures). Flip `verified: true` only after confirmation; add `verifiedOn` and `source`.
- Photos: 1 hero + 3 gallery per adventure, licensed (own, CC-BY with credit, or purchased). Store in `assets/images/adventures/<id>/`, ≤ 300 KB each, with a `credits.json`. Replace `CoverArt` placeholders.
- Add 10–15 "Outside Kerala" starters (Coorg, Nilgiris, Kodaikanal, Wayanad border treks on the Karnataka side) in a second JSON file with the same schema.
- Trail GPX where available (`assets/tracks/<id>.gpx`) for route preview and elevation profile.
- Content QA test extended: every verified record has a non-empty phone for at least one non-112 contact.

## Acceptance
- ≥ 20 Kerala records verified before closed beta; unverified ones still show the amber banner.
- No photo without a credit entry; `flutter test` enforces it.
