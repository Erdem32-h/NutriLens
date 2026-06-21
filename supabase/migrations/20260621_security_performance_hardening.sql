-- Security & performance hardening (Supabase advisors audit, 2026-06-21)
--
-- Addresses:
--   - Orphan delete_account RPC callable by anon (app uses delete-account Edge Function)
--   - SECURITY DEFINER functions over-exposed to anon/authenticated
--   - product-images bucket listing via broad storage SELECT policy
--   - Missing search_path on trigger functions
--   - Missing scan_history UPDATE policy (upsert silently no-ops without it)
--   - Performance indexes for hot query paths

-- ---------------------------------------------------------------------------
-- 1. Remove orphan delete_account RPC (Edge Function is the supported path)
-- ---------------------------------------------------------------------------
drop function if exists public.delete_account();

-- ---------------------------------------------------------------------------
-- 2. Lock down SECURITY DEFINER EXECUTE grants
-- ---------------------------------------------------------------------------

-- Trigger-only helper — never callable via PostgREST
revoke all on function public.handle_new_user() from public, anon, authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.user_profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Monetization RPCs: authenticated users only (anon must not invoke)
revoke all on function public.check_and_increment_scan(uuid) from public, anon;
grant execute on function public.check_and_increment_scan(uuid) to authenticated;

revoke all on function public.grant_bonus_scan(uuid) from public, anon;
grant execute on function public.grant_bonus_scan(uuid) to authenticated;

-- Guest scan RPCs stay anon-accessible (by design)
revoke all on function public.check_and_increment_guest_scan(text) from public;
grant execute on function public.check_and_increment_guest_scan(text) to anon, authenticated;

revoke all on function public.peek_guest_scan(text) from public;
grant execute on function public.peek_guest_scan(text) to anon, authenticated;

-- Supabase scaffold helper, if present
do $$
begin
  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'rls_auto_enable'
  ) then
    execute 'revoke all on function public.rls_auto_enable() from public, anon, authenticated';
  end if;
end $$;

-- Community report counters: require signed-in caller
create or replace function public.increment_verified_count(product_id_param uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  update public.community_products
     set verified_count = coalesce(verified_count, 0) + 1
   where id = product_id_param;
end;
$$;

create or replace function public.increment_reported_count(product_id_param uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  update public.community_products
     set reported_count = coalesce(reported_count, 0) + 1
   where id = product_id_param;
end;
$$;

revoke all on function public.increment_verified_count(uuid) from public, anon;
grant execute on function public.increment_verified_count(uuid) to authenticated;

revoke all on function public.increment_reported_count(uuid) from public, anon;
grant execute on function public.increment_reported_count(uuid) to authenticated;

-- Read-only scan budget for UI badges (no increment)
create or replace function public.peek_scan(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_tier text;
  v_limit int;
  v_count int;
  v_bonus int;
begin
  if auth.uid() is null or auth.uid() <> p_user_id then
    return jsonb_build_object('remaining', 0, 'is_premium', false);
  end if;

  select subscription_tier, daily_scan_limit
    into v_tier, v_limit
    from public.user_profiles
    where id = p_user_id;

  if v_tier is null then
    v_tier := 'free';
    v_limit := 2;
  end if;

  if v_tier = 'premium' then
    return jsonb_build_object('remaining', -1, 'is_premium', true);
  end if;

  select scan_count, bonus_count
    into v_count, v_bonus
    from public.daily_scans
    where user_id = p_user_id and scan_date = current_date;

  v_count := coalesce(v_count, 0);
  v_bonus := coalesce(v_bonus, 0);

  return jsonb_build_object(
    'remaining', greatest(v_limit + v_bonus - v_count, 0),
    'is_premium', false
  );
end;
$$;

revoke all on function public.peek_scan(uuid) from public, anon;
grant execute on function public.peek_scan(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Fix search_path on HP score trigger (advisor: function_search_path_mutable)
-- ---------------------------------------------------------------------------
alter function public.recalculate_community_product_hp_score()
  set search_path = public, pg_temp;

-- ---------------------------------------------------------------------------
-- 4. RLS fixes — scan_history upsert needs UPDATE, not just INSERT
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'scan_history'
      and policyname = 'users_update_own_history'
  ) then
    create policy "users_update_own_history"
      on public.scan_history
      for update
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5. Storage — stop public bucket listing (direct public URLs still work)
-- ---------------------------------------------------------------------------
drop policy if exists "Public can read product images" on storage.objects;

-- Ensure authenticated upload + upsert still work (idempotent)
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Authenticated read own product images'
  ) then
    create policy "Authenticated read own product images"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id = 'product-images'
        and regexp_replace(
          split_part(split_part(name, '/', 2), '.', 1),
          '^[^_]+_',
          ''
        ) = auth.uid()::text
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Authenticated upload product images'
  ) then
    create policy "Authenticated upload product images"
      on storage.objects
      for insert
      to authenticated
      with check (bucket_id = 'product-images');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Authenticated update own product images'
  ) then
    create policy "Authenticated update own product images"
      on storage.objects
      for update
      to authenticated
      using (
        bucket_id = 'product-images'
        and regexp_replace(
          split_part(split_part(name, '/', 2), '.', 1),
          '^[^_]+_',
          ''
        ) = auth.uid()::text
      )
      with check (
        bucket_id = 'product-images'
        and regexp_replace(
          split_part(split_part(name, '/', 2), '.', 1),
          '^[^_]+_',
          ''
        ) = auth.uid()::text
      );
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 6. Performance indexes for hot paths
-- ---------------------------------------------------------------------------
create index if not exists additives_e_number_idx
  on public.additives (e_number);

create index if not exists guest_devices_updated_at_idx
  on public.guest_devices (updated_at);

create index if not exists product_reports_product_id_idx
  on public.product_reports (product_id);

create index if not exists product_reports_user_id_idx
  on public.product_reports (user_id);

create index if not exists daily_scans_user_date_idx
  on public.daily_scans (user_id, scan_date desc);
