# NutriLens Monetization Design

**Date:** 2026-04-04
**Status:** Approved

## Overview

NutriLens'e üç gelir kanalı eklenir: abonelik (RevenueCat), reklam (AdMob), ve freemium tarama limiti. Server-side kontrol ile hack koruması sağlanır.

## Decisions

| Karar | Seçim | Sebep |
|-------|-------|-------|
| Platform | Android + iOS | Maksimum erişim |
| Ödeme | RevenueCat | Tek SDK, cross-platform, $2.5K'ya kadar ücretsiz |
| Abonelik planları | Aylık + Yıllık | Yıllık ~%40 indirim ile uzun vadeli bağlılık |
| Reklam | AdMob (Banner + Rewarded) | Banner sürekli gelir, Rewarded kullanıcı dostu |
| Tarama limiti | Günde 2 (barkod + AI birlikte) | Basit, anlaşılır |
| Limit kontrolü | Server-side (Supabase RPC) | Hack koruması, zaten network gerekli |

## Tier Karşılaştırması

| Özellik | Free | Premium |
|---------|------|---------|
| Günlük tarama | 2 (+ max 3 ödüllü reklam) | Sınırsız |
| Banner reklam | Var | Yok |
| AI tarama | 2 hak dahilinde | Sınırsız |
| Geçmiş/Favoriler | Tam erişim | Tam erişim |
| Sağlık filtreleri | Tam erişim | Tam erişim |

## 1. Veritabanı Şeması

### Yeni tablo: `user_profiles`

```sql
CREATE TABLE user_profiles (
  id                      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  subscription_tier       TEXT NOT NULL DEFAULT 'free' CHECK (subscription_tier IN ('free', 'premium')),
  rc_customer_id          TEXT,
  subscription_expires_at TIMESTAMPTZ,
  daily_scan_limit        INT NOT NULL DEFAULT 2,
  created_at              TIMESTAMPTZ DEFAULT now(),
  updated_at              TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Users can read/update only own profile
CREATE POLICY "users_read_own" ON user_profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "users_update_own" ON user_profiles FOR UPDATE USING (auth.uid() = id);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_profiles (id) VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
```

### Yeni tablo: `daily_scans`

```sql
CREATE TABLE daily_scans (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  scan_date   DATE NOT NULL DEFAULT CURRENT_DATE,
  scan_count  INT NOT NULL DEFAULT 0,
  bonus_count INT NOT NULL DEFAULT 0,
  UNIQUE(user_id, scan_date)
);

ALTER TABLE daily_scans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_read_own_scans" ON daily_scans FOR SELECT USING (auth.uid() = user_id);
```

### RPC: `check_and_increment_scan`

