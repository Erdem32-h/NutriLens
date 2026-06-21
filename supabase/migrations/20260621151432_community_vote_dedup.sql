-- Prevent community vote inflation (advisors audit follow-up, 2026-06-21).
--
-- Problem: increment_verified_count / increment_reported_count blindly did
-- +1 per call, so any authenticated user could inflate counters by calling
-- the RPC directly in a loop. product_reports had no per-user uniqueness.
--
-- Fix:
--   1. One report per (user, product) via a unique constraint.
--   2. Recompute counters FROM product_reports instead of incrementing, so
--      the RPCs are idempotent and abuse-proof even when called directly.
--
-- Client pairs with an upsert on product_reports (onConflict user_id,product_id)
-- in community_product_source.dart so repeat votes / flips update the row.

alter table public.product_reports
  add constraint product_reports_user_product_unique unique (user_id, product_id);

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

  update public.community_products c
     set verified_count = (
           select count(*) from public.product_reports r
           where r.product_id = product_id_param and r.action = 'verify'
         ),
         reported_count = (
           select count(*) from public.product_reports r
           where r.product_id = product_id_param and r.action = 'report_wrong'
         )
   where c.id = product_id_param;
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

  update public.community_products c
     set verified_count = (
           select count(*) from public.product_reports r
           where r.product_id = product_id_param and r.action = 'verify'
         ),
         reported_count = (
           select count(*) from public.product_reports r
           where r.product_id = product_id_param and r.action = 'report_wrong'
         )
   where c.id = product_id_param;
end;
$$;

-- Keep the locked-down grants from the security hardening migration.
revoke all on function public.increment_verified_count(uuid) from public, anon;
grant execute on function public.increment_verified_count(uuid) to authenticated;
revoke all on function public.increment_reported_count(uuid) from public, anon;
grant execute on function public.increment_reported_count(uuid) to authenticated;
