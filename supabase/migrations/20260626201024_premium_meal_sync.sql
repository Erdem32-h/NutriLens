-- Premium meal cloud sync: meal_entries table + RLS + meal-photos storage.
-- Free users stay local-only; premium users' meals are mirrored here for
-- backup + multi-device restore. The client (auth uid) is the writer.

create table if not exists public.meal_entries (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  meal_name text not null,
  brand text,
  meal_type text not null,
  captured_at timestamptz not null,
  ingredients_text text,
  nutriments jsonb,
  calories double precision not null default 0,
  hp_score double precision,
  confidence double precision,
  ai_raw_json text,
  photo_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists meal_entries_user_captured_idx
  on public.meal_entries (user_id, captured_at desc);

alter table public.meal_entries enable row level security;

-- Per-user RLS. (select auth.uid()) is evaluated once per statement (perf).
drop policy if exists "meal_entries_select_own" on public.meal_entries;
create policy "meal_entries_select_own" on public.meal_entries
  for select using ((select auth.uid()) = user_id);

drop policy if exists "meal_entries_insert_own" on public.meal_entries;
create policy "meal_entries_insert_own" on public.meal_entries
  for insert with check ((select auth.uid()) = user_id);

drop policy if exists "meal_entries_update_own" on public.meal_entries;
create policy "meal_entries_update_own" on public.meal_entries
  for update using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "meal_entries_delete_own" on public.meal_entries;
create policy "meal_entries_delete_own" on public.meal_entries
  for delete using ((select auth.uid()) = user_id);

-- Private bucket for meal photo thumbnails.
insert into storage.buckets (id, name, public)
values ('meal-photos', 'meal-photos', false)
on conflict (id) do nothing;

-- Storage RLS: object path is "<user_id>/<meal_id>.jpg"; a user may only
-- touch objects under their own uid folder.
drop policy if exists "meal_photos_select_own" on storage.objects;
create policy "meal_photos_select_own" on storage.objects
  for select using (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "meal_photos_insert_own" on storage.objects;
create policy "meal_photos_insert_own" on storage.objects
  for insert with check (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "meal_photos_update_own" on storage.objects;
create policy "meal_photos_update_own" on storage.objects
  for update using (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "meal_photos_delete_own" on storage.objects;
create policy "meal_photos_delete_own" on storage.objects
  for delete using (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
