-- The v3 hardening migration (20260621_security_performance_hardening.sql)
-- set search_path on this trigger function, but v4
-- (20260826193810_hp_score_v4_nova_ceiling.sql) replaced the function body
-- with `create or replace function ... as $$ ... $$` and no `set
-- search_path` clause. CREATE OR REPLACE does not carry the old function's
-- config forward — it silently dropped the hardening, which is why the
-- advisor flagged `function_search_path_mutable` again.
alter function public.recalculate_community_product_hp_score()
  set search_path = public, pg_temp;
