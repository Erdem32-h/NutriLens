-- Rollback-only check for
-- 20261114040500_lock_entitlements_reports_daily_scans.sql.
-- Run in the Supabase SQL Editor AFTER applying the migration. It always ends
-- with an ERROR whose text is the result; the error rolls everything back,
-- nothing persists.
--
-- Expected:
--   tier=free limit=2 credits=0 name_edit=true   (client could not self-grant)
--   forged=blocked null_user=blocked own=ok      (reports are the caller's own)
--   today_kept=1 past_deleted=true               (today's scan counter survives)
--   scan_allowed=true credit_spent=true          (server paths still write)
do $do$
declare
  uid uuid; other uuid; pid uuid;
  v_tier text; v_limit int; v_credits int; v_name_ok boolean;
  v_forged text := 'ALLOWED'; v_null text := 'ALLOWED'; v_own text := 'failed';
  v_today int; v_past_gone boolean;
  v_scan jsonb; v_credits_after int;
begin
  select id into uid from auth.users order by created_at limit 1;
  select id into other from auth.users where id <> uid order by created_at limit 1;
  select id into pid from public.community_products order by created_at limit 1;

  -- Known starting point, written as postgres (the trigger lets it through).
  insert into public.user_profiles (id) values (uid) on conflict (id) do nothing;
  update public.user_profiles
     set subscription_tier = 'free', subscription_expires_at = null,
         daily_scan_limit = 2, scan_credits = 0
   where id = uid;
  delete from public.daily_scans where user_id = uid;
  insert into public.daily_scans (user_id, scan_date, scan_count, bonus_count)
    values (uid, current_date, 2, 0), (uid, current_date - 1, 2, 0);
  delete from public.product_reports where product_id = pid;

  perform set_config('request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';

  -- 1. Self-grant attempt; an ordinary column in the same statement must land.
  update public.user_profiles
     set subscription_tier = 'premium',
         subscription_expires_at = now() + interval '10 years',
         daily_scan_limit = 9999, scan_credits = 9999,
         display_name = 'locktest'
   where id = uid;

  -- 2. Reports under someone else's id, under no id, then honestly.
  begin
    insert into public.product_reports (product_id, user_id, action)
      values (pid, other, 'report_wrong');
  exception when insufficient_privilege then v_forged := 'blocked';
  end;
  begin
    insert into public.product_reports (product_id, user_id, action)
      values (pid, null, 'report_wrong');
  exception when insufficient_privilege then v_null := 'blocked';
  end;
  begin
    insert into public.product_reports (product_id, user_id, action)
      values (pid, uid, 'report_wrong');
    v_own := 'ok';
  exception when others then v_own := sqlerrm;
  end;

  -- 3. The app's "delete my data" statement.
  delete from public.daily_scans where user_id = uid;

  execute 'reset role';

  select subscription_tier, daily_scan_limit, scan_credits, display_name = 'locktest'
    into v_tier, v_limit, v_credits, v_name_ok
    from public.user_profiles where id = uid;
  select count(*) into v_today
    from public.daily_scans where user_id = uid and scan_date = current_date;
  select not exists (
    select 1 from public.daily_scans
     where user_id = uid and scan_date = current_date - 1
  ) into v_past_gone;

  -- 4. Server paths must still be able to write the locked columns: with the
  -- daily allowance spent (scan_count 2 of 2), the RPC has to spend a credit.
  update public.user_profiles set scan_credits = 1 where id = uid;
  execute 'set local role authenticated';
  v_scan := public.check_and_increment_scan(uid);
  execute 'reset role';
  select scan_credits into v_credits_after from public.user_profiles where id = uid;

  raise exception
    'RESULT tier=% limit=% credits=% name_edit=% | forged=% null_user=% own=% | today_kept=% past_deleted=% | scan_allowed=% credit_spent=%',
    v_tier, v_limit, v_credits, v_name_ok, v_forged, v_null, v_own,
    v_today, v_past_gone, v_scan->>'allowed', v_credits_after = 0;
end $do$;
