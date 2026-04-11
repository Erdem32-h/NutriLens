# Barkod Çözümleme & İçindekiler OCR Sistemi — Tasarım Dokümanı

**Tarih:** 2026-03-25
**Durum:** Onaylandı

---

## 1. Amaç

Çoklu API zinciri + İçindekiler OCR fallback + Topluluk katkılı veritabanı ile barkod çözümleme oranını maksimuma çıkarmak.

Skorun %50'si (Chemical Load) doğrudan içindekiler listesindeki E maddelerinden hesaplanıyor. Bu yüzden OCR fallback'i içindekiler listesi fotoğrafına odaklanır.

## 2. Kararlar

| Karar | Seçim | Gerekçe |
|-------|-------|---------|
| Zincir mimarisi | Strategy Pattern | Genişletilebilir, her kaynak bağımsız test edilebilir |
| OCR teknolojisi | Google ML Kit (cihaz üstü) | Ücretsiz, offline, Türkçe destekli |
| Kamera | image_picker | Ayrı UX, çerçeve + flash kontrol |
| Barcode Lookup API | upcitemdb.com (ücretsiz) | API key gerekmez, rate limited ama yeterli |
| Supabase tabloları | MCP ile doğrudan oluştur | Bağlı proje mevcut |
| Additives seed data | Ayrı iş olarak ele alınacak | Bu scope dışında |

## 3. Mimari — Strategy Pattern ile Çözümleme Zinciri

### 3.1 ProductSource Interface

```dart
abstract interface class ProductSource {
  String get name;        // "community", "off", "barcode_lookup"
  int get priority;       // Düşük = önce dene (0, 1, 2)
  Duration get timeout;   // Max bekleme süresi (5sn)

  Future<ProductEntity?> resolve(String barcode);
}
```

### 3.2 Concrete Sources

| Source | Priority | Timeout | Döndürdüğü |
|--------|----------|---------|-------------|
| CommunityProductSource | 0 | 5sn | Tam ürün (Supabase community_products) |
| OpenFoodFactsSource | 1 | 5sn | Tam ürün (mevcut remote datasource) |
| BarcodeLookupSource | 2 | 5sn | Kısmi (isim+marka, ingredients genelde yok) |

### 3.3 ProductResolver

```dart
class ProductResolver {
  final List<ProductSource> _sources; // Priority sıralı

  Future<ProductResolveResult> resolve(String barcode);
}

class ProductResolveResult {
  final ProductEntity? product;
  final String? resolvedBy;
  final bool hasIngredients;
  final List<String> triedSources;
}
```

### 3.4 Akış

```
Repository.getProduct(barcode)
  → Drift cache (fresh?) → return
  → ProductResolver.resolve(barcode)
      → CommunitySource.resolve()     → buldu? return
      → OFFSource.resolve()           → buldu? return
      → BarcodeLookupSource.resolve() → buldu? return
      → null → NotFoundFailure (UI OCR'a yönlendirir)
  → Başarılı → Drift cache + Supabase'e kaydet
```

## 4. OCR & İçindekiler Parser

### 4.1 Teknoloji

Google ML Kit — Text Recognition v2 (`google_mlkit_text_recognition` paketi)
- Cihaz üzerinde çalışır, internet gerekmez
- Latin harfler + Türkçe karakter desteği

### 4.2 Parser Pipeline

```
Ham OCR Metin
  → Adım 1: Temizlik
     "İçindekiler:" başlığını bul, "Besin Değerleri" ile kes
     Satır sonları → boşluk, çift boşluk → tek

  → Adım 2: E Kodu Regex (3 pattern)
     E\d{3}[a-z]?        → "E471", "E160a"
     E\s?\d{3}\s?[a-z]?  → "E 471"
     E-\d{3}             → "E-471"
     → Normalize: "E471" formatı

  → Adım 3: Türkçe İsim Match
     Additives DB'deki nameTr alanına karşı match
     "monosodyum glutamat" → E621

  → Adım 4: Additives DB Match + Confidence
     Her E kodu → riskLevel (1-5)
     Bulunamayan → unmatchedAdditives, riskLevel 3 varsayım
```

### 4.3 IngredientsParseResult

```dart
class IngredientsParseResult {
  final String cleanedText;
  final List<String> detectedAdditives;
  final List<String> unmatchedAdditives;
  final double confidence; // 0.0 - 1.0
}
```

### 4.4 Confidence Kuralları

- ≥3 E kodu → 0.8+
- 1-2 E kodu + anlamlı metin → 0.5-0.8
- 0 E kodu ama metin var → 0.3
- Hiç metin yok → 0.0

## 5. HP Score Calculator

### 5.1 İki Mod

| Mod | Kaynak | Hesaplanan | Gösterim |
|-----|--------|-----------|----------|
| calculateFull | OFF / Community | HP Score = 100 - (CL×0.50) - (RF×0.30) + (NF×0.20) | Tam HP Score gauge |
| calculatePartial | OCR-only | Sadece Chemical Load | "Kimyasal Yük Analizi" etiketi |

### 5.2 HpScoreResult

```dart
class HpScoreResult {
  final double hpScore;
  final double chemicalLoad;
  final double? riskFactor;
  final double? nutriFactor;
  final bool isPartial;
  final int gaugeLevel; // 1-5
}
```

### 5.3 E Kodu Normalizasyonu

OFF: `"en:e471"` → normalize → `"E471"` → Additives DB `eNumber` match

