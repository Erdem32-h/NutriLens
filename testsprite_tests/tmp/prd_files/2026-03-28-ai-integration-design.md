# NutriLens AI Integration Design

**Date:** 2026-03-28
**Status:** Approved

## Summary

NutriLens'e Gemini 2.5 Flash tabanlı AI desteği eklenmesi. Supabase Edge Function proxy ile güvenli API erişimi. Üç ana kullanım alanı: OCR iyileştirme, besin değeri yapılandırma, barkodssuz yemek tanıma.

## Decisions

| Karar | Seçim | Gerekce |
|-------|-------|---------|
| AI Modeli | Gemini 2.5 Flash | Hızlı, vision destekli, ücretsiz tier yeterli |
| Mimari | D: ML Kit (cihazda) + Gemini (API) | OCR hızlı/ücretsiz, AI sadece iyileştirme için |
| API Key güvenliği | Supabase Edge Function proxy | Rate limiting, kullanıcı kota, key sunucuda |
| Scanner UI | İki modlu (Barkod / AI Analiz) | Kamera zaten açık, doğal geçiş |
| Sonuç ekranı | Detaylı + kayıt | Kalori, makrolar, HP gauge, geçmişe kaydet |
| OCR iyileştirme UX | Sessiz (otomatik) | Ekstra adım yok, hata varsa fallback |
| Barkodssuz veri modeli | Sanal barkod (ai_ prefix) | Mevcut sistem değişmeden çalışır |

## Architecture

```
Flutter App
  ├── ML Kit (on-device) ──→ Raw OCR text
  │                              │
  ├── GeminiAiService ───────────┤
  │   ├── improveIngredientsOcr()│  raw text → cleaned text
  │   ├── improveNutritionOcr()  │  raw text → structured JSON
  │   └── recognizeFood()        │  image → food analysis
  │                              │
  └────── HTTPS ─────────────────▼
                    Supabase Edge Function (gemini-proxy)
                      ├── Auth token validation
                      ├── Rate limiting (30 req/hr/user)
                      └── Gemini 2.5 Flash API call
```

## Edge Function: gemini-proxy

**Single endpoint, 3 actions:**

```
POST /gemini-proxy
Authorization: Bearer <supabase_auth_token>

Body: {
  "action": "ocr_ingredients" | "ocr_nutrition" | "food_recognition",
  "payload": {
    "text": "...",
    "image_base64": "..."
  }
}
```

### Prompts

**ocr_ingredients:**
```
Sen bir gıda etiketi uzmanısın. Aşağıdaki metin bir gıda ürününün
içindekiler listesinin OCR çıktısıdır. OCR hataları içerebilir.

Görevlerin:
1. OCR hatalarını düzelt (karakter karışıklıkları, eksik harfler)
2. Türkçe içerik varsa Türkçeyi tercih et
3. İngilizce ise Türkçeye çevir
4. Temiz, virgülle ayrılmış içindekiler listesi döndür

OCR metni: {text}

Sadece düzeltilmiş içindekiler listesini döndür, başka açıklama yazma.
```

**ocr_nutrition:**
```
Sen bir gıda etiketi uzmanısın. Aşağıdaki metin bir besin değerleri
tablosunun OCR çıktısıdır.

Görevlerin:
1. OCR hatalarını düzelt
2. Birimleri gram'a çevir (mg→g: /1000)
3. Değerleri 100g başına normalize et

OCR metni: {text}

Sadece şu JSON formatında döndür:
{"energy_kcal":0,"fat":0,"saturated_fat":0,"sugars":0,"salt":0,"fiber":0,"protein":0}
```

**food_recognition:**
```
Sen bir beslenme uzmanısın. Bu fotoğraftaki yemeği analiz et.

Görevlerin:
1. Yemeğin ne olduğunu belirle (Türkçe isim)
2. Tahmini porsiyon büyüklüğü
3. Kalori ve makro besin değerlerini tahmin et

Sadece şu JSON formatında döndür:
{
  "food_name": "...",
  "portion_grams": 0,
  "energy_kcal": 0,
  "fat": 0,
  "saturated_fat": 0,
  "sugars": 0,
  "salt": 0,
  "fiber": 0,
  "protein": 0,
  "confidence": 0.0-1.0,
  "description": "kısa açıklama"
}
```

## Flutter Service Layer

### New: GeminiAiService

```dart
class GeminiAiService {
  final SupabaseClient _client;

  Future<String> improveIngredientsOcr(String rawText) async { ... }
  Future<NutritionOcrResult> improveNutritionOcr(String rawText) async { ... }
  Future<FoodRecognitionResult> recognizeFood(Uint8List imageBytes) async { ... }
}
```

