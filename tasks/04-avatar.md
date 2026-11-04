# 04 · Avatar setup + customization

**Status:** done (2026-10-18) with the procedural layer renderer. Superseded for the primary path by task 22 (AI render from a selfie); the procedural avatar remains the offline / no-photo fallback · **Size:** L · **Depends on:** 01, 03

## Goal
Frames 3–5: pick a base avatar, customize outfit/accessories/hair, and land on a "Profile Created" card.
The avatar is the player identity used on the map, in groups and in the community.

## Scope
- Data: `Avatar { base, outfit, accessory, hairStyle, hairColor }` with enums; persisted on the user.
- Asset strategy (decision): **layered 2D PNG/SVG**, not 3D renders. Layers: body, outfit, hair, accessory.
  Ship 8 bases × 4 outfits × 6 hair styles × 6 hair colours × 4 accessories as flat vector layers under
  `assets/avatar/`. Until an illustrator delivers, use a procedural placeholder: coloured silhouette +
  initials, with the same layer API so swapping art is asset-only.
- Screen 3 "Choose Your Avatar": large preview, vertical thumbnail rail, prev/next arrows, Next.
- Screen 4 "Customization": tabs Avatar · Outfit · Accessories; grids; hair style row; hair colour swatches; Next.
- Screen 5 "Profile Created": avatar ring, username, title (from 05), level + XP bar, three stats, motivational quote, continue.
- `AvatarView(avatar, size)` widget composes the layers; used by `AvatarRing`, map markers (12), feed (13).
- Edit entry point from Profile (06) reopens customization.

## Acceptance
- Choosing and customizing persists across app restarts.
- `AvatarView` renders at 24 px (map marker) and 160 px (profile) without blur or clipping.
- Skipping customization is allowed; a default avatar is assigned.
- Golden test for `AvatarView` with two combinations.

## Implementation notes
- Keep layer PNGs ≤ 512 px and under 40 KB each; total avatar assets under 3 MB.
- Expose `avatar.toJson()` so 16 can sync it.
- Username rules: 3–20 chars, letters/digits/underscore, unique check deferred to 16.

## Out of scope
3D models, animated avatars, paid cosmetics.