## 6. Veritabanı

### 6.1 Supabase: community_products (YENİ)

```sql
CREATE TABLE community_products (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  barcode TEXT NOT NULL UNIQUE,
  product_name TEXT,
  brand TEXT,
  image_url TEXT,
  ingredients_text TEXT,
  additives_tags JSONB DEFAULT '[]'::jsonb,
  nutriments JSONB DEFAULT '{}'::jsonb,
  nova_group INTEGER,
  nutriscore_grade TEXT,
  hp_score NUMERIC,
  hp_chemical_load NUMERIC,
  hp_risk_factor NUMERIC,
  hp_nutri_factor NUMERIC,
  source TEXT NOT NULL DEFAULT 'community',
  ingredients_photo_url TEXT,
  added_by UUID REFERENCES auth.users(id),
  verified_count INTEGER DEFAULT 0,
  reported_count INTEGER DEFAULT 0,
  is_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 6.2 Supabase: product_reports (YENİ)

```sql
CREATE TABLE product_reports (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id UUID REFERENCES community_products(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  action TEXT NOT NULL,
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 6.3 RLS

- Herkes okuyabilir
- Authenticated ekleyebilir
- Sadece ekleyen güncelleyebilir

### 6.4 Drift Lokal

Mevcut FoodProducts tablosuna dokunulmuyor. Tüm kaynaklardan gelen veri aynı `cacheProduct()` ile Drift'e yazılır.

## 7. UI Ekranları

| Ekran | Route | Tetikleyici |
|-------|-------|-------------|
| ProductNotFoundScreen | /product/:barcode/not-found | Zincirde bulunamadı |
| IngredientsCameraScreen | /product/:barcode/ocr | "Fotoğrafla" butonu |
| IngredientsVerificationScreen | /product/:barcode/verify | OCR başarılı |
| ManualIngredientsScreen | /product/:barcode/manual | "Manuel Gir" butonu |

### Yeni Widget'lar

- **AdditiveChip** — E kodu + risk seviyesi renk badge'i
- **ChemicalLoadGauge** — Kimyasal yük göstergesi (kısmi analiz)
- **CommunityBadge** — "Topluluk katkısı" etiketi

## 8. Riverpod Provider'lar (Yeni)

- `productResolverProvider` — Strategy resolver (source'ları inject eder)
- `ocrServiceProvider` — IngredientsOcrService instance
- `hpScoreCalculatorProvider` — HpScoreCalculator instance
- `communityDataSourceProvider` — Supabase community CRUD

## 9. Dosya Yapısı — Yeni/Güncellenecek Dosyalar

```
lib/
├── core/
│   └── services/
│       ├── ingredients_ocr_service.dart        ← YENİ
│       └── hp_score_calculator.dart             ← YENİ
├── features/product/
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── product_source.dart             ← YENİ: Interface + resolver
│   │   │   ├── community_product_source.dart   ← YENİ: Supabase source
│   │   │   ├── off_product_source.dart         ← YENİ: OFF wrapper (mevcut remote'u kullanır)
│   │   │   └── barcode_lookup_source.dart      ← YENİ: upcitemdb API
│   │   ├── models/
│   │   │   └── product_dto.dart                ← GÜNCELLE: fromCommunityRow, fromBarcodeLookup
│   │   └── repositories/
│   │       └── product_repository_impl.dart    ← GÜNCELLE: resolver kullan
│   ├── domain/
│   │   └── usecases/
│   │       └── submit_community_product_usecase.dart ← YENİ
│   └── presentation/
│       ├── providers/
│       │   ├── product_provider.dart           ← GÜNCELLE: yeni provider'lar
│       │   └── ocr_provider.dart               ← YENİ
│       ├── screens/
│       │   ├── product_detail_screen.dart      ← GÜNCELLE: kısmi analiz badge
│       │   ├── product_not_found_screen.dart   ← YENİ
│       │   ├── ingredients_camera_screen.dart  ← YENİ
│       │   ├── ingredients_verification_screen.dart ← YENİ
│       │   └── manual_ingredients_screen.dart  ← YENİ
│       └── widgets/
│           ├── additive_chip.dart              ← YENİ
│           ├── chemical_load_gauge.dart        ← YENİ
│           └── community_badge.dart            ← YENİ
```

## 10. Edge Cases

| Durum | Davranış |
|-------|----------|
| İnternet yok | Drift cache + OCR (cihaz üstü) çalışır |
| API timeout (>5sn) | Sessizce sonraki source'a geç |
| OCR E kodu bulamadı | "Doğal ürün olabilir" + manuel giriş öner |
| OCR metin bulamadı | "Daha net çekin" + tekrar çek |
| E kodu Additives DB'de yok | riskLevel 3 varsay, unmatchedAdditives'e ekle |
| BarcodeLookup sadece isim döndü | İsmi kaydet, OCR'a yönlendir |
| Sahte veri girişi | verified_count / reported_count, 3+ report → gizle |

## 11. Paket Gereksinimleri

```yaml
# YENİ EKLENECEK
google_mlkit_text_recognition: ^0.14.0
image_picker: ^1.1.0
```

## 12. Uygulama Fazları

1. **Faz 1:** HP Score Calculator + Supabase tabloları
2. **Faz 2:** Strategy Pattern çözümleme zinciri
3. **Faz 3:** OCR sistemi (ML Kit + parser)
4. **Faz 4:** UI ekranları + router
5. **Faz 5:** Topluluk doğrulama + polish
