# 13 · Community feed

**Status:** in-progress (2026-10-18): local-first feed, compose, likes, comments, hashtags, follow, report, block and Nearby are done against `LocalCommunityRepository`; the Firestore/Storage half waits for task 16 · **Size:** L · **Depends on:** 01, 02, 16

## Goal
Frame 11: All / Following / Nearby feed; posts with avatar, name, time, place, text with hashtags, photo,
likes, comments, share.

## Scope
- Models: `Post { id, authorId, text, photoUrls, placeName, lat/lng?, activityId?, createdAt, likeCount, commentCount }`, `Comment`, `Follow`.
- Compose: text + up to 4 photos (compressed to ≤ 1600 px, ≤ 400 KB), optional attach of an activity (shows its route card), optional place.
- Feeds: All (global, newest), Following, Nearby (within 50 km of last known position, needs location permission).
- Interactions: like (optimistic), comment thread, share (deep link), report, block, delete own post.
- Hashtags rendered neon and tappable (search by tag).
- Moderation baseline: report reasons, hide reported content after 3 reports pending review, blocked users filtered client-side. Community guidelines screen linked from Settings.
- Offline: cached last 50 posts; compose queues when offline.

## Acceptance
- Posting with a photo appears in All within 2 s on a second device.
- Nearby shows nothing (and says why) when location is denied.
- No post from a blocked user is visible anywhere in the app.
- Image upload respects size limits (unit test on the compressor).

## Implementation notes
- Firestore collections `posts`, `posts/{id}/comments`, `follows`; Storage bucket `posts/`.
- Security rules: authors edit/delete own; likes via a `likes/{postId_userId}` doc to prevent double counting.
- Keep the feed UI usable before 16 by shipping a `LocalCommunityRepository` with seeded demo posts.
