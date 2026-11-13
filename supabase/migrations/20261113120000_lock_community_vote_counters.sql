-- Lock community_products.reported_count / verified_count against direct
-- client writes.
--
-- Problem: community_products_update lets any signed-in user UPDATE any row
-- (needed for the edit flow), and the table-level UPDATE grant covers every
-- column. A user could set reported_count = 0 and un-hide a product that
-- 3+ users reported (the app hides rows at reported_count >= 3), or insert a
-- row with a negative count so it can never be hidden.
--
-- Fix: a BEFORE INSERT/UPDATE trigger that, for the client roles (anon,
-- authenticated), forces the counters to 0 on insert and keeps the old
-- values on update. The counters still change through
-- increment_reported_count / increment_verified_count: they are SECURITY
-- DEFINER owned by postgres, so current_user inside them is postgres and the
-- trigger lets their recompute through. service_role / dashboard edits also
-- pass, so a reviewed product can be un-hidden by hand.
--
-- Column-level REVOKE is not enough on its own: the table-level UPDATE grant
-- from 20261023173355_explicit_table_grants.sql still covers the columns.

create or replace function public.lock_community_vote_counters()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if current_user in ('anon', 'authenticated') then
    if tg_op = 'INSERT' then
      new.reported_count := 0;
      new.verified_count := 0;
    else
      new.reported_count := old.reported_count;
      new.verified_count := old.verified_count;
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.lock_community_vote_counters()
  from public, anon, authenticated;

drop trigger if exists trg_lock_community_vote_counters
  on public.community_products;

create trigger trg_lock_community_vote_counters
  before insert or update on public.community_products
  for each row execute function public.lock_community_vote_counters();
