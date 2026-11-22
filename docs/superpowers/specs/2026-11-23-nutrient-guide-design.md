# Besin Rehberi (vitamin / mineral / amino asit bilgi kütüphanesi) — Tasarım

Tarih: 2026-11-23 · Durum: onay bekliyor

## Amaç (neden)
Kullanıcı bir besinin vücutta ne yaptığını, eksikliğinin ve fazlalığının hangi belirtileri verdiğini uygulama içinde öğrenebilsin. Bu bir **öğrenme içeriği**; ürün/öğün verisine bağlı değil.

## Hedefler
- Vitaminler (~13), mineraller (~14), temel amino asitler (9) için detaylı kayıt.
- Her kayıt: ne işe yarar, eksiklik belirtileri, fazlalık belirtileri, hangi besinlerde bulunur, günlük ihtiyaç aralığı, kaynak.
- Çevrimdışı çalışır, sunucu/migration yok.
- Profil ekranından erişilir.

## Hedef dışı
- Ürün başına mikro besin değeri (OFF/USDA/AI) — bu özellikte yok.
- HP Score'a etki yok; `NutrimentsEntity`, Drift ve Supabase şeması değişmez.
- Kişiselleştirilmiş eksiklik teşhisi veya takviye önerisi yok.
- Alt çubuğa yeni sekme yok.

## Kaçınılacak (anti-hedef)
Tıbbi tavsiye gibi görünmek. Belirsiz/uydurma sağlık iddiası. Bu yüzden her ekranda uyarı ve her kayıtta kaynak alanı zorunlu.

## Yaklaşımlar
- **A. Gömülü JSON asset (seçildi):** `assets/nutrients/nutrients.json` + liste ve detay ekranı; mevcut `assets/additives/additives_database.json` + `additive_detail_screen` deseninin aynısı. Çevrimdışı, migration yok. Eksi: içerik değişikliği yeni sürüm ister.
- **B. Supabase tablosu:** sürümsüz düzeltme, ama RLS/önbellek altyapısı ~40 sabit kayıt için fazla. Elendi.
- **C. AI ile anlık üretim:** uydurma riski ve kota maliyeti, sağlık iddiasında kabul edilemez. Elendi.

## Tasarım

**Veri.** `assets/nutrients/nutrients.json`: `{version, updated_at, nutrients: [...]}`. Kayıt alanları:
`id`, `category` (`vitamin` | `mineral` | `amino_acid`), `name_{tr,en}`, `alt_name_{tr,en}` (ör. Kobalamin), `function_{tr,en}`, `deficiency_{tr,en}` (belirti listesi), `excess_{tr,en}` (belirti listesi), `sources_{tr,en}` (besin listesi), `daily_need` (yetişkin aralığı + birim, metin), `upper_limit` (varsa), `source` (ör. "NIH ODS", "EFSA"). Diğer diller İngilizceye düşer.

**Domain/Data.** `NutrientEntity` (Equatable) + `NutrientRepository` (asset'i bir kez yükleyip önbelleğe alır) + Riverpod `FutureProvider`. Yükleme hatası sessiz yutulmaz, ekranda hata durumu gösterilir. Kapsam `lib/features/nutrient_guide/` (domain/data/presentation).

**UI.**
- `NutrientGuideScreen`: üç sekme (Vitaminler / Mineraller / Amino asitler), her sekmede kayıt listesi, üstte basit arama.
- `NutrientDetailScreen`: bölümler — Ne işe yarar / Eksikse / Fazlaysa / Nerede bulunur / Günlük ihtiyaç; altta "Tıbbi tavsiye değildir" uyarısı ve kaynak.
- Route: `/nutrients` ve `/nutrient/:id` (`app_router.dart`, `route_names.dart`).
- Giriş: Profil ekranına "Besin Rehberi" kartı.
- Stil: mevcut tema (`context.colors`) ve katkı maddesi detay ekranının düzeni.

**Yerelleştirme.** UI başlıkları (sekmeler, bölüm adları, uyarı) `app_*.arb` dosyalarına; en/tr eksiksiz, diğerleri İngilizce. İçerik JSON'da kalır, ARB'ye taşınmaz.

**İçerik süreci.** İçeriği NIH ODS / EFSA gibi kaynaklardan derleyip `source` alanına yazarım; **yayından önce Fatih örnekle gözden geçirir** (özellikle fazlalık ve üst sınır değerleri).

## Test
- Repository: JSON ayrıştırma, dil yedeği (fallback), eksik alan, bozuk JSON.
- Veri bütünlüğü testi: her kayıtta zorunlu alanlar (function/deficiency/excess/source) ve kategoriye göre beklenen sayı dolu.
- Widget: liste sekmeleri, detay ekranı bölümleri ve uyarı görünür. UI emülatörde ekran görüntüsüyle doğrulanır.

## Builder'a bırakılanlar (benim kararlarım)
- JSON kayıt sayısı/ayrıntı düzeyi; arama basit alt-dize eşleşmesi.
- Profil kartının tam yeri ve ikonu mevcut profil düzenine göre.
- Dosya adları ve provider isimleri proje desenine göre.

## Açık nokta
- Kart yeri Profil dışında bir yer olsun istenirse (ör. Öğünler ekranı) değişir; şu an varsayım: Profil.
