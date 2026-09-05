-- ISOLATED TEST DATABASE ONLY. Minimal production-shaped dependencies.
create schema if not exists storage;
create table storage.objects (
  bucket_id text, name text, owner uuid, owner_id text
);
create table public.community_products (id integer primary key, added_by uuid references auth.users(id));
create table public.product_reports (id integer primary key, user_id uuid references auth.users(id));
create table public.analytics_events (id integer primary key, user_id uuid references auth.users(id));