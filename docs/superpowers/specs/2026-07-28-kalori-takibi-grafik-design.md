# Kalori Takibi Grafiği (Öğünlerim) — Tasarım

**Tarih:** 2026-07-28
**Durum:** Onaylandı, uygulama planı bekliyor
**Kapsam:** `MealsScreen`'e gün/hafta/ay/yıl kalori+makro grafiği eklenmesi,
makro "az/normal/çok" göstergesi, ve ana ekran widget'ının 3 makro
göstergesiyle genişletilmesi.

---

## 1. Problem / istek

Kullanıcı, telefonundaki bir sağlık uygulamasının Uyku ekranına benzer bir
kalori takibi arayüzü istiyor: Gün/Hafta/Ay/Yıl sekmeleri, dönem içi bar
grafiği, ve altında bir özet kart. Kendi isteği: "içinde protein yağ ve
karbonhidrat oranları ve onların çok ya da az olduğuna yönelik gösterge...
tasarımı figma'da yap. bunun yansıması da widget'ta olsun."

## 2. Mevcut durum

- `MealEntryEntity` (`lib/features/meals/domain/entities/meal_entry_entity.dart`)
  her öğün için `calories` + `NutrimentsEntity` (`fat`, `carbohydrates`,
  `proteins`, gram cinsinden) tutuyor. **Makro verisi zaten var**, şema
  değişikliği gerekmiyor.
- `MealsScreen` (`lib/features/meals/presentation/screens/meals_screen.dart`)
  şu an sadece Bugün/Hafta/Ay kcal toplamını 3 statik kartta gösteriyor
  (`_SummaryCards`, satır 88-115). Grafik yok, Yıl yok, makro yok.
- `mealCalorieSummaryProvider` (`meal_provider.dart:64-101`) sadece toplam
  kcal döndürüyor (`MealCalorieSummary{today, week, month}`); günlük
  bucket'lama veya makro toplamı yok.
- `MealLocalDataSource.totalCalories()` sadece `double` toplam döndürüyor,
  ham satırları döndürmüyor — bucket'lama için yeni bir metot gerekiyor.
- Kişisel kalori hedefi (TDEE) **hiçbir yerde yok** — bu tasarım kişisel
  hedef gerektirmiyor (bkz. §4, kullanıcı kararı: genel referans).
- Grafik kütüphanesi (`fl_chart` vb.) projede **yok**. `BentoNutritionGrid`
  (`lib/features/product/presentation/widgets/bento_nutrition_grid.dart`)
  el yapımı `CustomPainter`/`LinearProgressIndicator` kullanıyor — aynı yol
  izlenecek, yeni bağımlılık eklenmeyecek.
- `home_widget: ^0.6.0` paketiyle Android (`NutriLensHomeWidgetProvider.kt`)
  + iOS (`NutriLensHomeWidget.swift`) widget'ları zaten var, `HomeWidgetService`
  (`lib/core/services/home_widget_service.dart`) bugünün kcal + öğün sayısını
  yazıyor. Makro yok.
- Renk sistemi: `AppColors.gaugeColor()` / `riskColor()` (`lib/core/theme/app_colors.dart`)
  1-5 kademeli **kalite** (iyi/kötü) rengi taşıyor — makro **kimliği**
  (protein/yağ/karbonhidrat) için ayrı, sabit bir palet gerekiyor (bkz. §6).
- `HealthScoreBar` (`lib/features/product/presentation/widgets/health_score_bar.dart`)
  görsel dili: `colors.surfaceCard` arka plan, `BorderRadius.circular(24)`,
  `padding: 20`, büyük sayı + segmentli çubuk. Yeni özet kart bu dili taklit
  eder.
- `mealTypeLabel()` (`lib/features/meals/presentation/meal_display.dart`)
  zaten kahvaltı/öğle/akşam/ara öğün etiketlerini localize ediyor — Gün
  görünümünde yeniden kullanılacak.

## 3. Yerleşim kararı

İki sekme var: **Geçmişim** (taranan ürünlerin HP Score listesi — kalori
verisiyle ilgisi yok) ve **Öğünlerim** (kalori verisinin gerçek kaynağı,
zaten Bugün/Hafta/Ay kartları var). Kullanıcı onayıyla: **Öğünlerim**
genişletilecek, Geçmişim'e dokunulmayacak.

