-- Canonical category for same-category "healthier alternative" matching.
-- Populated by the client (Gemini classify / dropdown for user products,
-- OFF tag mapping for imported ones). Index supports the alternatives query
-- (category = X AND hp_score > current ORDER BY hp_score DESC).
alter table public.community_products
  add column if not exists category text;

create index if not exists community_products_category_hp_idx
  on public.community_products (category, hp_score desc);
