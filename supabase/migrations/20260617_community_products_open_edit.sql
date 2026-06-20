-- Community products are a collaborative TR corpus. Previously UPDATE was
-- restricted to the original creator (added_by = auth.uid()), which blocked
-- users from completing missing data (e.g. adding a product photo) on products
-- others had created: the client upsert turned into an UPDATE and RLS rejected
-- it ("veritabanına kaydedilemedi"). Open UPDATE to any authenticated user.
-- SELECT stays public; INSERT still requires the inserter to own the new row.
alter policy "community_products_update" on public.community_products
  using (auth.uid() is not null)
  with check (auth.uid() is not null);
