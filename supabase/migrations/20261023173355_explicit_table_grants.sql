-- Supabase 2026-10-30'dan itibaren public şemadaki yeni tablolara Data API yetkisini
-- otomatik vermiyor. Bu, migration'lardan sıfırdan kurulan şemaları da kapsar
-- (supabase db reset, preview branch, yeni proje): o ortamlarda bu dosya olmadan
-- supabase-js / PostgREST "permission denied" döner.
--
-- Canlıda etkisizdir: GRANT mevcut yetkiyi daraltmaz. Erişimin asıl kapısı RLS'tir.
-- Yetkiler 2026-10-23'te canlı katalogdan üretildi (G-018):
--   authenticated, service_role -> canlıdaki yetkinin aynısı
--   anon -> yalnızca anon/public rolüne policy'si olan komutlar
-- Sunucuya özel tablolar (account_deletion_receipts, ai_request_quota, analytics_*,
-- guest_devices) ve analytics view'ları bilinçli olarak yalnızca service_role'de.
--
-- Kural: bundan sonra her CREATE TABLE, kendi GRANT'ini aynı migration'da içerir.

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  public.additives, public.allergens, public.blacklist, public.community_products,
  public.counterfeit_products, public.daily_scans, public.favorites, public.food_products,
  public.meal_entries, public.product_reports, public.scan_history, public.user_profiles
TO authenticated, service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  public.account_deletion_receipts, public.ai_request_quota, public.analytics_device_quota,
  public.analytics_events, public.analytics_funnel, public.analytics_funnel_by_cohort,
  public.analytics_funnel_steps, public.analytics_last_step, public.guest_devices
TO service_role;
GRANT SELECT, USAGE ON SEQUENCE public.analytics_events_id_seq TO service_role;

GRANT SELECT ON TABLE public.community_products TO anon;
GRANT SELECT, DELETE ON TABLE public.daily_scans TO anon;
GRANT SELECT, INSERT ON TABLE public.product_reports TO anon;
GRANT SELECT, INSERT, DELETE ON TABLE public.blacklist, public.favorites TO anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.user_profiles TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.meal_entries, public.scan_history TO anon;
