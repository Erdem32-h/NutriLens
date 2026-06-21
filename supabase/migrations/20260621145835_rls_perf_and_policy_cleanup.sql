-- Supabase advisors audit (2026-06-21): performance hardening.
--
-- 1. auth_rls_initplan: wrap auth.uid()/auth.role() in scalar subselects so
--    they evaluate once per query instead of once per row.
-- 2. multiple_permissive_policies: drop duplicate user_profiles policies,
--    keeping one canonical policy per action.
-- 3. unindexed_foreign_keys: add covering index on community_products.added_by.
-- Semantics are preserved; only evaluation cost and duplicates change.

-- ── user_profiles: remove duplicate policies, keep one per action ─────────
drop policy if exists "Users can view own profile"   on public.user_profiles;
drop policy if exists "Users can update own profile" on public.user_profiles;

drop policy if exists "users_read_own_profile" on public.user_profiles;
create policy "users_read_own_profile" on public.user_profiles
  for select using ((select auth.uid()) = id);

drop policy if exists "users_update_own_profile" on public.user_profiles;
create policy "users_update_own_profile" on public.user_profiles
  for update using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

drop policy if exists "Users can insert own profile" on public.user_profiles;
create policy "Users can insert own profile" on public.user_profiles
  for insert with check ((select auth.uid()) = id);

-- ── blacklist ────────────────────────────────────────────────────────────
drop policy if exists "Users can view own blacklist" on public.blacklist;
create policy "Users can view own blacklist" on public.blacklist
  for select using ((select auth.uid()) = user_id);

drop policy if exists "Users can manage own blacklist" on public.blacklist;
create policy "Users can manage own blacklist" on public.blacklist
  for insert with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete own blacklist" on public.blacklist;
create policy "Users can delete own blacklist" on public.blacklist
  for delete using ((select auth.uid()) = user_id);

-- ── favorites ────────────────────────────────────────────────────────────
drop policy if exists "Users can view own favorites" on public.favorites;
create policy "Users can view own favorites" on public.favorites
  for select using ((select auth.uid()) = user_id);

drop policy if exists "Users can manage own favorites" on public.favorites;
create policy "Users can manage own favorites" on public.favorites
  for insert with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete own favorites" on public.favorites;
create policy "Users can delete own favorites" on public.favorites
  for delete using ((select auth.uid()) = user_id);

-- ── scan_history ─────────────────────────────────────────────────────────
drop policy if exists "Users can view own history" on public.scan_history;
create policy "Users can view own history" on public.scan_history
  for select using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert own history" on public.scan_history;
create policy "Users can insert own history" on public.scan_history
  for insert with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete own history" on public.scan_history;
create policy "Users can delete own history" on public.scan_history
  for delete using ((select auth.uid()) = user_id);

drop policy if exists "users_update_own_history" on public.scan_history;
create policy "users_update_own_history" on public.scan_history
  for update using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- ── daily_scans ──────────────────────────────────────────────────────────
drop policy if exists "users_read_own_scans" on public.daily_scans;
create policy "users_read_own_scans" on public.daily_scans
  for select using ((select auth.uid()) = user_id);

drop policy if exists "users_delete_own_daily_scans" on public.daily_scans;
create policy "users_delete_own_daily_scans" on public.daily_scans
  for delete using ((select auth.uid()) = user_id);

-- ── community_products (open-edit; performance only) ─────────────────────
drop policy if exists "community_products_update" on public.community_products;
create policy "community_products_update" on public.community_products
  for update to authenticated
  using ((select auth.uid()) is not null)
  with check ((select auth.uid()) is not null);

-- ── product_reports ──────────────────────────────────────────────────────
drop policy if exists "product_reports_insert" on public.product_reports;
create policy "product_reports_insert" on public.product_reports
  for insert with check ((select auth.role()) = 'authenticated');

-- ── unindexed FK: community_products.added_by ────────────────────────────
create index if not exists community_products_added_by_idx
  on public.community_products (added_by);
