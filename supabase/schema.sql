-- Trail Seek schema for Supabase (Postgres). Apply with:
--   psql "$SUPABASE_DB_URL" -f supabase/schema.sql
-- Idempotent: safe to re-run.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------- profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Trail Seeker',
  username text not null unique,
  email text,
  avatar_id text,
  bio text not null default '',
  home_town text not null default '',
  provider text not null default 'email',
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

create or replace function public.slugify_username(name text) returns text
language sql immutable as $$
  select coalesce(nullif(regexp_replace(lower(name), '[^a-z0-9_]', '', 'g'), ''), 'trail')
$$;

-- Every new auth user gets a profile with a unique username.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare base text; candidate text; n int := 0;
begin
  base := left(public.slugify_username(coalesce(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1))), 16);
  if length(base) < 3 then base := base || 'trail'; end if;
  candidate := base;
  while exists (select 1 from public.profiles where username = candidate) loop
    n := n + 1; candidate := base || (n + 1)::text;
  end loop;
  insert into public.profiles (id, display_name, username, email, provider)
  values (new.id,
          coalesce(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', 'Trail Seeker'),
          candidate, new.email, coalesce(new.raw_app_meta_data->>'provider', 'email'))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------- social
create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  followee_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);
create index if not exists follows_followee on public.follows(followee_id);

create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  name text not null default '',
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  text text not null check (length(text) <= 500),
  photos text[] not null default '{}',
  place_name text,
  lat double precision,
  lng double precision,
  activity_id text,
  created_at timestamptz not null default now(),
  edited_at timestamptz
);
create index if not exists posts_created on public.posts(created_at desc);

create table if not exists public.likes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);
create index if not exists likes_post on public.likes(post_id);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  text text not null check (length(text) <= 300),
  created_at timestamptz not null default now()
);
create index if not exists comments_post on public.comments(post_id, created_at);

