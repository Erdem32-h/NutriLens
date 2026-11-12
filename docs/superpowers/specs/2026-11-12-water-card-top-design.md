# Su kartı en üstte + tek dokunuşla bardak — Tasarım (kısa)

**Tarih:** 2026-11-12 · **Durum:** Fatih onayladı (yaklaşım A)

## Niyet
Günde 3-4 AI isteğine düşen kullanım için tutunma kaldıracı su takibi. Su ekleyen
cihazlar ortalama 3,1 gün aktif, diğerleri 1,7 (60 gün, ilişki — nedensellik değil).
Ama su kartı Öğünler sekmesinde 6. sırada; misafirlerin %21'i su ekliyor
(30 gün, 112'de 24). Hedef: daha çok yeni kullanıcı suya başlasın.

## Hedef / hedef dışı / anti-hedef
- **Hedef:** misafir → aynı gün `water_glass_added` oranı %21'den yukarı.
- **Hedef dışı:** hatırlatıcı zamanlaması, "bugün" kartı, boş gün ekranı (B yolu),
  onboarding değişikliği.
- **Anti-hedef:** öğün kaydını zorlaştırmak; kartın gün içinde yer değiştirmesi.

## Yaklaşımlar
- **A (seçildi):** kart başlığın hemen altına; karta görünür "+1 bardak" butonu.
  Küçük, doğrudan ölçülür. Eksi: kalori grafiği biraz aşağı iner.
- **B:** öğünsüz gün için boş ekran (öğün + su). Daha büyük; "kaydetmeyi varsayılan
  yap" önerisiyle karışır, etkiler ayrılamaz. A ölçüldükten sonra.
- **C:** ayrı sekme / onboarding adımı. Elendi: onboarding en büyük kayıp noktası.

## Tasarım
1. `MealsScreen`: `WaterCard` başlığın hemen altına, `_CalorieInsights`'ın üstüne.
   Ramazan/oruç kartlarının sırası değişmez.
2. `WaterCard`: üst satırda eksi butonunun yanına dolgulu "+1 bardak" butonu
   (mevcut `waterAddGlass` metni, 6 dilde var). Bardak ikonları aynen çalışır;
   karta dokunmak yine su ekranını açar.
3. Ölçüm (benim kararım): `water_glass_added` olayına `source` alanı —
   `card_button` | `glass` | `screen_button`. Butonun işe yarayıp yaramadığını
   ayırmanın tek yolu bu.

## Başarı ölçütü
1.5.3 yayınından ~2 hafta sonra: misafir → aynı gün su oranı ve
`source=card_button` payı.