`_SummaryCards` bölümü **kaldırılıp yerine** yeni grafik bölümü gelecek
(3 kartın işlevini gün/hafta/ay sekmeleri zaten kapsıyor). Altındaki öğün
listesi değişmeden kalır.

## 4. Makro referans aralıkları

Kullanıcı kararı: **genel diyet referansı**, kişiye özel hedef yok.

| Makro | Referans (toplam kcal içindeki payı) |
|---|---|
| Protein | %10–35 |
| Karbonhidrat | %45–65 |
| Yağ | %20–35 |

Bu aralıklar `lib/core/constants/macro_reference_constants.dart`'ta
`ScoreConstants` deseniyle (`abstract final class`, `static const`)
tanımlanır. Bir makro payı aralığın altındaysa **Düşük**, üstündeyse
**Yüksek**, içindeyse **Normal** etiketi alır.

**Not:** Toplam kalori hedefi (aralık/referans) yok — sadece dağılım
(protein/yağ/karbonhidrat payı) değerlendiriliyor. Ekranda "hedefe göre
az/çok kalori" gibi bir mesaj **verilmez**, çünkü hedef altyapısı yok; bu
bilinçli bir kapsam dışı bırakma.

## 5. Zaman dilimleri ve bucket'lama

| Sekme | Bucket | Bar sayısı | Kaynak |
|---|---|---|---|
| **Gün** | Öğün tipi (kahvaltı/öğle/akşam/ara öğün) | 4 | Bugünün `MealEntryEntity` listesi, `mealType`'a göre gruplanır |
| **Hafta** | Gün (Pzt–Paz) | 7 | Bu haftanın öğünleri, `capturedAt` gününe göre gruplanır |
| **Ay** | Gün | 28-31 | Bu ayın öğünleri, güne göre gruplanır |
| **Yıl** | Ay | 12 | Bu yılın öğünleri, aya göre gruplanır |

Her bucket için: toplam kcal + makro-kcal katkısı (`protein_g×4`,
`carb_g×4`, `fat_g×9`) hesaplanır; bar bu üç değere göre üç renkli
segmente bölünür (dikey stacked bar — referans ekrandaki uyku
evreleri gibi).

Bucket'lama **Dart tarafında, bellekte** yapılır (yeni SQL agregasyonu
yok) — kişisel kullanım için satır sayısı küçük (günde birkaç öğün).
Önceki/sonraki dönem gezinme oku (ekrandaki `<` `>` gibi) mevcut haftayı/
ayı/yılı offset'ler; gelecek tarihe geçilemez.

**Kenar durum — boş dönem:** Bir bucket'ta hiç öğün yoksa bar 0 yükseklikte
render edilir (kırık/eksik gösterim yok). Sekmenin tamamı boşsa (örn. hiç
öğün girilmemiş ay) grafik alanı `MealsScreen`'in mevcut `_EmptyMeals`
boş-durum diliyle uyumlu sade bir mesaj gösterir, grafik render edilmez.

## 6. UI bileşenleri

Yeni dosyalar `lib/features/meals/presentation/widgets/` altında (dosya
başına tek sorumluluk, ~100-200 satır hedef):

### 6.1 `calorie_period_selector.dart`
Gün/Hafta/Ay/Yıl segment kontrolü (mevcut `AppButton`/tema diliyle uyumlu,
`SegmentedButton` veya elle yapılmış pill grubu) + dönem gezinme oku +
seçili dönemin tarih aralığı etiketi (örn. "26 Tem – 1 Ağu").

### 6.2 `calorie_stacked_bar_chart.dart`
El yapımı bar grafik (Container/AnimatedContainer yükseklikleri, `fl_chart`
bağımlılığı yok — `BentoNutritionGrid`'in `_CircularProgressPainter`
desenine paralel). Her bar 3 renkli segmente bölünür:

| Makro | Renk (kimlik, kalite değil) |
|---|---|
| Protein | `#6366F1` (indigo) |
| Karbonhidrat | `#F59E0B` (amber) |
| Yağ | `#EC4899` (pembe) |