create table if not exists public.reports (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

-- Report counts are readable by everyone (reports themselves are not).
create or replace view public.report_counts with (security_invoker = false) as
select post_id, count(*)::int as n from public.reports group by post_id;

-- Feed with counts; RLS of the underlying tables applies (security_invoker).
create or replace view public.feed_posts with (security_invoker = true) as
select p.id, p.author_id, pr.display_name as author_name, pr.avatar_id as author_avatar_id, pr.username as author_username,
       p.text, p.photos, p.place_name, p.lat, p.lng, p.activity_id, p.created_at, p.edited_at,
       (select count(*) from public.likes l where l.post_id = p.id)::int as like_count,
       (select count(*) from public.comments c where c.post_id = p.id)::int as comment_count,
       (select count(*) from public.report_counts r where r.post_id = p.id)::int as report_count,
       exists (select 1 from public.likes l where l.post_id = p.id and l.user_id = auth.uid()) as liked_by_me
from public.posts p join public.profiles pr on pr.id = p.author_id;

create or replace view public.profile_cards with (security_invoker = true) as
select pr.id, pr.display_name, pr.username, pr.avatar_id, pr.bio, pr.home_town, pr.is_demo, pr.created_at,
       (select count(*) from public.follows f where f.followee_id = pr.id)::int as followers,
       (select count(*) from public.follows f where f.follower_id = pr.id)::int as following,
       (select count(*) from public.posts p where p.author_id = pr.id)::int as posts,
       exists (select 1 from public.follows f where f.followee_id = pr.id and f.follower_id = auth.uid()) as followed_by_me
from public.profiles pr;

-- ---------------------------------------------------------------- bookings
create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  user_id uuid not null references public.profiles(id) on delete cascade,
  user_name text not null default '',
  program_id text not null,
  program_name text not null,
  destination_id text not null default '',
  destination_name text not null default '',
  cover_image text,
  visit_date date not null,
  slot text not null,
  party jsonb not null default '{}'::jsonb,
  lines jsonb not null default '[]'::jsonb,
  total integer not null default 0 check (total >= 0),
  status text not null default 'confirmed' check (status in ('confirmed', 'cancelled', 'completed')),
  payment_method text not null default '',
  payment_ref text not null default '',
  vehicle text,
  camera boolean not null default false,
  operator_synced boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists bookings_user on public.bookings(user_id, created_at desc);
create index if not exists bookings_slot on public.bookings(program_id, visit_date, slot);

-- Seats taken on a slot across all users (bookings themselves are private).
create or replace function public.booked_seats(p_program_id text, p_date date, p_slot text) returns int
language sql security definer set search_path = public stable as $$
  select coalesce(sum((party->>'adults')::int + (party->>'children')::int + (party->>'students')::int + (party->>'foreigners')::int), 0)::int
  from public.bookings
  where program_id = p_program_id and visit_date = p_date and slot = p_slot and status = 'confirmed'
$$;

-- ---------------------------------------------------------------- RLS
alter table public.profiles enable row level security;
alter table public.follows enable row level security;
alter table public.blocks enable row level security;
alter table public.posts enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;
alter table public.reports enable row level security;
alter table public.bookings enable row level security;

do $$ begin
  -- profiles
  drop policy if exists profiles_read on public.profiles;
  create policy profiles_read on public.profiles for select to authenticated using (true);
  drop policy if exists profiles_update_own on public.profiles;
  create policy profiles_update_own on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
  -- follows
  drop policy if exists follows_read on public.follows;
  create policy follows_read on public.follows for select to authenticated using (true);
  drop policy if exists follows_write_own on public.follows;
  create policy follows_write_own on public.follows for insert to authenticated with check (follower_id = auth.uid());
  drop policy if exists follows_delete_own on public.follows;
  create policy follows_delete_own on public.follows for delete to authenticated using (follower_id = auth.uid());
  -- blocks
  drop policy if exists blocks_own on public.blocks;
  create policy blocks_own on public.blocks for all to authenticated using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());
  -- posts
  drop policy if exists posts_read on public.posts;
  create policy posts_read on public.posts for select to authenticated using (true);
  drop policy if exists posts_insert_own on public.posts;
  create policy posts_insert_own on public.posts for insert to authenticated with check (author_id = auth.uid());
  drop policy if exists posts_update_own on public.posts;
  create policy posts_update_own on public.posts for update to authenticated using (author_id = auth.uid()) with check (author_id = auth.uid());
  drop policy if exists posts_delete_own on public.posts;
  create policy posts_delete_own on public.posts for delete to authenticated using (author_id = auth.uid());
  -- likes
  drop policy if exists likes_read on public.likes;
  create policy likes_read on public.likes for select to authenticated using (true);
  drop policy if exists likes_write_own on public.likes;
  create policy likes_write_own on public.likes for insert to authenticated with check (user_id = auth.uid());
  drop policy if exists likes_delete_own on public.likes;
  create policy likes_delete_own on public.likes for delete to authenticated using (user_id = auth.uid());
  -- comments
  drop policy if exists comments_read on public.comments;
  create policy comments_read on public.comments for select to authenticated using (true);
  drop policy if exists comments_insert_own on public.comments;
  create policy comments_insert_own on public.comments for insert to authenticated with check (author_id = auth.uid());
  drop policy if exists comments_delete_own on public.comments;
  create policy comments_delete_own on public.comments for delete to authenticated using (author_id = auth.uid());
  -- reports: write-only for users
  drop policy if exists reports_insert_own on public.reports;
  create policy reports_insert_own on public.reports for insert to authenticated with check (user_id = auth.uid());
  -- bookings: private to the owner
  drop policy if exists bookings_own on public.bookings;
  create policy bookings_own on public.bookings for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
end $$;

grant usage on schema public to anon, authenticated;
grant select on public.feed_posts, public.profile_cards, public.report_counts to authenticated;
grant select, insert, update, delete on public.profiles, public.follows, public.blocks, public.posts, public.likes, public.comments, public.reports, public.bookings to authenticated;
grant execute on function public.booked_seats(text, date, text) to authenticated;

