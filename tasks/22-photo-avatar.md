# 22 · Photo avatar: AI-rendered trekker from a selfie

**Status:** in-progress (2026-10-18) · **Size:** M · **Depends on:** 04 · **Finishes with:** 16 (server proxy)

## Why this exists
The mockup's avatars are AI image renders (stylised 3D trekker portraits). The procedural drawing from
task 04 cannot reach that look, and the user asked for avatars that match the mockup and can be made
from their own photo.

## Research outcome (2026-10-18)
| Option | Verdict |
|---|---|
| Ready Player Me (selfie → 3D, free tier) | **Gone.** Shut down 31 Jan 2026 after the Netflix acquisition; domain no longer resolves. |
| Avaturn / Avatar SDK MetaPerson (selfie → 3D web SDK) | Work, but business plans are ~$800/month; free tiers are non-commercial. Out of budget. |
| DiceBear / faces.js / Avataaars (open-source 2D SVG) | Good illustrations, no photo input, and not the 3D look. Kept as a possible style pack later. |
| White-box Cartoonization / AnimeGANv2 (open-source, TFLite, on-device) | Cartoonises the photo; works offline; not a game character. Candidate for an offline fallback. |
| **Identity-preserving image model (FLUX PuLID / InstantID), open weights, hosted API** | **Chosen.** ~$0.035 per image on fal.ai, so ~₹12 for four variants per user. Same technique the mockup used. Weights are open, so it can be self-hosted later. |

## Update 2026-10-18 (evening): keyless default
The user does not want any paid or keyed service. Default path is now **on-device**: ML Kit selfie
segmentation (free, offline) cuts the person out, a pure-Dart toon filter (`toon_filter.dart`)
flattens colours, inks outlines and composites onto a neon mountain backdrop; four style presets,
runs in a background isolate, photo never leaves the phone. The fal.ai HD renderer stays in code but
only appears as an "HD render" toggle when a build is made with a service configured. Expectation
set honestly: cartoon portrait, not the mockup's 3D render.

## What is built
- `AvatarGenerator` interface + `FalAvatarGenerator` (queue API: submit → poll → fetch), 4 variants per request, friendly error mapping, unit-tested with a fake transport.
- `PhotoAvatarScreen` (`/avatar/photo`): selfie from camera or gallery (downscaled to 768 px), then frame 4's customisation as **prompt attributes**: Outfit (4 presets), Hair Style (7, "Natural" keeps the photo's), Hair Color (7 swatches, "Natural" default), Accessories (5). Progress with elapsed seconds, 2×2 variant picker, "Generate again with these settings", save. Last used settings are remembered.
- **Full-body render (frame 3):** after a portrait is chosen, one more request with the same seed and a full-body prompt (`portrait_4_3`). Stored as `<stem>-full.png`; shown as the big preview on Choose Avatar and as the hero behind Profile Created. If it fails, the portrait alone is kept.
- Image avatars stored as 512 px PNG under app documents (`img:<file>` ids); `AvatarView`, `AvatarRing`, `MemberAvatar` render them everywhere, with the procedural drawing as fallback when the file is missing (other phones, before sync).
- Entry points: "Create from my photo" card on Choose Avatar; Profile edit and Settings → Edit avatar open the chooser.

## How to test today
```bash
flutter run -d 39091FDJH005W1 --dart-define=FAL_KEY=<key from fal.ai dashboard>
```
Without the define, the screen explains that the service is not configured and the button stays disabled.

## Remaining
- **Server proxy (with task 16):** a Cloud Function `POST /avatar/generate` that holds the key, rate-limits per user (e.g. 3 generations/day), strips EXIF, forwards to fal, and stores the chosen PNG in Storage so group members and the community see each other's avatars. Then build with `--dart-define=AVATAR_ENDPOINT=https://…/avatar/generate` and no key.
- Consent copy and privacy policy line: the photo is sent to a third-party renderer, not retained.
- Optional offline fallback: White-box Cartoonization TFLite (Apache-2.0) via `tflite_flutter`.
- Prompt tuning on real faces (skin tone fidelity, glasses, headscarves); keep `id_weight` 1.0 unless likeness drifts.
