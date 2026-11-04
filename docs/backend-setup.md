# Backend: Supabase

Project ref `ouwdljjioddctfoznsvc` (Tokyo pooler `aws-0-ap-northeast-1.pooler.supabase.com`). The database URL and
password live only in the git-ignored `.env`.

## What is in the database

| Table / view | Holds |
|---|---|
| `profiles` | one row per account (created by a trigger on sign-up): name, unique username, bio, town, avatar |
| `follows`, `blocks` | who follows / blocks whom |
| `posts`, `likes`, `comments`, `reports` | the community feed |
| `bookings` | every booking: programme, date, slot, party, price lines, total, payment ref, status, `operator_synced` |
| `feed_posts`, `profile_cards` | views with like / comment / follower counts and "liked / followed by me" |
| `booked_seats(program, date, slot)` | function returning seats taken on a slot, without exposing other visitors' bookings |
| storage `post-photos` | photos attached to posts, one folder per user |

Row-level security: anyone signed in reads profiles, posts, likes, comments, follows; you can only write your own
rows; bookings are visible only to their owner.

## Apply or reset

```
source .env
psql "$SUPABASE_DB_URL" -f supabase/schema.sql   # idempotent
psql "$SUPABASE_DB_URL" -f supabase/seed.sql     # recreates the 12 demo explorers (password: trailseek)
```

## Switching the app and website to cloud mode

Both need the project's **anon (public) key** from Supabase → Project Settings → API.

- App: put it in `supabase.env` (copy `supabase.env.example`) and build with `tools/build_apk.sh`.
- Website: `vercel env add NEXT_PUBLIC_SUPABASE_ANON_KEY production` (and `NEXT_PUBLIC_SUPABASE_URL`), then redeploy.

Authentication settings to check in the Supabase dashboard: Auth → Providers → Email (turn off "Confirm email" for
the closed pilot if visitors should log in right after sign-up), Auth → URL configuration → add
`https://trailseek.vercel.app` and `io.trailseek.app://login-callback`.
