# Spec — Paylaşma (Markalı Share Kartı) (#3)

- **Tarih:** 2026-06-17
- **Durum:** Onaylandı (brainstorm), plan bekliyor
- **Özellik:** Ürün detayını ve öğünü, üretilen markalı bir görsel kart olarak sosyal medyada paylaşma.

## Amaç
Kullanıcı bir ürünün/öğünün şık, markalı bir kartını tek dokunuşla sosyal medyada paylaşsın (Instagram, WhatsApp vb.) — marka görünürlüğü + organik büyüme.

## Brainstorm kararları
- Format: **markalı, üretilen görsel kart** (screenshot değil).
- Oran: **kare 1:1** (1080×1080) — feed + story uyumlu, tek varyant.
- Deep link: kapsam dışı (QR/altyazı şimdilik sadece mağaza linki metni).

## Kart içeriği
- **Ürün kartı:** ürün görseli, ad + marka, HP skoru rozeti (renk = skor kademesi), 3 anahtar çip (örn. "Az şeker", "Katkı: N", "NOVA n"), "NutriLens ile tarandı" altyazısı + dekoratif QR/logo.
- **Öğün kartı:** yemek fotoğrafı, yemek adı, kalori + makrolar (protein/karbonhidrat/yağ), porsiyon; aynı çerçeve.
- Kart **sabit aydınlık/marka paleti** kullanır (uygulamanın dark teması değil) — sosyalde tutarlı ve okunur görünsün.

## Teknik yaklaşım
- Paket: **`share_plus`** (pubspec'e eklenir).
- Render: ekran dışı (`Overlay`/`Offstage`) `RepaintBoundary` + `GlobalKey` → `RenderRepaintBoundary.toImage(pixelRatio)` ile 1080px PNG → temp dosyaya yaz → `SharePlus.share(files + caption)`.
- Altyazı metni: örn. `"<ürün> — HP Skoru 82/100 · NutriLens ile tarandı · <mağaza linki>"`.

## Mimari
- **core/services:** `ShareService` — verilen widget'ı görsele çevirip paylaşır (capture + temp file + share). Tekrar kullanılabilir.
- **presentation/widgets:** `ProductShareCard`, `MealShareCard` (saf, sabit boyutlu render widget'ları).
- **Buton konumları:** `product_detail_screen` (AppBar), `food_result_screen` (AppBar), `ComparisonScreen` (#2, kıyas kartı opsiyonel ileride).

## Sınır durumlar
- Görsel yok → markalı placeholder.
- Eksik veri → ilgili çipi/satırı gizle.
- Network görseli (ürün) → paylaşmadan önce yüklenmesini bekle (precache), aksi halde boş çıkar.
- iOS/Android share sheet farkları → `share_plus` soyutlar.

## Kapsam dışı
- Deep link / app-links altyapısı.
- Story (9:16) varyantı, çoklu oran seçimi.
- Kıyas (#2) ekranının paylaşımı (hook bırakılır, sonra).