```sql
CREATE OR REPLACE FUNCTION check_and_increment_scan(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_tier TEXT;
  v_limit INT;
  v_count INT;
  v_bonus INT;
BEGIN
  SELECT subscription_tier, daily_scan_limit
    INTO v_tier, v_limit
    FROM user_profiles WHERE id = p_user_id;

  IF v_tier = 'premium' THEN
    RETURN jsonb_build_object('allowed', true, 'remaining', -1, 'is_premium', true);
  END IF;

  INSERT INTO daily_scans (user_id, scan_date, scan_count, bonus_count)
    VALUES (p_user_id, CURRENT_DATE, 0, 0)
    ON CONFLICT (user_id, scan_date) DO NOTHING;

  SELECT scan_count, bonus_count INTO v_count, v_bonus
    FROM daily_scans WHERE user_id = p_user_id AND scan_date = CURRENT_DATE;

  IF v_count < v_limit + v_bonus THEN
    UPDATE daily_scans SET scan_count = scan_count + 1
      WHERE user_id = p_user_id AND scan_date = CURRENT_DATE;
    RETURN jsonb_build_object(
      'allowed', true,
      'remaining', v_limit + v_bonus - v_count - 1,
      'is_premium', false
    );
  END IF;

  RETURN jsonb_build_object('allowed', false, 'remaining', 0, 'is_premium', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### RPC: `grant_bonus_scan`

```sql
CREATE OR REPLACE FUNCTION grant_bonus_scan(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_bonus INT;
BEGIN
  INSERT INTO daily_scans (user_id, scan_date, scan_count, bonus_count)
    VALUES (p_user_id, CURRENT_DATE, 0, 0)
    ON CONFLICT (user_id, scan_date) DO NOTHING;

  SELECT bonus_count INTO v_bonus
    FROM daily_scans WHERE user_id = p_user_id AND scan_date = CURRENT_DATE;

  IF v_bonus >= 3 THEN
    RETURN jsonb_build_object('granted', false, 'reason', 'max_bonus_reached');
  END IF;

  UPDATE daily_scans SET bonus_count = bonus_count + 1
    WHERE user_id = p_user_id AND scan_date = CURRENT_DATE;

  RETURN jsonb_build_object('granted', true, 'bonus_remaining', 2 - v_bonus);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## 2. Abonelik Katmanı (RevenueCat)

### Flutter Dosya Yapısı

```
lib/core/services/
├── subscription_service.dart      -- Abstract + RevenueCat impl
├── scan_limit_service.dart        -- Supabase RPC wrapper

lib/core/providers/
├── subscription_provider.dart     -- Riverpod providers

lib/features/premium/
├── presentation/
│   ├── screens/
│   │   └── paywall_screen.dart    -- Plan seçim ekranı
│   └── widgets/
│       ├── plan_card.dart         -- Fiyat kartı
│       └── scan_limit_banner.dart -- Kalan hak gösterimi
```

### Abonelik Akışı

1. Uygulama açılışı → `Purchases.configure(apiKey)` + `Purchases.logIn(userId)`
2. `CustomerInfo` stream dinlenir → tier değişikliği Supabase'e sync
3. Satın alma → `Purchases.purchasePackage()` → RevenueCat webhook → Supabase güncelle
4. Subscription expire → webhook EXPIRATION → tier = 'free'

### RevenueCat Webhook Edge Function

```
supabase/functions/rc-webhook/index.ts

Events handled:
- INITIAL_PURCHASE    → tier = 'premium', expires_at = event date
- RENEWAL             → expires_at güncelle
- CANCELLATION        → expires_at güncelle (süre sonuna kadar premium kalır)
- EXPIRATION          → tier = 'free', expires_at = null
```

## 3. Reklam Entegrasyonu (AdMob)

### Dosya Yapısı

```
lib/core/services/
├── ad_service.dart              -- AdMob init, load, show, dispose

lib/core/widgets/
├── ad_banner_widget.dart        -- Koşullu banner (free only)

lib/core/constants/
├── ad_constants.dart            -- Test + prod ad unit ID'leri
```

### Reklam Kuralları

- **Banner**: Scanner, History, Favorites ekranlarında bottom nav üstünde. Sadece free.
- **Rewarded**: Günlük hak bittiğinde ScanLimitSheet'te. Max 3/gün.
- **Premium**: Hiçbir reklam gösterilmez.

### Ad Unit ID Yönetimi

Test ID'leri kodda sabit, prod ID'leri `.env`'den okunur. `kDebugMode` ile otomatik seçim.

## 4. UI Değişiklikleri

### Yeni Ekranlar

1. **PaywallScreen** — Aylık/Yıllık plan kartları, özellik listesi, restore butonu
2. **ScanLimitSheet** — Bottom sheet: "Premium'a Geç" + "Reklam İzle" + "Kapat"

### Mevcut Ekran Güncellemeleri

1. **Scanner Screen** — Tarama öncesi hak kontrolü, kalan hak badge, alt banner
2. **History/Favorites** — Alt banner (free only)
3. **Profile Screen** — Tier badge, "Premium'a Geç" / "Aboneliği Yönet" butonu
4. **App Shell** — Banner reklam alanı bottom nav üstünde (free only)

### Tarama Akışı

```
Tara butonu → check_and_increment_scan RPC
  ├── allowed + premium → tarama (reklamsız)
  ├── allowed + free → tarama (banner reklamlı, kalan hak göster)
  └── not allowed → ScanLimitSheet
       ├── Premium'a Geç → PaywallScreen
       ├── Reklam İzle → Rewarded → grant_bonus_scan → tarama
       └── Kapat → geri
```

## 5. Güvenlik

- Tarama limiti server-side (Supabase RPC, SECURITY DEFINER)
- RevenueCat webhook imza doğrulaması
- RLS: kullanıcılar sadece kendi profilini okur/günceller
- Ad unit ID'leri .env'de, repo'ya girmez
- Receipt validation RevenueCat tarafında yapılır

## 6. Bağımlılıklar

```yaml
# pubspec.yaml'a eklenecek
purchases_flutter: ^8.0.0    # RevenueCat SDK
google_mobile_ads: ^5.3.0    # AdMob SDK
```