-- ---------------------------------------------------------------- storage
insert into storage.buckets (id, name, public) values ('post-photos', 'post-photos', true)
on conflict (id) do update set public = true;
do $$ begin
  drop policy if exists "post photos read" on storage.objects;
  create policy "post photos read" on storage.objects for select using (bucket_id = 'post-photos');
  drop policy if exists "post photos upload own" on storage.objects;
  create policy "post photos upload own" on storage.objects for insert to authenticated
    with check (bucket_id = 'post-photos' and (storage.foldername(name))[1] = auth.uid()::text);
  drop policy if exists "post photos delete own" on storage.objects;
  create policy "post photos delete own" on storage.objects for delete to authenticated
    using (bucket_id = 'post-photos' and (storage.foldername(name))[1] = auth.uid()::text);
end $$;

-- ---------------------------------------------------------------- realtime
do $$ begin
  begin alter publication supabase_realtime add table public.posts; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.likes; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.comments; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.follows; exception when duplicate_object then null; end;
end $$;

-- ---------------------------------------------------------------- progression
alter table public.profiles add column if not exists xp integer not null default 0;
alter table public.profiles add column if not exists activity_count integer not null default 0;

-- Every completed trek / ride / coracle, as the app's ActivityRecord JSON.
create table if not exists public.activities (
  id text primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  data jsonb not null,
  ended_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index if not exists activities_user on public.activities(user_id, ended_at desc);
alter table public.activities enable row level security;
do $$ begin
  drop policy if exists activities_read on public.activities;
  create policy activities_read on public.activities for select to authenticated using (true);
  drop policy if exists activities_write_own on public.activities;
  create policy activities_write_own on public.activities for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
end $$;
grant select, insert, update, delete on public.activities to authenticated;

-- Leaderboard order: XP is computed by the app with its XP rules and stored on the profile.
drop view if exists public.profile_cards;
create view public.profile_cards with (security_invoker = true) as
select pr.id, pr.display_name, pr.username, pr.avatar_id, pr.bio, pr.home_town, pr.is_demo, pr.created_at, pr.xp, pr.activity_count,
       (select count(*) from public.follows f where f.followee_id = pr.id)::int as followers,
       (select count(*) from public.follows f where f.follower_id = pr.id)::int as following,
       (select count(*) from public.posts p where p.author_id = pr.id)::int as posts,
       exists (select 1 from public.follows f where f.followee_id = pr.id and f.follower_id = auth.uid()) as followed_by_me,
       (select count(*) + 1 from public.profiles o where o.xp > pr.xp)::int as rank
from public.profiles pr;
grant select on public.profile_cards to authenticated;

-- ------------------------------------------------------------ trail walks
-- Every finished trek uploads the walker's own path for that adventure.
-- Trails are learned on the phone from many walks (3+ different people on
-- the same line), so no map data is needed. walker_key is a one-way hash,
-- never the account id; the first and last 50 m are trimmed before upload.
create table if not exists public.trail_walks (
  id uuid primary key default gen_random_uuid(),
  adventure_id text not null,
  walker_key text not null,
  walked_at timestamptz not null default now(),
  points jsonb not null,
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists trail_walks_adventure on public.trail_walks (adventure_id, walked_at desc);
alter table public.trail_walks enable row level security;
do $$ begin
  drop policy if exists trail_walks_read on public.trail_walks;
  create policy trail_walks_read on public.trail_walks for select to authenticated using (true);
  drop policy if exists trail_walks_insert_own on public.trail_walks;
  create policy trail_walks_insert_own on public.trail_walks for insert to authenticated with check (owner_id = auth.uid());
end $$;
-- Readers see walks, not who walked them.
revoke select on public.trail_walks from authenticated;
grant select (id, adventure_id, walker_key, walked_at, points) on public.trail_walks to authenticated;
grant insert on public.trail_walks to authenticated;
