-- Abuse quota, separate from product scan allowances (old mobile versions
-- already debit those before calling AI). Only Edge service_role can debit.
create table public.ai_request_quota (
  subject text primary key,
  window_started_at timestamptz not null,
  requests integer not null check (requests >= 0)
);
alter table public.ai_request_quota enable row level security;
revoke all on public.ai_request_quota from public, anon, authenticated;
grant all on public.ai_request_quota to service_role;
create index ai_request_quota_window_idx on public.ai_request_quota(window_started_at);

create or replace function public.consume_ai_quota(
  p_subject text, p_global_daily_limit integer
) returns boolean
language plpgsql security definer set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_day timestamptz := date_trunc('day', v_now at time zone 'UTC') at time zone 'UTC';
  v_global public.ai_request_quota%rowtype;
  v_subject public.ai_request_quota%rowtype;
begin
  if p_subject is null or p_subject !~ '^(user:[0-9a-f-]{36}|dev:[0-9a-f]{64})$'
     or p_global_daily_limit is null or p_global_daily_limit not between 1 and 100000 then
    raise exception 'Invalid quota arguments';
  end if;
  -- The single global row serializes admission across all Edge instances.
  -- Always lock global before subject, avoiding lock-order deadlocks.
  insert into public.ai_request_quota values ('global', v_day, 0)
    on conflict do nothing;
  select * into v_global from public.ai_request_quota where subject = 'global' for update;
  if v_global.window_started_at < v_day then
    update public.ai_request_quota set window_started_at = v_day, requests = 0 where subject = 'global';
    v_global.requests := 0;
  end if;
  if v_global.requests >= p_global_daily_limit then return false; end if;

  insert into public.ai_request_quota values (p_subject, v_now, 0)
    on conflict do nothing;
  select * into v_subject from public.ai_request_quota where subject = p_subject for update;
  if v_subject.window_started_at <= v_now - interval '1 hour' then
    update public.ai_request_quota set window_started_at = v_now, requests = 0 where subject = p_subject;
    v_subject.requests := 0;
  end if;
  if v_subject.requests >= 30 then return false; end if;
  update public.ai_request_quota set requests = requests + 1 where subject in ('global', p_subject);
  -- Bound retention/cardinality even if callers rotate guest hashes.
  delete from public.ai_request_quota
    where subject <> 'global' and window_started_at < v_now - interval '2 days';
  return true;
end;
$$;
revoke all on function public.consume_ai_quota(text, integer) from public, anon, authenticated;
grant execute on function public.consume_ai_quota(text, integer) to service_role;