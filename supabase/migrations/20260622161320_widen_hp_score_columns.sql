-- HP score is valid in [0,100]. After the v3 re-score, clean products land
-- on exactly 100.00, but hp_score_at_scan / food_products.hp_score were
-- numeric(4,2) (max 99.99) → "numeric field overflow" on insert. In
-- addScanToHistory the failure was swallowed by a catch, so scans of
-- 100-scoring products never synced to Supabase (only local Drift).
-- Widen to numeric(5,2) which comfortably holds 100.00.

alter table public.scan_history  alter column hp_score_at_scan type numeric(5,2);
alter table public.food_products alter column hp_score        type numeric(5,2);