Bu üç renk **sabit kimlik renkleridir**, `gaugeColor`/`riskColor`'la
karıştırılmaz (onlar kalite/risk taşır, bunlar "hangi makro" bilgisini
taşır) — ekrandaki referans görselde de segment rengi (derin/hafif uyku)
ile alttaki "Düşük/Yüksek" etiket rengi ayrı kavramlardır.

### 6.3 `macro_balance_card.dart`
`HealthScoreBar` görsel dilinde (`surfaceCard`, radius 24, padding 20):
- Üstte: seçili dönemin ortalama/toplam kcal'i (büyük sayı)
- Altta: 3 satır (Protein/Karbonhidrat/Yağ) — her biri payı (%) ve
  Düşük/Normal/Yüksek etiketi (mavi/yeşil/turuncu, referans ekrandaki
  "Düşük"=mavi, "Yüksek"=turuncu diliyle uyumlu)

### 6.4 `meals_screen.dart` değişikliği
`_SummaryCards` widget'ı ve çağrısı kaldırılır; yerine yeni bir
`_CalorieInsights` (veya benzer) bölümü üç yeni widget'ı birleştirip aynı
`SliverToBoxAdapter` konumuna oturtur. Öğün listesi (`SliverList`) ve boş
durum değişmeden kalır.

## 7. Veri katmanı

### 7.1 `MealLocalDataSource` — yeni metot
```dart
Future<List<MealEntryEntity>> getMealsInRange({
  required String userId,
  required DateTime from,
  required DateTime to,
});
```
`totalCalories()` ile aynı sorgu deseni (`capturedAt` aralık filtresi),
ama `rows.map(_fromRow)` ile tam entity listesi döner (bucket'lama ve
makro hesaplama için ham veri gerekiyor).

### 7.2 Yeni provider dosyası: `meal_chart_provider.dart`
`meal_provider.dart`'a eklemek dosyayı büyütüp iki farklı sorumluluğu
(CRUD/sync vs. grafik agregasyonu) karıştırır — ayrı dosya.

```dart
enum CaloriePeriod { day, week, month, year }

final calorieChartDataProvider =
    FutureProvider.family<CalorieChartData, (CaloriePeriod, int offset)>(...);
```

`offset` = geriye kaç dönem (0 = şu anki hafta/ay/yıl/gün, 1 = önceki...),
gezinme oklarıyla değişir. Dönüş tipi `CalorieChartData`: bucket listesi
(`label`, `kcal`, `proteinKcal`, `carbKcal`, `fatKcal`) + dönem toplam/
ortalama kcal + her makronun payı ve Düşük/Normal/Yüksek durumu.

## 8. Ana ekran widget'ı (home_widget)

Kullanıcı kararı: **kalori + 3 makro göstergesi**.

`HomeWidgetService.refresh()` bugünün satırlarını zaten çekiyor
(`home_widget_service.dart:63-78`); değişiklik:
1. Her satırın `nutriments` JSON alanı `NutrimentsDto.fromJsonString` ile
   parse edilir, protein/karb/yağ gram toplamları çıkarılır.
2. Makro-kcal'e çevrilir (`×4`/`×4`/`×9`), toplam makro-kcal'e göre her
   birinin **payı** (0-100 int) hesaplanır.
3. 3 yeni anahtar yazılır: `today_protein_pct`, `today_carb_pct`,
   `today_fat_pct` (mevcut `_keyKcal`/`_keyMealCount` desenine paralel).

**Kapsam kararı — widget'ta Düşük/Normal/Yüksek etiketi YOK:** widget
alanı çok küçük; native tarafta sadece 3 renkli mini bar/nokta (§6.2'deki
aynı 3 kimlik rengi) çizilir, aynı eşik mantığının Kotlin+Swift'te
tekrarlanması gerekmez. Etiketleme yalnızca uygulama içindeki
`macro_balance_card.dart`'ta var.

- **Android:** `nutrilens_home_widget.xml` layout'una 3 küçük
  `ProgressBar`/renkli dikdörtgen eklenir; `NutriLensHomeWidgetProvider.kt`
  yeni anahtarları okuyup bağlar.
