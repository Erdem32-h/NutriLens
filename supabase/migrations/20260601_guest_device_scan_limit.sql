-- Guest (un-registered) scan limit, keyed by a hashed device identifier so
-- clearing the app's cache/data no longer resets the free-scan budget.
--
-- The client sends SHA-256(salt + ANDROID_ID | IDFV); the raw identifier
-- never leaves the device. This table is intentionally NOT exposed via the
-- Data API: it has RLS on and NO grants/policies for anon/authenticated, so
-- the only access path is the SECURITY DEFINER functions below (which run as
-- the owner and bypass RLS). That stops a guest from reading/writing the
-- counter directly with the anon key.

create table if not exists public.guest_devices (
  device_hash text primary key,
  scan_count  int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.guest_devices enable row level security;
-- (no policies + no grants on purpose — RPC-only access)

-- Atomically check + consume one guest scan for a device.
-- Returns { allowed, remaining }.
create or replace function public.check_and_increment_guest_scan(
  p_device_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_limit constant int := 5;
  v_count int;
begin
  -- Reject obviously bad hashes (a real SHA-256 hex is 64 chars).
  if p_device_hash is null or length(p_device_hash) < 16 then
    return jsonb_build_object('allowed', false, 'remaining', 0, 'error', 'bad_device');
  end if;

  insert into public.guest_devices (device_hash, scan_count)
  values (p_device_hash, 0)
  on conflict (device_hash) do nothing;

  -- Lock the row so concurrent scans from the same device can't double-spend.
  select scan_count into v_count
    from public.guest_devices
   where device_hash = p_device_hash
   for update;

  if v_count >= v_limit then
    return jsonb_build_object('allowed', false, 'remaining', 0);
  end if;

  update public.guest_devices
     set scan_count = scan_count + 1,
         updated_at = now()
   where device_hash = p_device_hash;

  return jsonb_build_object('allowed', true, 'remaining', v_limit - (v_count + 1));
end;
$$;

-- Read-only remaining budget for the scanner badge (no increment).
create or replace function public.peek_guest_scan(
  p_device_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_limit constant int := 5;
  v_count int;
begin
  select scan_count into v_count
    from public.guest_devices
   where device_hash = p_device_hash;
  v_count := coalesce(v_count, 0);
  return jsonb_build_object('remaining', greatest(v_limit - v_count, 0), 'count', v_count);
end;
$$;

-- Lock down execution: only the app's anon/authenticated roles, nothing else.
revoke all on function public.check_and_increment_guest_scan(text) from public;
revoke all on function public.peek_guest_scan(text) from public;
grant execute on function public.check_and_increment_guest_scan(text) to anon, authenticated;
grant execute on function public.peek_guest_scan(text) to anon, authenticated;

-- Defense in depth: keep the table out of the Data API entirely. New public
-- tables are still auto-exposed before the 2026-10-30 default change, so
-- revoke explicitly — only the SECURITY DEFINER RPCs (running as owner) may
-- touch it. Direct PostgREST access now returns 42501.
revoke all on table public.guest_devices from anon, authenticated;
