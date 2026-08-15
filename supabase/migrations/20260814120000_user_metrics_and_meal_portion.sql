-- Kişisel kalori hedefi için vücut ölçüleri. Yeni tablo değil:
-- user_profiles zaten var, RLS'li ve handle_new_user ile otomatik oluşuyor.
alter table public.user_profiles
  add column if not exists sex text,
  add column if not exists birth_year integer,
  add column if not exists height_cm integer,
  add column if not exists weight_kg double precision,
  add column if not exists target_weight_kg double precision,
  add column if not exists activity_level text;

-- Öğün porsiyon gramajı: besin değerleri 100 g için değil, bu gramaj için
-- TOPLAM. Bulut senkronu bu bilgiyi kaybetmemeli.
alter table public.meal_entries
  add column if not exists portion_grams integer;