- **iOS:** `NutriLensHomeWidget.swift`'teki `systemSmall`/`systemMedium`
  view'lara aynı 3 göstergenin karşılığı eklenir (App Group üzerinden aynı
  anahtarlar okunur).

## 9. Figma adımı

Kodlamadan önce Figma MCP (`use_figma`/`figma-generate-design` skill'leri)
ile şu ekranların mockup'ı çıkarılır ve onaya sunulur:
1. `MealsScreen` — Gün/Hafta/Ay/Yıl sekmeli grafik bölümü + makro kart
   (light + dark tema)
2. Android/iOS widget düzeni — kcal + 3 makro göstergesi

Mockup onaylandıktan sonra Flutter implementasyonuna geçilir. Mockup,
mevcut `AppColors`/`HealthScoreBar` görsel dilini (radius 24, `surfaceCard`,
tipografi) referans alır — sıfırdan yeni bir görsel dil **icat edilmez**.

## 10. l10n

Yeni anahtarlar 6 dosyaya birden eklenir (tr/en/es/pt/ar/zh), `app_tr.arb`
şablon:

| Anahtar | TR değeri |
|---|---|
| `caloriePeriodDay` | Gün |
| `caloriePeriodWeek` | Hafta |
| `caloriePeriodMonth` | Ay |
| `caloriePeriodYear` | Yıl |
| `macroProtein` | Protein |
| `macroCarbs` | Karbonhidrat |
| `macroFat` | Yağ |
| `macroLevelLow` | Düşük |
| `macroLevelNormal` | Normal |
| `macroLevelHigh` | Yüksek |
| `calorieChartEmptyPeriod` | Bu dönemde kayıtlı öğün yok |

Meal tipi etiketleri (`mealTypeBreakfast` vb.) zaten mevcut, yeniden
kullanılır.

## 11. Kenar durumlar

| Konu | Karar |
|---|---|
| Boş dönem | §5 — grafik yerine sade boş mesaj |
| Zaman dilimi / gün sınırı | Mevcut `mealCalorieSummaryProvider` gibi cihazın yerel `DateTime` sınırları kullanılır (UTC dönüşümü yok, mevcut davranışla tutarlı) |
| Hafta başlangıcı | Pazartesi (mevcut `weekStart = todayStart.subtract(Duration(days: now.weekday - 1))` mantığıyla tutarlı) |
| Gelecek dönem gezinme | Engellenir — ok gelecek tarihe geçemez |
| Widget veri tazeleme | Mevcut tetikleyiciler değişmez (§ `home_widget_service.dart` dosya başı yorumu — meal kayıt/silme, barkod tarama, açılış, OS zamanlayıcı) |
| Açık/koyu tema | Tüm yeni widget'lar `context.colors` kullanır, ikisinde de doğrulanır |
| Nutriments alanları null | Bir öğünde `proteins`/`fat`/`carbohydrates` `null` ise 0 kabul edilir (mevcut `NutrimentsEntity` alanları nullable) |

## 12. Test

- `meal_chart_provider` bucket'lama mantığı için unit testler: gün/hafta/
  ay/yıl sınırları, ay değişimi, hafta başı Pazartesi, boş dönem, null
  makro alanları.
- `macro_balance_card` / `calorie_stacked_bar_chart` için widget testleri
  (mevcut `test/features/meals/` deseni).
- `HomeWidgetService` için mevcutta test yok (native platform bağımlılığı);
  makro hesaplama mantığı test edilebilir bir yardımcı fonksiyona
  çıkarılıp orada test edilir (native `HomeWidget.saveWidgetData`
  çağrılarına dokunmadan).

## 13. Kapsam dışı (bilinçli)

- Kişisel kalori hedefi / TDEE hesaplaması — altyapı yok, bu spec'in
  konusu değil.
- Geçmişim ekranına dokunma — kalori verisiyle ilgisi yok (§3).
- Yeni bir grafik kütüphanesi bağımlılığı — el yapımı bar yeterli.
- Widget'ta Düşük/Normal/Yüksek metin etiketi — alan kısıtı (§8).
