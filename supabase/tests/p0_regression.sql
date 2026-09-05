begin;
do $$
declare
  u uuid := '11111111-1111-4111-8111-111111111111';
  other_u uuid := '22222222-2222-4222-8222-222222222222';
  s text := 'dev:' || repeat('a', 64);
begin
  if has_function_privilege('anon', 'public.consume_ai_quota(text,integer)', 'execute')
    or has_function_privilege('authenticated', 'public.prepare_account_deletion(uuid)', 'execute')
    or has_function_privilege('anon', 'public.list_account_meal_photos(uuid)', 'execute') then
    raise exception 'Client can execute privileged helper';
  end if;
  for i in 1..30 loop
    if not public.consume_ai_quota(s, 100) then raise exception 'Early quota rejection'; end if;
  end loop;
  if public.consume_ai_quota(s, 100) then raise exception 'Quota exceeded'; end if;
  if (select requests from public.ai_request_quota where subject='global') <> 30 then
    raise exception 'Rejected request consumed global quota';
  end if;
  update public.ai_request_quota set window_started_at = now() - interval '2 hours' where subject=s;
  if not public.consume_ai_quota(s, 100) then raise exception 'Hourly refill failed'; end if;
  if public.consume_ai_quota('dev:' || repeat('b',64), 31) then
    raise exception 'Hash rotation bypasses global limit';
  end if;
  update public.ai_request_quota set window_started_at = now() - interval '2 days' where subject='global';
  if not public.consume_ai_quota(s, 100) then raise exception 'Daily refill failed'; end if;

  insert into auth.users(id) values (u), (other_u);
  insert into public.community_products values (1,u), (2,other_u);
  insert into public.product_reports values (1,u), (2,other_u);
  insert into public.analytics_events values (1,u), (2,other_u);
  insert into storage.objects values
    ('meal-photos', u::text || '/nested/meal.jpg', null, null),
    ('meal-photos', 'orphan.jpg', u, u::text),
    ('meal-photos', other_u::text || '/other.jpg', other_u, other_u::text),
    ('product-images', 'products/shared.jpg', u, u::text);
  if (select count(*) from public.list_account_meal_photos(u)) <> 2 then
    raise exception 'Photo lookup missed nested/orphan photo or selected another user';
  end if;
  perform public.prepare_account_deletion(u);
  perform public.prepare_account_deletion(u);
  delete from auth.users where id=u;
  if (select added_by from public.community_products where id=1) is not null
    or (select count(*) from public.community_products) <> 2 then
    raise exception 'Shared contributions lost or not detached';
  end if;
  if (select count(*) from public.product_reports) <> 1
    or (select count(*) from public.analytics_events) <> 1 then
    raise exception 'Wrong account data removed';
  end if;
  if exists(select 1 from storage.objects where bucket_id='product-images' and (owner is not null or owner_id is not null)) then
    raise exception 'Public image ownership not detached';
  end if;
end;
$$;
rollback;