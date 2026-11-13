-- Rollback-only check for 20261113120000_lock_community_vote_counters.sql.
-- Run in the Supabase SQL Editor. It always ends with an ERROR whose text is
-- the result; the error rolls everything back, nothing persists.
-- Expected: upd_kept=5  name_edit=true  rpc=1
do $do$
declare pid uuid; uid uuid; after_upd int; name_ok boolean; after_rpc int;
begin
  create or replace function public.lock_community_vote_counters()
  returns trigger language plpgsql set search_path = public, pg_temp as $f$
  begin
    if current_user in ('anon', 'authenticated') then
      if tg_op = 'INSERT' then
        new.reported_count := 0; new.verified_count := 0;
      else
        new.reported_count := old.reported_count; new.verified_count := old.verified_count;
      end if;
    end if;
    return new;
  end; $f$;
  drop trigger if exists trg_lock_community_vote_counters on public.community_products;
  create trigger trg_lock_community_vote_counters before insert or update on public.community_products
    for each row execute function public.lock_community_vote_counters();

  select id into pid from public.community_products order by created_at limit 1;
  select id into uid from auth.users limit 1;
  update public.community_products set reported_count = 5 where id = pid;

  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  update public.community_products
     set reported_count = 0, product_name = coalesce(product_name, '') || ' #locktest'
   where id = pid;
  execute 'reset role';
  select reported_count, product_name like '% #locktest' into after_upd, name_ok
    from public.community_products where id = pid;

  delete from public.product_reports where product_id = pid;
  update public.community_products set reported_count = 0 where id = pid;
  insert into public.product_reports(product_id, user_id, action) values (pid, uid, 'report_wrong');
  execute 'set local role authenticated';
  perform public.increment_reported_count(pid);
  execute 'reset role';
  select reported_count into after_rpc from public.community_products where id = pid;

  raise exception 'RESULT upd_kept=% (beklenen 5) name_edit=% (beklenen true) rpc=% (beklenen 1)',
    after_upd, name_ok, after_rpc;
end $do$;
