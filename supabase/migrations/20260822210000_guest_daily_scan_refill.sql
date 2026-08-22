-- Extends the guest scan model: after the original 5-scan lifetime burst is
-- spent, guests get a recurring daily allowance (2/day, matching the
-- registered free tier's own daily_scan_limit) instead of a hard lifetime
-- wall. Registration keeps its own value (cross-device sync, favorites,
-- premium purchase) but is no longer the only way to keep scanning at all —
-- the data behind this call showed the lifetime-5 wall was barely load-
-- bearing anyway (93% of guest devices never reached it).
--
-- Offline behavior for the daily phase is deliberately NOT extended with a
-- courtesy scan (unlike the lifetime phase's one-off goodwill scan) — once
-- past the lifetime burst, an unreachable server just blocks, same as the
-- registered free tier's daily quota already does with no offline fallback.
-- Simpler, and the abuse surface (clear-and-go-offline) stays exactly as
-- small as before: the client pins its local mirror at the lifetime cap the
-- moment it hears `phase: 'daily'` from either RPC and never spends from it
-- again (see GuestScanCounter / scanner_screen.dart).

alter table public.guest_devices
  add column if not exists daily_scan_date date,
  add column if not exists daily_scan_count int not null default 0;

create or replace function public.check_and_increment_guest_scan(
  p_device_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lifetime_limit constant int := 5;
  v_daily_limit constant int := 2;
  v_lifetime_count int;
  v_daily_date date;
  v_daily_count int;
begin
  -- Reject obviously bad hashes (a real SHA-256 hex is 64 chars).
  if p_device_hash is null or length(p_device_hash) < 16 then
    return jsonb_build_object('allowed', false, 'remaining', 0, 'phase', 'lifetime', 'error', 'bad_device');
  end if;

  insert into public.guest_devices (device_hash, scan_count)
  values (p_device_hash, 0)
  on conflict (device_hash) do nothing;

  -- Lock the row so concurrent scans from the same device can't double-spend.
  select scan_count, daily_scan_date, daily_scan_count
    into v_lifetime_count, v_daily_date, v_daily_count
    from public.guest_devices
   where device_hash = p_device_hash
   for update;

  -- Lifetime burst still has budget.
  if v_lifetime_count < v_lifetime_limit then
    update public.guest_devices
       set scan_count = scan_count + 1,
           updated_at = now()
     where device_hash = p_device_hash;

    return jsonb_build_object(
      'allowed', true,
      'remaining', v_lifetime_limit - (v_lifetime_count + 1),
      'phase', 'lifetime'
    );
  end if;

  -- Daily phase. Roll the bucket over if the stored date isn't today —
  -- `is distinct from` also treats a never-set (null) date as a rollover.
  if v_daily_date is distinct from current_date then
    v_daily_count := 0;
  end if;

  if v_daily_count >= v_daily_limit then
    -- Still stamp today's date so a stale null doesn't linger, but don't
    -- grant a scan.
    update public.guest_devices
       set daily_scan_date = current_date,
           daily_scan_count = v_daily_count,
           updated_at = now()
     where device_hash = p_device_hash;
    return jsonb_build_object('allowed', false, 'remaining', 0, 'phase', 'daily');
  end if;

  update public.guest_devices
     set daily_scan_date = current_date,
         daily_scan_count = v_daily_count + 1,
         updated_at = now()
   where device_hash = p_device_hash;

  return jsonb_build_object(
    'allowed', true,
    'remaining', v_daily_limit - (v_daily_count + 1),
    'phase', 'daily'
  );
end;
$$;

-- Read-only remaining budget for the scanner badge (no increment). Mirrors
-- the phase logic above but computes the day-rollover in-memory instead of
-- writing it, since a peek must never mutate state.
create or replace function public.peek_guest_scan(
  p_device_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lifetime_limit constant int := 5;
  v_daily_limit constant int := 2;
  v_lifetime_count int;
  v_daily_date date;
  v_daily_count int;
begin
  select scan_count, daily_scan_date, daily_scan_count
    into v_lifetime_count, v_daily_date, v_daily_count
    from public.guest_devices
   where device_hash = p_device_hash;

  v_lifetime_count := coalesce(v_lifetime_count, 0);
  v_daily_count := coalesce(v_daily_count, 0);

  if v_lifetime_count < v_lifetime_limit then
    return jsonb_build_object(
      'remaining', v_lifetime_limit - v_lifetime_count,
      'phase', 'lifetime'
    );
  end if;

  if v_daily_date is distinct from current_date then
    v_daily_count := 0;
  end if;

  return jsonb_build_object(
    'remaining', greatest(v_daily_limit - v_daily_count, 0),
    'phase', 'daily'
  );
end;
$$;

-- CREATE OR REPLACE FUNCTION preserves existing grants when the signature
-- is unchanged, so the anon/authenticated execute grants from the original
-- migration still apply — no re-grant needed here.
