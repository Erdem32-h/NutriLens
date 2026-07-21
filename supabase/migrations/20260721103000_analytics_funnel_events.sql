-- Activation funnel instrumentation.
--
-- Context: 5000 installs produced 61 accounts and 31 guest devices, and of
-- those 61 accounts only 7 ever scanned and 0 ever favourited. Every one of
-- those numbers was reconstructed after the fact by joining domain tables
-- (profiles / scan_history / favorites), which can only show that a user
-- *finished* a step — never where they gave up. This adds the missing
-- intermediate steps.
--
-- Identity model mirrors `guest_devices`: the client sends
-- SHA-256(salt + ANDROID_ID | IDFV), so the raw OS id never leaves the
-- device. `user_id` is filled in only once the user authenticates, which is
-- what lets a single device be followed across the guest -> registered
-- boundary without ever storing PII.
--
-- Access model also mirrors `guest_devices`: RLS on, no grants, no policies.
-- Guests have no JWT, so writes go through an anon-executable SECURITY
-- DEFINER RPC and reads are service-role only. A leaked anon key can append
-- (rate-limited, validated) but can never read the table back.

create table if not exists public.analytics_events (
  id           bigserial primary key,
  device_hash  text        not null,
  user_id      uuid        null references auth.users(id) on delete set null,
  session_id   text        not null,
  event        text        not null,
  props        jsonb       not null default '{}'::jsonb,
  app_version  text        null,
  platform     text        null,
  locale       text        null,
  -- Client clock: subject to device time skew, but the only source for
  -- "how long did the user take between step N and N+1".
  occurred_at  timestamptz not null,
  -- Server clock: authoritative for ordering and retention. Diverges from
  -- occurred_at by however long an offline batch sat queued on-device.
  received_at  timestamptz not null default now()
);

alter table public.analytics_events enable row level security;
-- (no policies + no grants on purpose — RPC-only writes, service-role reads)

create index if not exists analytics_events_event_time_idx
  on public.analytics_events (event, occurred_at desc);
create index if not exists analytics_events_device_idx
  on public.analytics_events (device_hash, occurred_at desc);
create index if not exists analytics_events_user_idx
  on public.analytics_events (user_id, occurred_at desc)
  where user_id is not null;
create index if not exists analytics_events_session_idx
  on public.analytics_events (session_id, occurred_at);

-- O(1) per-device flood guard. Counting rows in analytics_events on every
-- insert would get slower exactly as the table grows; a rolling counter
-- stays constant-time.
create table if not exists public.analytics_device_quota (
  device_hash  text primary key,
  window_start timestamptz not null default now(),
  event_count  int not null default 0
);

alter table public.analytics_device_quota enable row level security;

-- Batch ingest. Returns the number of rows actually written, which is 0 when
-- the batch was dropped (bad device hash / over quota) — the client treats
-- any successful response as "delivered" and never retries, because a
-- retry storm is worse than a lost analytics event.
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
  -- Generous enough for a heavy session, low enough that a scripted
  -- flood hits the wall quickly.
  v_hourly_limit constant int := 1000;
  v_max_batch    constant int := 50;
  v_count        int;
  v_window       timestamptz;
  v_batch        int;
  v_written      int;
begin
  -- A real SHA-256 hex digest is 64 chars; anything shorter is a client bug
  -- or someone poking at the RPC.
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

  -- Roll the window forward rather than expiring rows on a schedule.
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
    -- Cap the payload so a buggy client can't write megabyte blobs.
    case when pg_column_size(i.props) > 2048 then '{}'::jsonb else i.props end,
    left(i.app_version, 32),
    left(i.platform, 16),
    left(i.locale, 8),
    -- Reject client clocks that are implausibly far out; a device with its
    -- date set to 2035 would otherwise poison every time-bucketed query.
    case
      when i.occurred_at is null then now()
      when i.occurred_at > now() + interval '1 day' then now()
      when i.occurred_at < now() - interval '30 days' then now()
      else i.occurred_at
    end
  from incoming i
  where i.event is not null
    -- Whitelist the shape, not the vocabulary: new event names ship with the
    -- client without needing a migration, but junk never lands.
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

revoke all on function public.track_events(text, uuid, jsonb) from public;
grant execute on function public.track_events(text, uuid, jsonb) to anon, authenticated;

-- Keep both tables out of the Data API entirely. New public tables are still
-- auto-exposed before the 2026-10-30 default change, so revoke explicitly.
revoke all on table public.analytics_events from anon, authenticated;
revoke all on table public.analytics_device_quota from anon, authenticated;
revoke all on sequence public.analytics_events_id_seq from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Reporting views (service-role / SQL editor only — never exposed to clients)
-- ---------------------------------------------------------------------------

-- Canonical step list. A step can be satisfied by any of several events
-- (e.g. a session starts via guest, login, or registration), which is why
-- this is an array rather than a single name.
create or replace view public.analytics_funnel_steps as
select * from (
  values
    (1, 'app_opened',        array['app_opened']),
    (2, 'onboarding_shown',  array['onboarding_shown']),
    (3, 'session_started',   array['guest_started', 'login_succeeded', 'register_succeeded']),
    (4, 'scanner_opened',    array['scanner_opened']),
    (5, 'camera_ready',      array['scan_camera_ready']),
    (6, 'barcode_detected',  array['scan_barcode_detected']),
    (7, 'product_viewed',    array['product_viewed']),
    (8, 'activated',         array['favorite_added', 'meal_added', 'product_shared'])
) as t(step_order, step, event_names);

-- The headline number: how many distinct devices ever reached each step.
-- `devices` is the denominator that matters, because a guest has no user_id
-- and guests are most of the funnel.
create or replace view public.analytics_funnel as
select
  s.step_order,
  s.step,
  count(distinct e.device_hash) as devices,
  count(distinct e.user_id)     as users,
  count(e.id)                   as events
from public.analytics_funnel_steps s
left join public.analytics_events e
  on e.event = any(s.event_names)
group by s.step_order, s.step
order by s.step_order;

-- Same funnel sliced by the day the device was first seen, so a fix shipped
-- on date X can be read as a change in the cohorts after X rather than as a
-- shift in the all-time average (which a large pre-fix cohort would mask).
create or replace view public.analytics_funnel_by_cohort as
with first_seen as (
  select device_hash, min(occurred_at)::date as cohort_day
    from public.analytics_events
   group by device_hash
)
select
  f.cohort_day,
  s.step_order,
  s.step,
  count(distinct e.device_hash) as devices
from first_seen f
join public.analytics_events e on e.device_hash = f.device_hash
join public.analytics_funnel_steps s on e.event = any(s.event_names)
group by f.cohort_day, s.step_order, s.step
order by f.cohort_day desc, s.step_order;

-- Where sessions die: the last step each device reached. Answers "what is
-- the single biggest drop-off right now" without eyeballing the whole table.
create or replace view public.analytics_last_step as
with device_step as (
  select e.device_hash, max(s.step_order) as last_step_order
    from public.analytics_events e
    join public.analytics_funnel_steps s on e.event = any(s.event_names)
   group by e.device_hash
)
select
  s.step_order,
  s.step as stalled_at,
  count(d.device_hash) as devices
from device_step d
join public.analytics_funnel_steps s on s.step_order = d.last_step_order
group by s.step_order, s.step
order by s.step_order;

revoke all on public.analytics_funnel_steps    from anon, authenticated;
revoke all on public.analytics_funnel          from anon, authenticated;
revoke all on public.analytics_funnel_by_cohort from anon, authenticated;
revoke all on public.analytics_last_step       from anon, authenticated;
