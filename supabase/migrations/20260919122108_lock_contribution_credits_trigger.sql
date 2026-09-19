-- grant_contribution_scan_credits() is a trigger-only function (returns
-- trigger, fired by community_products AFTER INSERT). It never needed a
-- direct EXECUTE grant, unlike handle_new_user() which got the same
-- lockdown in 20260621_security_performance_hardening.sql. Postgres already
-- refuses to call a `returns trigger` function outside trigger context, so
-- this closes the advisor finding (anon/authenticated SECURITY DEFINER
-- exposure) without changing behavior — trigger firing does not check
-- EXECUTE privileges.
revoke all on function public.grant_contribution_scan_credits()
  from public, anon, authenticated;
