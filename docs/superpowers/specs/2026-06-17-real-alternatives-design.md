# Spec — Gerçek Alternatifler (#1)

- **Tarih:** 2026-06-17
- **Durum:** Onaylandı (brainstorm), plan bekliyor
- **Özellik:** Ürün detayında, aynı kategorideki daha sağlıklı muadilleri göster.

## Amaç
Mevcut "alternatifler" sekmesi sadece bir bilgi placeholder'ı. Hedef: bir ürünü açınca **aynı kategorideki, kendinden daha yüksek HP skorlu** ürünleri (en sağlıklı üstte) listelemek — kullanıcıyı daha iyi seçime yönlendirmek (Yuka mantığı).

## Brainstorm kararları
- Alternatif tanımı: **aynı kategori + daha sağlıklı** (HP skoruna göre sıralı).
- Kategori kaynağı: **Gemini otomatik tahmin + düzeltilebilir dropdown** (kullanıcı ürünleri); OFF ürünleri `categoriesTags`'ten eşlenir.
- Havuz: yalnızca `community_products` (büyüyen TR korpusu; taranan OFF ürünleri zaten oraya import ediliyor). Canlı OFF sorgusu kapsam dışı.

## Veri modeli
- `community_products` tablosuna tek kanonik **`category text`** kolonu + B-tree index (`category, hp_score`).
- Migration: `supabase/migrations/<ts>_community_products_category.sql`.

### Kategori doldurma
- **Kullanıcı ürünleri:** Kayıt formuna (`edit_product_screen.dart`) kategori **dropdown**'u. Form, ad + içindekiler dolduğunda `gemini-proxy`'nin yeni **`classify_category`** aksiyonunu çağırıp dropdown'u otomatik seçer; kullanıcı değiştirebilir. Kayıtta dropdown değeri `category` olarak yazılır.
- **OFF ürünleri:** `categoriesTags` → kanonik kategori eşleme (Dart `Map<String,String>`, örn. `en:milks → süt`, `en:biscuits → bisküvi`). `autoImportFromApi` ve normal çözümleme sırasında set edilir.
- **Boş kalırsa:** `category = null` → alternatif gösterilmez (fallback mesaj).

### Curated kategori listesi (~20, ayarlanabilir)
süt, yoğurt, peynir, tereyağı/margarin, bisküvi/kraker, çikolata, şekerleme, cips/atıştırmalık, kuruyemiş, gazlı içecek, meyve suyu, su/maden suyu, kahve/çay, ekmek/unlu mamul, kahvaltılık gevrek, makarna/bakliyat, hazır yemek/konserve, sos, reçel/bal, et/şarküteri, dondurma, diğer.

## Eşleştirme sorgusu (Supabase)
```
category = :cat AND hp_score > :currentHp AND barcode <> :self
order by hp_score desc
limit 5
```
- HP skoru null olan satırlar hariç.
- Sonuç boşsa: "Bu kategoride daha sağlıklı alternatif bulunamadı" (mevcut tip-card fallback'i korunur).

## Mimari (Clean Arch)
- **domain:** `GetAlternativesUseCase(ProductEntity)` → `ProductRepository.getAlternatives(...)`.
- **data:** `AlternativesSource` (community_products sorgusu) + OFF→kategori mapper util.
- **presentation:** `alternativesProvider(barcode)` (FutureProvider.family). Placeholder yerine **alternatif ürün kartları**: görsel, ad, marka, HP rozeti, "+N puan daha sağlıklı" etiketi. Kart tıklaması → ilgili ürün detayına. Her kartta küçük **"Kıyasla"** butonu (#2'ye hook; #2 gelene kadar gizli/pasif).

## Sınır durumlar
- Kategori null / eşleşme yok → fallback mesaj.
- Kendi barkodunu hariç tut.
- HP null ürünleri ele.
- Az ürün → kısa liste (limit 5).

## Bağımlılıklar / sonra doldurulacak
- `gemini-proxy` içinde `classify_category` aksiyonu (prompt + sabit kategori listesi, Flash).
- OFF `categoriesTags` → kanonik kategori eşleme tablosunun ilk sürümü (en sık ~50 etiket).

## Kapsam dışı
- Canlı OFF alternatif sorgusu.
- Çoklu kategori / alt-kategori hiyerarşisi (tek kanonik kategori yeterli).