- Uses `_client.functions.invoke('gemini-proxy', body: {...})`
- Timeout: 15 seconds
- Fallback: OCR operations → use raw ML Kit result on failure
- Food recognition → show error to user on failure

### New: NutritionOcrResult

```dart
class NutritionOcrResult {
  final double? energyKcal;
  final double? fat;
  final double? saturatedFat;
  final double? sugars;
  final double? salt;
  final double? fiber;
  final double? protein;
}
```

### New: FoodRecognitionResult

```dart
class FoodRecognitionResult {
  final String foodName;
  final int portionGrams;
  final double energyKcal;
  final double fat;
  final double saturatedFat;
  final double sugars;
  final double salt;
  final double fiber;
  final double protein;
  final double confidence;
  final String description;
}
```

### Providers

```dart
final geminiAiServiceProvider = Provider<GeminiAiService>((ref) => ...);
final foodRecognitionProvider = FutureProvider.family<FoodRecognitionResult, Uint8List>(...);
```

## OCR Flow Change

```
Before: Photo → ML Kit → raw text → fields
After:  Photo → ML Kit → raw text → Gemini → cleaned text → fields
                                  ↓ (on failure)
                           raw text → fields (fallback)
```

User sees no difference in UX. Results are just more accurate.

## Scanner Screen: Dual Mode

```
┌──────────┬──────────────┐
│ 🔲 Barkod│ 📷 AI Analiz │  ← Tab bar at top
└──────────┴──────────────┘

Barkod mode: existing barcode scanner (no changes)
AI mode: camera preview + capture button + "Yemeği çerçeve içine alın" hint
```

## Food Result Screen

```
┌─────────────────────────────────┐
│  ◀  AI Analiz Sonucu            │
│  [Çekilen fotoğraf]             │
│  🍕 Lahmacun                    │
│  Tahmini porsiyon: ~250g        │
│  Güven: %87                     │
│  [HP Skor 3/5 gauge]            │
│  ┌────────┬────────┬───────┐    │
│  │580 kcal│ 22g    │ 18g   │    │
│  │Enerji  │ Protein│ Yağ   │    │
│  ├────────┼────────┼───────┤    │
│  │ 68g    │ 3.2g   │ 4.1g  │    │
│  │Karb.   │ Lif    │ Tuz   │    │
│  └────────┴────────┴───────┘    │
│  📝 Kısa açıklama...            │
│  [━━━ Geçmişe Kaydet ━━━━━]    │
│  [━━━ Tekrar Çek ━━━━━━━━━]    │
└─────────────────────────────────┘
```

## Data Model: Barcodeless Foods

AI-recognized foods use virtual barcodes:
- Format: `ai_{timestamp}_{short_uuid}`
- Example: `ai_1712345678_a1b2`
- Stored in same `community_products` table with `source: 'ai_recognition'`

ProductEntity mapping:
- `productName` → AI food name ("Lahmacun")
- `brands` → "AI Tahmin"
- `imageUrl` → captured photo uploaded to Supabase Storage
- `nutriments` → AI-estimated values
- `hpScore` → calculated from AI nutriment estimates

History/Favorites display:
- 🤖 icon or "AI Tahmin" label distinguishes from barcoded products
- Tap opens normal product detail page
- Low confidence (< 0.6) shows warning label

## Phase 0: Bugfixes (Pre-AI)

### 0a: Show ingredients in Besin tab
- Add ingredients card above nutrition table in product detail Nutrition tab
- Shows `product.ingredientsText` with "İçindekiler" header

### 0b: HP Score instant 5 for harmful ingredients
- In `hp_score_calculator.dart` `calculateFull()`, before any calculation:
- Scan `ingredientsText` for harmful keywords
- If found → return `hpScore: 10.0` (maps to gauge 5 = worst)
- Keywords: palm yağı, palm oil, invert şeker, invert sugar, glikoz şurubu,
  glucose syrup, fruktoz şurubu, fructose syrup, früktoz şurubu, mısır şurubu,
  corn syrup, şeker şurubu, sugar syrup, yüksek fruktozlu mısır şurubu,
  high fructose corn syrup

### 0c: Debug petit beurre photo upload
- Add diagnostic logging to `_uploadImage` method
- Log: barcode value, sanitized path, file size, file extension
- Log: Supabase response or error details
- Identify and fix root cause

## Implementation Phases

- **Phase 0:** Bugfixes (ingredients display, HP score rules, photo upload)
- **Phase 1:** Supabase Edge Function (gemini-proxy)
- **Phase 2:** Flutter GeminiAiService + OCR integration
- **Phase 3:** Scanner dual mode UI + food recognition flow
- **Phase 4:** FoodResultScreen + history integration
