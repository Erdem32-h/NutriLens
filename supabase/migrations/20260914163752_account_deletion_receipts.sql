-- Hash only: the random request capability is never persisted server-side.
-- No auth FK: the receipt must survive deletion. Keep for seven days.
create table public.account_deletion_receipts (
  user_id uuid not null,
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  completed_at timestamptz,
  expires_at timestamptz not null default now() + interval '7 days',
  primary key (user_id, request_hash)
);
alter table public.account_deletion_receipts enable row level security;
revoke all on public.account_deletion_receipts from public, anon, authenticated;
grant all on public.account_deletion_receipts to service_role;

create function public.begin_account_deletion_receipt(p_user_id uuid, p_request_hash text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  delete from public.account_deletion_receipts where expires_at < now();
  if not exists(select 1 from auth.users where id = p_user_id) then
    raise exception 'Account not found';
  end if;
  insert into public.account_deletion_receipts(user_id, request_hash)
    values(p_user_id, p_request_hash) on conflict do nothing;
end;
$$;
revoke all on function public.begin_account_deletion_receipt(uuid,text) from public, anon, authenticated;
grant execute on function public.begin_account_deletion_receipt(uuid,text) to service_role;

-- Completion commits in the SAME transaction as Auth deletion. If Auth
-- deletion rolls back, there cannot be a falsely successful receipt.
create function public.complete_account_deletion_receipts()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.account_deletion_receipts set completed_at = now()
    where user_id = old.id and expires_at > now();
  return old;
end;
$$;
revoke all on function public.complete_account_deletion_receipts() from public, anon, authenticated;
create trigger complete_account_deletion_receipts
after delete on auth.users for each row
execute function public.complete_account_deletion_receipts();