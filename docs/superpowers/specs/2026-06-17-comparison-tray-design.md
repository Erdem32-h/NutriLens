# Spec — Kıyaslama Tepsisi (#2)

- **Tarih:** 2026-06-17
- **Durum:** Onaylandı (brainstorm), plan bekliyor
- **Özellik:** Kullanıcının seçtiği 2 ürünü yan yana (versus tarzı) karşılaştırma.

## Amaç
Kullanıcı favorilerinden veya bir ürün detayından 2 ürünü seçip besin/HP özelliklerini yan yana görsün; her satırda hangi ürünün daha iyi olduğu vurgulansın.

## Brainstorm kararları
- Format: **2 ürün, sabit yan yana** (3+ ve kalıcı kıyas listesi kapsam dışı).
- Giriş noktaları: **favoriler (çoklu seçim) + ürün detayı/alternatif kartı ("Kıyasla")**.

## Seçim akışı
- **Favoriler:** AppBar'da "Kıyasla" ikonu → *seç modu*. Tile'lar checkbox; en fazla 2 seçim; altta "Kıyasla (2/2)" butonu → kıyas ekranı.
- **Ürün detayı / alternatif kartı:** "Kıyasla" butonu → `ProductPickerSheet` (favoriler + son geçmiş) → 2. ürün → kıyas ekranı. (#1 alternatif hook'u buraya bağlanır.)

## Kıyas ekranı (`/compare`)
- 2 sütun. Üstte yan yana ürün başlıkları (görsel, ad, marka, HP gauge) — scroll'da **sticky**.
- Satır satır karşılaştırma; her satırda **daha iyi taraf yeşil vurgulu (✓)**.

### Satırlar ve "daha iyi" yönü
| Satır | Daha iyi |
|---|---|
| HP Skoru | yüksek |
| Enerji (kcal) | düşük |
| Yağ | düşük |
| Doymuş yağ | düşük |
| Şeker | düşük |
| Tuz | düşük |
| Protein | yüksek |
| Lif | yüksek |
| NOVA grubu | düşük (1↔4) |
| Katkı maddesi sayısı | düşük |
| Nutri-Score | A→E |

- En altta **"Paylaş"** butonu (#3 hook).

## Mimari (Clean Arch / Riverpod)
- **domain/util:** `comparisonMetrics(ProductEntity a, ProductEntity b)` → saf fonksiyon; `List<ComparisonRow(label, valueA, valueB, betterSide, format)]`. Her metriğin yönü burada; **unit-test edilebilir** (%80 coverage hedefi).
- **presentation:**
  - `ComparisonScreen` (route `/compare`, iki barkod `extra` ile geçer).
  - `comparisonProvider` — iki barkodu mevcut `productByBarcodeProvider` ile çeker (yeni data katmanı yok).
  - `ProductPickerSheet` — `favoritesProvider` + `historyProvider`; tekrar kullanılabilir.
  - Favoriler seç-modu → ekran içi local state (`FavoritesScreen`).

## Sınır durumlar
- Eksik veri (null) → "—", o satırda vurgu yok.
- AI tahmini öğünler (`ai_` barkod) kıyasa girebilir; eksik alanlar "—".
- Aynı ürünü iki kez seçmeyi engelle.

## Kapsam dışı
- 3+ ürün kıyası, kalıcı kıyas listesi/sepeti.
