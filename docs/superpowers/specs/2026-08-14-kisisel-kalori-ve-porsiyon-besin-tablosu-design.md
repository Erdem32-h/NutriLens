# Kişiye Özel Kalori Hedefi + Porsiyon-Doğru Besin Tablosu

**Tarih:** 2026-08-14
**Durum:** Onaylandı, uygulanmayı bekliyor
**Kapsam:** Spec A. Tüm uygulama görsel dil hizalaması ayrı bir spec (Spec B) olarak ele alınacak.

---

## Problem

İki ayrı yanlışlık aynı iki widget'ta birleşiyor:

1. **Kalori referansı herkes için sabit.** `BentoNutritionGrid` yüzdelik değerleri
   `_dailyCalories = 2000` sabitine göre hesaplıyor
   (`lib/features/product/presentation/widgets/bento_nutrition_grid.dart:22`),
   `dailyValueNote` yerelleştirme metni de aynı varsayımı tekrarlıyor. 55 kiloluk
   hareketsiz bir kullanıcı da 95 kiloluk aktif bir kullanıcı da aynı yüzdeyi görüyor.

2. **Öğün besin tablosu yanlış etiketli.** AI prompt'u değerleri açıkça porsiyon
   toplamı olarak istiyor ("Nutrition değerleri o portion_grams için TOPLAM
   değerdir, 100 g için değil" — `anthropic_ai_service.dart:722`) ve
   `food_result_screen` bu toplamları porsiyon çarpanıyla ölçekleyip gösteriyor.
   Ama tabloyu çizen `EditorialNutrientTable` sütun başlığına `'100g'` sabitini
   basıyor (`editorial_nutrient_table.dart:167`), çünkü aynı widget hem paketli
   ürün (gerçekten 100 g) hem öğün (porsiyon toplamı) ekranında kullanılıyor.
   **Sayılar doğru, etiket yalan söylüyor.**

Ayrıca `MealEntries` tablosunda porsiyon gramajı için kolon yok — öğün
kaydedilirken bu bilgi kayboluyor, bu yüzden `meal_detail_screen` gramajı
gösteremiyor.

## Başarı kriteri

- Bilgilerini giren bir kullanıcı, Öğünlerim'de "alınan / hedef" değerini kendi
  vücut ölçülerine göre hesaplanmış olarak görür.
- Öğün besin tablosu, o öğünün gerçek gramajını başlıkta gösterir; paketli ürün
  tablosu "100 g" demeye devam eder.
- Bilgilerini girmemiş kullanıcı için hiçbir ekran bozulmaz — her yerde 2000 kcal
  varsayılanına düşülür.
- Metrics toplama akışının her adımı ölçülebilir; nerede terk edildiği görülebilir.

## Kapsam dışı (bilinçli YAGNI)

Makro (protein/karbonhidrat/yağ) hedefleri, kilo takip grafiği, haftalık kilo
verme tempo seçimi, su takibi, öğün bazlı kalori dağılımı (kahvaltı %25 gibi).

---

## Mimari

### 1. Veri modeli

**Yerel (Drift, şema v3 → v4).** Yeni `UserMetrics` tablosu:

| Kolon | Tip | Not |
|---|---|---|
| `userId` | text, PK | Misafirde `'guest'` |
| `sex` | text | `male` \| `female` \| `unspecified` |
| `birthYear` | int | Yaştan türetilir; hedef her yıl kendiliğinden güncellensin diye yaş değil yıl saklanır |
| `heightCm` | int | |
| `weightKg` | real | |
| `targetWeightKg` | real, nullable | Boş bırakılırsa koruma (TDEE) |
| `activityLevel` | text | `sedentary` \| `light` \| `moderate` \| `active` |
| `updatedAt` | dateTime | |

Aynı migration'da `MealEntries` tablosuna `portionGrams` (int, nullable) kolonu eklenir.

**Uzak (Supabase).** Yeni tablo yok. `public.user_profiles` zaten var, RLS'li ve
`handle_new_user` trigger'ı ile otomatik oluşuyor (`001_users_profiles.sql`).
Aynı 6 alan oraya kolon olarak eklenir. `public.meal_entries` tablosuna da
`portion_grams` kolonu eklenir ki premium bulut senkronu porsiyonu kaybetmesin.

**Misafirden kayıtlıya devir.** `GuestMigrationService.migrate(newUserId:)` zaten
var ve `post_auth_flow` içinden çağrılıyor. `guest` satırının `userId`'sini yeni
kullanıcıya taşıma işi oraya eklenir — ayrı bir devir mekanizması kurulmaz.

### 2. Hesaplayıcı

`lib/core/services/calorie_target_calculator.dart` — saf fonksiyon, I/O yok,
provider yok, doğrudan test edilebilir.

```
BMR (Mifflin-St Jeor):
  male        → 10·kg + 6.25·cm − 5·yaş + 5
  female      → 10·kg + 6.25·cm − 5·yaş − 161
  unspecified → 10·kg + 6.25·cm − 5·yaş − 78   (iki formülün ortalaması)

TDEE = BMR × aktivite faktörü
  sedentary 1.2 | light 1.375 | moderate 1.55 | active 1.725

Hedef:
  hedefKilo < mevcutKilo − 1  → TDEE × 0.85
  hedefKilo > mevcutKilo + 1  → TDEE × 1.10
  aksi halde / hedef yok      → TDEE

Taban: sonuç max(BMR, 1200) değerinin altına asla inmez.
Sonuç 10'a yuvarlanır.
```

Girdi doğrulama sınırları: yaş 16–100, boy 120–230 cm, kilo 30–300 kg,
hedef kilo 30–300 kg. Aralık dışı değer hesaplayıcıya ulaşmadan form seviyesinde
reddedilir; hesaplayıcı yine de kendi içinde sınırları uygular (savunmacı).

### 3. Toplama akışı

**Tetikleyici:** ilk `meal_added` olayından sonra, `UserMetrics` kaydı yoksa ve
kullanıcı daha önce reddetmediyse. Kullanıcı değeri görmüş olduğu an sorulur —
onboarding'e eklenmez (onboarding'de 0→1 sayfasında zaten %32 düşüş var).

