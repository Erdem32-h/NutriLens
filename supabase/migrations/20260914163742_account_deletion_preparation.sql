-- Private files are removed via Storage API, never by deleting metadata.
-- Shared product images survive account deletion without author ownership.
create or replace function public.list_account_meal_photos(p_user_id uuid)
returns table(name text)
language sql security definer set search_path = ''
as $$
  select o.name from storage.objects o
  where o.bucket_id = 'meal-photos'
    and (o.owner_id = p_user_id::text or o.owner = p_user_id
      or split_part(o.name, '/', 1) = p_user_id::text)
  order by o.name limit 100;
$$;

create or replace function public.prepare_account_deletion(p_user_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if p_user_id is null then raise exception 'user id required'; end if;
  update public.community_products set added_by = null where added_by = p_user_id;
  delete from public.product_reports where user_id = p_user_id;
  delete from public.analytics_events where user_id = p_user_id;
  -- Ownership only; bytes and public product URLs remain intact.
  update storage.objects set owner = null, owner_id = null
    where bucket_id = 'product-images'
      and (owner_id = p_user_id::text or owner = p_user_id);
end;
$$;

revoke all on function public.list_account_meal_photos(uuid) from public, anon, authenticated;
revoke all on function public.prepare_account_deletion(uuid) from public, anon, authenticated;
grant execute on function public.list_account_meal_photos(uuid) to service_role;
grant execute on function public.prepare_account_deletion(uuid) to service_role;