-- track_events accepted p_user_id from the caller with no check against
-- auth.uid(), so any anon/authenticated caller could attribute analytics
-- events to an arbitrary user_id (including a real user's), poisoning the
-- activation funnel. Fall back to null unless the caller is authenticated
-- as that exact user; anon calls (auth.uid() is null) always get null.
create or replace function public.track_events(
  p_device_hash text,
  p_user_id     uuid,
  p_events      jsonb
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hourly_limit constant int := 1000;
  v_max_batch    constant int := 50;
  v_count        int;
  v_window       timestamptz;
  v_batch        int;
  v_written      int;
begin
  if p_user_id is not null and auth.uid() is distinct from p_user_id then
    p_user_id := null;
  end if;

  if p_device_hash is null or length(p_device_hash) < 16 then
    return 0;
  end if;

  if p_events is null or jsonb_typeof(p_events) <> 'array' then
    return 0;
  end if;

  v_batch := jsonb_array_length(p_events);
  if v_batch = 0 or v_batch > v_max_batch then
    return 0;
  end if;

  insert into public.analytics_device_quota (device_hash)
  values (p_device_hash)
  on conflict (device_hash) do nothing;

  select event_count, window_start
    into v_count, v_window
    from public.analytics_device_quota
   where device_hash = p_device_hash
   for update;

  if v_window < now() - interval '1 hour' then
    v_count  := 0;
    v_window := now();
  end if;

  if v_count + v_batch > v_hourly_limit then
    return 0;
  end if;

  with incoming as (
    select
      e.value ->> 'event'                              as event,
      coalesce(e.value -> 'props', '{}'::jsonb)        as props,
      e.value ->> 'session_id'                         as session_id,
      e.value ->> 'app_version'                        as app_version,
      e.value ->> 'platform'                           as platform,
      e.value ->> 'locale'                             as locale,
      (e.value ->> 'occurred_at')::timestamptz         as occurred_at
    from jsonb_array_elements(p_events) as e
  )
  insert into public.analytics_events (
    device_hash, user_id, session_id, event, props,
    app_version, platform, locale, occurred_at
  )
  select
    p_device_hash,
    p_user_id,
    i.session_id,
    i.event,
    case when pg_column_size(i.props) > 2048 then '{}'::jsonb else i.props end,
    left(i.app_version, 32),
    left(i.platform, 16),
    left(i.locale, 8),
    case
      when i.occurred_at is null then now()
      when i.occurred_at > now() + interval '1 day' then now()
      when i.occurred_at < now() - interval '30 days' then now()
      else i.occurred_at
    end
  from incoming i
  where i.event is not null
    and i.event ~ '^[a-z][a-z0-9_]{2,63}$'
    and i.session_id is not null
    and length(i.session_id) between 8 and 64
    and jsonb_typeof(i.props) = 'object';

  get diagnostics v_written = row_count;

  update public.analytics_device_quota
     set event_count  = v_count + v_written,
         window_start = v_window
   where device_hash = p_device_hash;

  return v_written;
end;
$$;