**Adımlar (5 ekran, tek akış):**
1. Cinsiyet — 3 kart (kadın / erkek / belirtmek istemiyorum)
2. Yaş + boy + kilo — tek ekranda 3 sayısal alan
3. Hedef kilo — atlanabilir ("Şu anki kilomu korumak istiyorum")
4. Aktivite düzeyi — 4 kart, tek dokunuş
5. Sonuç — "Günlük hedefin **2 180 kcal**" + kayıt CTA'sı

**Reddetme:** "Şimdi değil" kalıcıdır, akış bir daha kendiliğinden açılmaz.
Profil ekranından her zaman erişilebilir ve düzenlenebilir.

**Kayıt bağlantısı:** sonuç ekranında kazanç çerçeveli CTA — *"Hedefini kaydet,
cihaz değiştirsen de kalsın."* 693 açılışa karşılık 0 kayıt olan huniye kayıp
değil kazanç çerçevesiyle giren ilk nokta bu.

**Analytics** (`AnalyticsEvents` içinde, mevcut isimlendirme düzenine uygun):

| Event | Props |
|---|---|
| `metrics_prompt_shown` | — |
| `metrics_step_completed` | `step` (sex\|body\|target\|activity) |
| `metrics_completed` | `target_kcal`, `activity` |
| `metrics_dismissed` | `step` — hangi adımda bırakıldı |

### 4. Hedefin göründüğü yerler

- **Öğünlerim:** günün toplamı / hedef ("1 420 / 2 180 kcal") ve kalori
  grafiğine yatay hedef çizgisi.
- **`BentoNutritionGrid`:** `_dailyCalories` sabiti yerine hedef değeri parametre
  olarak alır.
- **`dailyValueNote`:** hedef varsa kişisel metin, yoksa mevcut 2000 kcal metni.

Paketli ürün ekranlarında da kişisel hedef kullanılır — "bu üründen 100 g
yerseniz günlük kalorinizin %X'i" ifadesi kişiselleştirildiğinde daha doğru olur.

**Fallback zorunlu:** `UserMetrics` yoksa her üç yer de 2000 kcal'e döner.
Hiçbir ekran metrics'in varlığına bağımlı olmaz.

### 5. Porsiyon etiketi

`EditorialNutrientTable` ve `BentoNutritionGrid` `basisLabel` (String) parametresi
alır:

- Ürün ekranları → `'100 g'`
- Öğün ekranları → `'${portionGrams} g'`
- `portionGrams` null (v4 öncesi kayıtlar) → gramajsız `'porsiyon'`

Sayısal değerlere dokunulmaz — bu değişiklik yalnızca başlığı düzeltir.

### 6. Sağlık/uyum notları

- Her sonuç ekranında ve profil metrics bölümünde: *"Tahmini değerdir, tıbbi
  tavsiye yerine geçmez."*
- 16 yaş altı girdi kabul edilmez.
- **App Store App Privacy beyanı güncellenmeli:** boy/kilo/yaş sağlık verisidir ve
  girişli kullanıcıda Supabase'e yazılır → **Health & Fitness → Body/Health data**
  eklenmelidir. 2026-08-13'te yayınlanan beyan bunu kapsamıyor.

---

## Test stratejisi

| Katman | Test |
|---|---|
| Hesaplayıcı | Tablo bazlı birim testler: bilinen BMR referans değerleri, 4 aktivite faktörü, açık/fazla/koruma dalları, `max(BMR, 1200)` tabanı, `unspecified` cinsiyet varyantı, sınır dışı girdilerin kırpılması |
| Drift | v3→v4 migration testi: mevcut `MealEntries` satırları korunur, `portionGrams` null gelir, `UserMetrics` boş oluşur |
| Devir | `GuestMigrationService` testi: `guest` satırı yeni `userId`'ye taşınır, hedef kullanıcıda zaten kayıt varsa üzerine yazılmaz |
| Widget | `basisLabel` ürün ekranında `'100 g'`, öğün ekranında gramaj gösterir; metrics yokken 2000 fallback'i her üç yerde çalışır |
| Form | Doğrulama sınırları, "hedef kilo yok" dalı, adım adım ilerleme |
| Canlı | Emülatörde 720x1280 / density 320 ile 5 adımlı akışın yerleşimi. Widget testleri bu projede metin kaynaklı dikey yerleşimi yakalamıyor (gerçek Roboto yerine test fontu çizildiği için satır kırılımları farklı) — yerleşim iddiası emülatörde doğrulanmadan tamam sayılmaz |

## Riskler

| Risk | Karşılık |
|---|---|
| 5 adımlı form terk edilir | Adım bazlı `metrics_dismissed` event'i nerede kaybedildiğini söyler; akış tek ekrana indirilebilir |
| Migration v4 mevcut öğünleri bozar | Yalnızca nullable kolon eklenir, veri dönüşümü yok; migration testi bunu doğrular |
| Kişisel hedef ürün %DV'sini beklenmedik biçimde değiştirir | Fallback her yerde aynı; hedef yoksa davranış bugünküyle bit bit aynı kalır |
| Sağlık verisi beyanı eksik kalır | Uygulama mağazaya çıkmadan App Privacy güncellemesi zorunlu adım olarak plana yazılır |
