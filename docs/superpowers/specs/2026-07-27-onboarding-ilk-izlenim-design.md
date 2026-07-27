# Onboarding İlk İzlenim — Tasarım

**Tarih:** 2026-07-27
**Durum:** Onaylandı, uygulama planı bekliyor
**Kapsam:** `OnboardingScreen` 3 sayfalık akışın görsel ve metin yeniden tasarımı

---

## 1. Problem

1.2.1 ile canlıya çıkan huni ölçümü, 4 günde 391 Android cihazdan veri topladı
(iOS hâlâ App Review'da, 7 cihaz — analiz Android).

| Adım | Cihaz | Oran |
|---|---|---|
| `onboarding_shown` | 388 | — |
| `onboarding_page_viewed(page=1)` | 258 | %66 |
| `onboarding_page_viewed(page=2)` | 227 | %58 |
| `onboarding_completed` + `onboarding_skipped` | 235 | %61 |

**Okuma notu:** `onboarding_page_viewed`, `PageView.onPageChanged` içinde
ateşleniyor — yani ilk açılışta sayfa 0 için **ateşlenmiyor**. Kayıtlı
`page=0` olayları (16 cihaz) geri kaydıranlardır. Bu yüzden sayfa 0'ı görüp
öteye geçmeyen cihaz sayısı `388 − 258 = 130` olarak okunur.

**Sonuç: 130 cihaz (%33) ilk ekrandan hiç öteye geçmiyor.** Uygulamanın
tek en büyük kaybı burada.

**Sayfa sayısı sorun değil.** Sayfa 0'ı geçenin %91'i akışı bitiriyor
(235/258). Akışı kısaltmak yanlış yeri optimize etmek olur — bu spec sayfa
sayısına dokunmuyor.

## 2. Kök neden

1. **Üründen hiçbir şey görünmüyor.** Sayfa 0 = gradyan kutu içinde jenerik
   `Icons.qr_code_scanner_rounded`. `assets/images/` klasörü tamamen boş;
   uygulamada tek bir ürün görseli yok. Ekran her jenerik utility app'i gibi
   duruyor.
2. **Vaat ile ürün uyuşmuyor.** Sayfa 0 "Barkod Tara" satıyor. Ama tarayıcı
   **yemek fotoğrafı** modunda açılıyor (`_scanMode = 1`) ve 4 günlük veride
   tarayıcıyı açan cihazların **183'ü yemek modunda, yalnızca 5'i barkod
   modunda**; barkod okutabilen 3 cihaz. Satılan şey, ürünün yaptığı şey
   değil.
3. **İç jargon sızıyor.** Sayfa 1: *"HP skoru ile ürünün kimyasal yükü, risk
   faktörü ve beslenme değeri"* — bunlar formül terimlerimiz, yeni
   kullanıcının kelimeleri değil.
4. **Hitap tutarsız.** Aynı akışta "tara**yın**" (siz) → "öğre**n**" (sen) →
   "belirle**yin**" (siz).

## 3. Hedef ve başarı kriteri

**Birincil metrik (değişmiyor, karşılaştırılabilir kalsın diye):**

```
onboarding_page_viewed(page=1) benzersiz cihaz / onboarding_shown benzersiz cihaz
```

- Bugün: **%66** (258/388)
- Hedef: **≥ %80**

**Koruma metriği (gerileme olmasın):** `onboarding_completed + onboarding_skipped`
/ `onboarding_shown` bugün %61 — düşmemeli.

**İkincil gözlem:** `guest_started` / `onboarding_shown` (bugün %55).

Ölçüm 1.2.2 sonrası kohort bazlı okunur (`analytics_funnel_by_cohort`), tüm
zaman ortalamasıyla değil — eski kohort yeni sonucu maskeler.

## 4. Kapsam

**Dahil:**
- `onboarding_screen.dart` — 3 sayfanın görsel içeriği
- 3 yeni önizleme widget'ı (yemek / puan / filtre)
- `_ScanningPhoto`'nun paylaşılabilir bir widget'a çıkarılması
- 1 görsel varlık (`assets/images/onboarding_meal.jpg`) — üretildi
- 6 dilde l10n metinleri
- Mevcut widget testlerinin güncellenmesi

**Hariç (bilinçli):**
- Sayfa sayısı değişikliği (§1 gerekçesi)
- Yeni ekran veya yeni filtre arayüzü — sayfa 2 yalnızca anlatım görseli;
  gerçek filtre ayarı profilde kalıyor
- Aktivasyon yolu cilası (meals/scanner/food-result) — 1.2.2 verisi bekliyor
- Retention kancaları, store vitrini — ayrı iş kalemleri
- HP Score formülü, barkod akışının kendisi

## 5. Tasarım — üç sayfa

| # | Görsel | Başlık | Alt metin |
|---|---|---|---|
| 0 | Yemek fotoğrafı + tarama çizgisi + `486 kcal` · `24g protein` · `puan 2/5` | **Tabağını çek, gerisini biz sayalım.** | Kalori, protein ve sağlık puanı — tek fotoğrafla. |
| 1 | Puan kartı (5 segmentli gauge, puan 4/5) + `21g şeker` · `4 katkı` · `1,2g tuz` | **Paketliyse barkodu okut.** | Katkı maddeleri, şeker ve tuz tek bakışta. |
| 2 | Diyet/alerjen çipleri (bazıları seçili) + sarı uyarı kutusu | **Sana göre uyarı versin.** | Alerjenini ve diyetini seç, sakıncalıyı hemen gör. |

**Neden bu sıra:** sayfa 0 uygulamanın gerçekten açıldığı modu anlatır
(vaat/ürün hizası). Barkod kaldırılmadı, 2. sıraya alındı.

**Örnek veriler illüstratiftir**, hesaplanmış sonuç değildir. Makul
seçildiler (320 g kıymalı makarna ≈ 486 kcal). Ekranda "gerçek sonuç"
iddiası yok.

**Puan neden 2/5:** 1/5 "her şey harika" der ve ürünü işlevsiz gösterir;
5/5 kırmızı ilk ekranda suçlayıcı durur. 2 hem skorun çalıştığını gösterir
hem kimseyi savunmaya itmez.

**Marka riski yok:** sayfa 1'de gerçek marka adı veya ambalajı yok; jenerik
ürün sunumu kullanılır. Gerçek bir markayı kötü puanla göstermek onboarding
için kabul edilmez risk.

## 6. Görsel varlık

`assets/images/onboarding_meal.jpg` — 1080×603 (16:9), 115 KB, JPEG q85.

- AI ile üretildi (nano_banana_pro); marka, logo, metin, ambalaj, el, insan
  içermiyor → telif ve marka riski yok.
- Bilinçli olarak **reklam karesi değil**: ev mutfağı, doğal ışık, sade beyaz
  tabak. Amaç "kullanıcının kendi çekeceği kare" hissi; parlak stüdyo görseli
  "benim tabağım böyle çıkmaz" diyerek vaadi bozar.
- `pubspec.yaml` zaten `assets/images/` klasörünü bildiriyor — pubspec
  değişikliği **gerekmiyor**.
- Aynı görsel store ekran görüntülerinde de kullanılabilir (tek üretim, iki iş).

## 7. Kod yapısı

### 7.1 `_PageData` → görsel builder

Bugün `_PageData` sabit bir `IconData` taşıyor. Üç sayfanın görseli artık
birbirinden farklı, dolayısıyla:

```dart
class _PageData {
  final WidgetBuilder visual;   // icon yerine
  final String title;
  final String description;
}
```

### 7.2 Yeni dosya: önizleme widget'ları

`lib/features/auth/presentation/widgets/onboarding_previews.dart`

Üç küçük stateless widget: `MealPreview`, `ScorePreview`, `FiltersPreview`.
Hepsi `context.colors` kullanır (light/dark otomatik uyum). Tek dosyada
tutuluyorlar çünkü toplamı ~200 satır ve yalnızca onboarding'e hizmet
ediyorlar; büyürlerse ayrılabilirler.

`onboarding_screen.dart` bugün 351 satır — görselleri içine gömmek onu
~600 satıra çıkarırdı, proje standardının (200-400 tipik) dışına taşar.

### 7.3 `ScanningPhoto` paylaşıma çıkarılıyor

Tarama çizgisi animasyonu **zaten var**: `food_result_screen.dart` içinde
private `_ScanningPhoto` + `_ScanLinePainter` + `_ViewfinderCornersPainter`.
Onboarding'de yeniden kullanmak için `lib/core/widgets/scanning_photo.dart`
altına `ScanningPhoto` olarak taşınır.

**Arayüz değişikliği:** bugün `Uint8List` alıyor. `ImageProvider` alacak
şekilde genelleştirilir — food-result `MemoryImage`, onboarding `AssetImage`
geçer. `food_result_screen.dart` çağrı noktası buna göre güncellenir.

**Kritik: animasyon sınırlı olmalı.** Bugünkü `_ScanningPhoto`
`repeat(reverse: true)` ile sonsuz döner. Onboarding'de sonsuz animasyon iki
şeyi bozar:

1. **Testler kilitlenir.** `onboarding_screen_test.dart` dört testte de
   `pumpAndSettle()` çağırıyor; sonsuz animasyonda bu asla yerleşmez ve
   test timeout'a düşer.
2. **UX yanlış mesaj verir.** Durmadan tarayan bir fotoğraf "hâlâ
   yükleniyor" der; oysa sonuçlar zaten ekranda.

Bu yüzden `ScanningPhoto` bir `sweeps` parametresi alır: food-result sonsuz
(`null` = analiz bitene kadar), onboarding **2 süpürme sonra durur** ve
çizgiyi gizler. Sayısal değerler süpürme biterken belirir.

## 8. l10n

### 8.1 Yeni anahtarlar (6 dosya: tr/en/es/pt/ar/zh)

| Anahtar | TR değeri |
|---|---|
| `onboardingMealTitle` | Tabağını çek, gerisini biz sayalım. |
| `onboardingMealBody` | Kalori, protein ve sağlık puanı — tek fotoğrafla. |
| `onboardingBarcodeTitle` | Paketliyse barkodu okut. |
| `onboardingBarcodeBody` | Katkı maddeleri, şeker ve tuz tek bakışta. |
| `onboardingFiltersTitle` | Sana göre uyarı versin. |
| `onboardingFiltersBody` | Alerjenini ve diyetini seç, sakıncalıyı hemen gör. |
| `onboardingSampleMealName` | Kıymalı makarna |
| `onboardingSamplePortion` | ~320 g porsiyon |
| `onboardingSampleWarning` | Bu üründe laktoz var — senin listende. |

Önizleme etiketleri (`KCAL`, `PROTEİN`, `ŞEKER`, `KATKI`, `TUZ`) ve çip
adları (`Gluten`, `Laktoz`, `Vegan`…) için **önce mevcut anahtarlar
aranır**; yalnızca karşılığı yoksa yeni anahtar açılır. `healthScoreLabel`,
`bestScore`, `worstScore` zaten var ve puan önizlemesinde kullanılır.

`app_tr.arb` şablondur; diğer 5 dil onu takip eder.

### 8.2 ⚠️ Dokunulmayacak anahtar

**`scanBarcodeTitle` paylaşımlıdır** — `food_result_screen.dart:231`'de
"paketli ürün algılandı" diyaloğunun buton etiketi olarak kullanılıyor.
Onboarding metni için **yeniden kullanılmaz veya değiştirilmez**.

### 8.3 Yetim kalacak anahtarlar

Bu beşinin tek kullanıcısı onboarding'dir; yeni anahtarlara geçince 6 arb
dosyasından da silinirler:
`scanBarcodeDescription`, `healthScoreTitle`, `healthScoreDescription`,
`personalFilters`, `personalFiltersDescription`.

Silmeden önce `lib/` genelinde son bir arama yapılır (generated dosyalar
hariç tutulur).

## 9. Kenar durumlar ve riskler

| Konu | Karar |
|---|---|
| **Küçük ekran taşması** | Yeni sayfa 0 eskisinden uzun (16:9 fotoğraf + meta + ızgara). `onboarding_screen_test.dart` 375×667'de taşmayı zaten test ediyor — **bu test geçmek zorunda.** Çözüm sırası: (1) esnek yükseklik — görsele sabit piksel yerine `Flexible`/`AspectRatio` ver, (2) yetmezse dikey boşlukları küçült, (3) son çare sayfa gövdesini `SingleChildScrollView`'a al. Hiçbir durumda sabit yükseklik verilmez. |
| **Açık tema** | Uygulamanın light teması var. Tüm önizlemeler `context.colors` kullanır. Her iki temada gözle doğrulanır (fotoğraf üstündeki beyaz metin light temada da okunmalı). |
| **RTL (Arapça)** | Çip dizilimi ve uyarı kutusu RTL'de test edilir; `EdgeInsets` yerine yönsel varyantlar (`EdgeInsetsDirectional`) kullanılır. |
| **Uzun çeviriler** | Başlıklarda **sabit satır sonu (`\n`) kullanılmaz**; metin doğal sarılır. En uzun dilde 3 satıra çıkabilir, düzen buna dayanmalı. |
| **Görsel yükleme hatası** | `Image.asset` hata verirse önizleme çökmemeli; `errorBuilder` ile sade bir dolgu gösterilir. |
| **Beklenti şişmesi** | Fotoğraf bilinçli olarak sade tutuldu (§6). Yine de risk sıfır değil: kullanıcının kendi karesi daha kötü çıkarsa hayal kırıklığı olabilir. Kabul edilen risk. |
| **Örnek verinin yanıltıcılığı** | Değerler illüstratif; ekranda "hesaplandı" iddiası yok. |

## 10. Ölçüm değişikliği

`onboarding_page_viewed` bugün ilk sayfa için ateşlenmiyor (§1). Bu spec
kapsamında `initState` içinde `page=0` için de bir kez ateşlenir — böylece
huni ileride çıkarım yapmadan doğrudan okunur.

**Karşılaştırma metriği değişmez:** öncesi/sonrası kıyası `page=1 /
onboarding_shown` üzerinden yapılır (§3), çünkü tarihsel veride `page=0`
yok. Yeni olay yalnızca gelecekteki analizleri netleştirir; mevcut
`onboarding_shown` ve `page=1` davranışına dokunmaz.

## 11. Test

Mevcut `test/features/auth/onboarding_screen_test.dart` dört testi korunur
(taşma / iki çıkış yolu / misafir moduna giriş / login yolu). Eklenecekler:

- Üç sayfanın da hata vermeden render olması
- `ScanningPhoto`'nun sınırlı süpürme sonrası durması — yani
  `pumpAndSettle()` zaman aşımına düşmemesi (§7.3'ün regresyon testi)
- Açık tema ve `Locale('ar')` altında taşma olmaması
- `page=0` analitik olayının bir kez ateşlenmesi

## 12. Sonraki adımlar (bu spec dışında)

1. **1.2.2 verisi geldiğinde** kamera→aktivasyon uçurumuna bak
   (`scan_photo_captured` → `meal_analysis_*` zinciri).
2. **Store vitrini** — bu fotoğraf ve önizlemeler ekran görüntüsü olarak
   kullanılabilir.
3. **Retention kancaları** — aktivasyon düzeldikten sonra.
