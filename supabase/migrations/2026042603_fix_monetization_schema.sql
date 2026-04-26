alter table if exists public.user_profiles
  add column if not exists subscription_tier text not null default 'free'
    check (subscription_tier in ('free', 'premium')),
  add column if not exists rc_customer_id text,
  add column if not exists subscription_expires_at timestamptz,
  add column if not exists daily_scan_limit int not null default 2;

create or replace function public.check_and_increment_scan(p_user_id uuid)
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

  return jsonb_build_object('allowed', false, 'remaining', 0, 'is_premium', false);
end;
$$;

create or replace function public.grant_bonus_scan(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_bonus int;
begin
  if auth.uid() is null or auth.uid() <> p_user_id then
    return jsonb_build_object('granted', false, 'reason', 'not_authenticated');
  end if;

  insert into public.daily_scans (user_id, scan_date, scan_count, bonus_count)
    values (p_user_id, current_date, 0, 0)
    on conflict (user_id, scan_date) do nothing;

  select bonus_count
    into v_bonus
    from public.daily_scans
    where user_id = p_user_id and scan_date = current_date;

  if v_bonus >= 3 then
    return jsonb_build_object('granted', false, 'reason', 'max_bonus_reached');
  end if;

  update public.daily_scans
    set bonus_count = bonus_count + 1
    where user_id = p_user_id and scan_date = current_date;

  return jsonb_build_object('granted', true, 'bonus_remaining', 2 - v_bonus);
end;
$$;

