# NutriLens — Türkçe ASO Paketi (Play Store & App Store)

> **Durum:** Kopyala-yapıştır hazır (2026-11-13). Karakter sınırları Python ile doğrulandı.
> **Not:** `Ramazan` modu 5 Şub 2027'ye kadar gizli olduğu için Kasım metnine eklenmedi; Ocak sonu güncellemesi aşağıda ayrı tutuldu.

---

## 1. Google Play Store (`tr-TR`)

### Uygulama Adı (`26 / 30` karakter)
```text
NutriLens: Barkod & Kalori
```

### Kısa Açıklama (`71 / 80` karakter)
```text
Barkod tara, katkı maddesi ve tağşiş kontrol et; tabağından kalori say.
```

### Uzun Açıklama (`1.885 / 4.000` karakter)
```text
Market rafında etiketi çözmeye çalışmak zorunda değilsin. NutriLens ile ürün barkodunu okut; içindekiler listesini, katkı maddelerini (E kodlarını), alerjenleri ve 0–100 arası Sağlık Puanı'nı (HP Score) saniyeler içinde gör. Evde ya da dışarıda yediğin öğünlerin fotoğrafını çek, kalori ve makro takibini aynı uygulamada tut.

Neden NutriLens?

• Barkod & QR Tarama ile Anlık Analiz
Paketin barkodunu veya yeni nesil ambalaj QR kodunu (GS1 Digital Link) okut. Ürün veritabanında yoksa içindekiler ve besin tablosunun fotoğrafını çek, yapay zekâ senin için çözsün.

• 0–100 Sağlık Puanı (HP Score) ve Açık Kırılım
Her puanın arkasında ne olduğu gizlenmez. Katkı maddesi yükü, işlenmişlik düzeyi (NOVA), şeker/yağ/tuz dengesi ve besin kalitesinin puanı nasıl etkilediğini sade Türkçeyle görürsün.

• Taklit ve Tağşiş Kontrolü (Türkiye'ye Özel)
Tarım ve Orman Bakanlığı'nın yayımladığı taklit ve tağşiş listeleriyle eşleşen marka ve parti kayıtları için tarama ekranında anında uyarı görürsün.

• Katkı Maddesi (E Kodu) ve Alerjen Uyarıları
E kodlarının ne anlama geldiğini ve risk düzeyini incele. Gluten, laktoz, kuruyemiş gibi kişisel alerjen ve hassasiyetlerini profiline ekle; sana uymayan ürünlerde önceden uyarıl.

• İki Ürünü Yan Yana Karşılaştır & Alternatif Bul
Aynı raftaki iki ürün arasında kararsız kaldığında HP Score ve besin değerlerini tek ekranda kıyasla. Düşük puanlı bir ürün için daha temiz içerikli gerçek alternatif önerilerini gör.

• Fotoğrafla Kalori Sayacı, Su ve Aralıklı Oruç Takibi
Tabağının fotoğrafını çekerek tahmini kalori, protein, karbonhidrat ve yağ değerlerini günlüğüne kaydet. "Bugün" özetinden tek dokunuşla içtiğin suyu ekle, istersen 16:8, 18:6, 20:4 veya OMAD aralıklı oruç sayacını başlat.

Not: NutriLens bilgilendirme amaçlıdır; ürün ambalajı verilerine ve kamuya açık resmi listelere dayanır, tıbbi tanı veya tedavi tavsiyesi yerine geçmez.
```

---

## 2. Apple App Store (`tr`)

### Name (`26 / 30` karakter)
```text
NutriLens: Barkod & Kalori
```

### Subtitle (`28 / 30` karakter)
```text
Katkı Maddesi, Tağşiş & Öğün
```

### Promotional Text (`154 / 170` karakter — incelemesiz güncellenebilir)
```text
Barkodu okut: katkı maddesi, taklit-tağşiş kontrolü ve sağlık puanını gör. Tabağını çek kalorisini ölç, tek dokunuşla suyunu ve aralıklı orucunu takip et.
```

### Keywords (`98 / 100` karakter — Name/Subtitle kelimeleri tekrar edilmedi)
```text
ekod,içindekiler,sayacı,diyet,sağlık,beslenme,alerjen,gluten,şeker,su,oruç,taklit,kıyas,makro,gıda
```

### Description
Google Play Uzun Açıklama metni birebir kullanılabilir (karakter sınırı aynı: 4.000).

---

## 3. Ekran Görüntüsü Sıralaması (İlk 3 Kart Kritik)

Mevcut `tools/generate_store_assets.py` 5 görsel üretiyor; dönüşüm için ilk 3 sıraya Türkiye'deki en güçlü 3 farklı kanca konmalı:

1. **Kart 1 (Kanca):** Barkod okuma + 0–100 HP Score kırılımı (`"Barkodu okut, gerçek puanını gör"`)
2. **Kart 2 (Fark):** Taklit/Tağşiş uyarısı + 2 ürün yan yana kıyas (`"Aynı rafta hangisi daha temiz?"`)
3. **Kart 3 (Katkı):** E kodları & alerjen çözümlemesi (`"Arka etiketteki E kodlarının Türkçesi"`)
4. **Kart 4 (Günlük alışkanlık):** Fotoğrafla öğün kalorisi + "Bugün" su kartı (`"Tabağını çek, kalorini ve suyunu tut"`)
5. **Kart 5 (Alternatif/Geçmiş):** Daha yüksek puanlı ürün önerisi + favoriler

---

## 4. Ocak Sonu 2027 — Ramazan Güncelleme Notu (Promotional Text)

Ramazan modu 5 Şub 2027'de açıldığında sadece App Store Promotional Text (`≤170`) + yeni ekran görüntüsüyle güncellenir:

```text
Ramazan'da sahur ve iftar öğünlerini fotoğrafla takip et, su hedefini koru. Market alışverişinde barkodu okut; katkı maddesi ve tağşiş kontrolünü saniyeler içinde yap.
```
*(167 / 170 karakter — doğrulandı.)*
