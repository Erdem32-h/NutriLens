do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'daily_scans'
      and policyname = 'users_delete_own_daily_scans'
  ) then
    create policy "users_delete_own_daily_scans"
      on public.daily_scans
      for delete
      using (auth.uid() = user_id);
  end if;
end $$;
