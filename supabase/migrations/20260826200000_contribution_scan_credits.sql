-- Contribution scan credits: adding a genuinely new product to the community
-- database earns permanent scan credits, spent only after the daily free
-- allowance runs out.
--
-- Why permanent and not `daily_scans.bonus_count`: that counter is keyed by
-- (user_id, scan_date) and resets at midnight. Typing a barcode, an ingredient
-- list and a nutrition panel is real work; paying for it in scans that expire
-- tonight is not a trade anyone would take. Credits sit in user_profiles and
-- wait to be used.
--
-- Why a trigger and not a client call: `grant_bonus_scan` already shows what
-- happens when the client is trusted to say it earned something (see
-- 04-problems-open, server-side ad verification). Here the client can only
-- insert a product row; the database decides whether that earned anything.
--
-- Three gates, all necessary:
--   1. source = 'user_created' — the manual "add a product" flow only.
--      `autoImportFromApi` writes rows with added_by set too, so without this
--      every ordinary scan of an Open-Food-Facts-known barcode would mint
--      credits.
--   2. AFTER INSERT only, and community_products.barcode is UNIQUE — so a
--      barcode can be rewarded exactly once, globally, ever. An upsert that
--      updates an existing row fires UPDATE and pays nothing.
--   3. Completeness — name, a real ingredient list, and at least one nutrition
--      value. An empty shell with a made-up barcode earns nothing.
--
-- Residual trust: `source` is written by the client, so a modified client can
-- claim 'user_created'. The remaining cost of farming is inventing a unique
-- barcode and filling a real ingredient list per 5 credits, and every attempt
-- leaves a junk row — which is the open community_products vandalism problem,
-- not a new one. Revisit together with the edit-history/audit work.

alter table public.user_profiles
  add column if not exists scan_credits integer not null default 0;

comment on column public.user_profiles.scan_credits is
  'Permanent scan credits earned by contributing new products. Spent one at a '
  'time by check_and_increment_scan once the daily free allowance is used up. '
  'Granted only by grant_contribution_scan_credits().';

create or replace function public.grant_contribution_scan_credits()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  -- Credits per accepted contribution.
  c_reward constant integer := 5;
  has_nutrition boolean;
begin
  if new.added_by is null or new.source is distinct from 'user_created' then
    return new;
  end if;

  has_nutrition := jsonb_typeof(new.nutriments) = 'object'
    and exists (
      select 1
      from jsonb_each_text(new.nutriments) as n(key, value)
      where n.value is not null and n.value <> '' and n.value <> 'null'
    );

  if coalesce(length(trim(new.product_name)), 0) < 2
     or coalesce(length(trim(new.ingredients_text)), 0) < 10
     or not has_nutrition then
    return new;
  end if;

  update public.user_profiles
    set scan_credits = scan_credits + c_reward,
        updated_at = now()
    where id = new.added_by;

  return new;
end;
$$;

drop trigger if exists trg_grant_contribution_scan_credits on public.community_products;

create trigger trg_grant_contribution_scan_credits
  after insert on public.community_products
  for each row
  execute function public.grant_contribution_scan_credits();

-- check_and_increment_scan: unchanged except for the fallback at the end.
-- Once the daily allowance (limit + same-day bonus) is spent, one permanent
-- credit is consumed instead of refusing the scan.
create or replace function public.check_and_increment_scan(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tier text;
  v_limit int;
  v_count int;
  v_bonus int;
  v_credits int;
begin
  if auth.uid() is null or auth.uid() <> p_user_id then
    return jsonb_build_object('allowed', false, 'remaining', 0, 'is_premium', false);
  end if;

  select subscription_tier, daily_scan_limit
    into v_tier, v_limit
    from public.user_profiles
    where id = p_user_id;

  if v_tier is null then
    insert into public.user_profiles (id)
      values (p_user_id)
      on conflict (id) do nothing;
    v_tier := 'free';
    v_limit := 2;
  end if;

  if v_tier = 'premium' then
    return jsonb_build_object('allowed', true, 'remaining', -1, 'is_premium', true);
  end if;

  insert into public.daily_scans (user_id, scan_date, scan_count, bonus_count)
    values (p_user_id, current_date, 0, 0)
    on conflict (user_id, scan_date) do nothing;

  select scan_count, bonus_count
    into v_count, v_bonus
    from public.daily_scans
    where user_id = p_user_id and scan_date = current_date;

  if v_count < v_limit + v_bonus then
    update public.daily_scans
      set scan_count = scan_count + 1
      where user_id = p_user_id and scan_date = current_date;

    return jsonb_build_object(
      'allowed', true,
      'remaining', v_limit + v_bonus - v_count - 1,
      'is_premium', false
    );
  end if;

  -- Daily allowance spent. Fall back to earned credits.
  -- `for update` because two concurrent scans must not spend the same credit;
  -- the daily path above has a known benign race (see 04-problems-open) but a
  -- permanent balance is worth locking.
  select scan_credits
    into v_credits
    from public.user_profiles
    where id = p_user_id
    for update;

  if coalesce(v_credits, 0) > 0 then
    update public.user_profiles
      set scan_credits = scan_credits - 1
      where id = p_user_id;

    update public.daily_scans
      set scan_count = scan_count + 1
      where user_id = p_user_id and scan_date = current_date;

    return jsonb_build_object(
      'allowed', true,
      'remaining', v_credits - 1,
      'is_premium', false,
      'used_credit', true
    );
  end if;

  return jsonb_build_object('allowed', false, 'remaining', 0, 'is_premium', false);
end;
$$;
