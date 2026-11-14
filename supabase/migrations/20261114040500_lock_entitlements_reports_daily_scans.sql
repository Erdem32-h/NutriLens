-- Three client-writable paths that decide what a user is entitled to. Same
-- class as 20261113120000_lock_community_vote_counters.sql: RLS limits WHICH
-- rows a client may write, never which columns, and the table-level grants
-- from 20261023173355_explicit_table_grants.sql cover every column.
--
-- 1. user_profiles: users_update_own_profile lets a signed-in user UPDATE
--    their own row, entitlement columns included. One REST call
--    (PATCH user_profiles?id=eq.<own id> {"subscription_tier":"premium"})
--    made the account premium for free: check_and_increment_scan and the
--    app's supabasePremiumProvider both trust that column. daily_scan_limit
--    and scan_credits were writable the same way.
--
-- 2. product_reports: the INSERT policy only checked the role, not the
--    author. One account could insert three report_wrong rows under other
--    users' ids (readable from community_products.added_by), or any number
--    with user_id = NULL (the unique index does not dedupe NULLs), and hide
--    any product on its own. The SELECT policy also exposed every reporter's
--    user id to anon.
--
-- 3. daily_scans: users_delete_own_daily_scans let a user delete today's
--    counter row, so the next check_and_increment_scan started again from 0.
--
-- Fixes keep every shipped build working: the app never writes the locked
-- columns, sends its own id in product_reports, and its "delete my data"
-- flow issues a plain DELETE that now simply skips today's row.

-- ── 1. user_profiles entitlement columns ─────────────────────────────────
-- Client roles keep the old values on UPDATE and get the defaults on INSERT.
-- Legitimate writers are unaffected: rc-webhook runs as service_role, and
-- check_and_increment_scan / grant_contribution_scan_credits /
-- handle_new_user are SECURITY DEFINER owned by postgres, so current_user
-- inside them is postgres. This function must stay SECURITY INVOKER for that
-- test to mean anything.
create or replace function public.lock_user_profile_entitlements()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if current_user in ('anon', 'authenticated') then
    if tg_op = 'INSERT' then
      -- Column defaults (see 2026042603 / 20260826202624).
      new.subscription_tier := 'free';
      new.subscription_expires_at := null;
      new.daily_scan_limit := 2;
      new.scan_credits := 0;
      new.rc_customer_id := null;
    else
      new.subscription_tier := old.subscription_tier;
      new.subscription_expires_at := old.subscription_expires_at;
      new.daily_scan_limit := old.daily_scan_limit;
      new.scan_credits := old.scan_credits;
      new.rc_customer_id := old.rc_customer_id;
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.lock_user_profile_entitlements()
  from public, anon, authenticated;

drop trigger if exists trg_lock_user_profile_entitlements
  on public.user_profiles;

create trigger trg_lock_user_profile_entitlements
  before insert or update on public.user_profiles
  for each row execute function public.lock_user_profile_entitlements();

-- ── 2. product_reports: a vote is always the caller's own ────────────────
drop policy if exists "product_reports_insert" on public.product_reports;
create policy "product_reports_insert" on public.product_reports
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

-- The app never reads this table; the counters live on community_products
-- and are recomputed by the SECURITY DEFINER increment_* functions, which
-- RLS does not restrict.
drop policy if exists "product_reports_select" on public.product_reports;
create policy "product_reports_select" on public.product_reports
  for select to authenticated
  using ((select auth.uid()) = user_id);

-- ── 3. daily_scans: today's counter is not the user's to delete ──────────
-- Past days stay deletable so "delete my data" still clears the history;
-- current_date is the same clock check_and_increment_scan keys on.
drop policy if exists "users_delete_own_daily_scans" on public.daily_scans;
create policy "users_delete_own_daily_scans" on public.daily_scans
  for delete to authenticated
  using ((select auth.uid()) = user_id and scan_date < current_date);
