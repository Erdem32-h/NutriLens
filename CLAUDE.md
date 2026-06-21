# NutriLens — Claude Code Bağlam Dosyası

## Proje Özeti
Flutter mobil uygulama. Barkod tarayarak ürün içeriklerini analiz eder,
HP Score (0-100) üretir. Türkiye pazarı odaklı.

**Stack:** Flutter, Riverpod, Drift, GoRouter, fpdart, Supabase, Clean Architecture

**HP Score (v3):**
```
HP Score = 100 − (Chemical Load × 0.45) − (Risk Factor × 0.40) + (Nutri Factor × 0.15) − ingredientQualityPenalty
```
Detay → `wiki/architecture/02-hp-score.md`

**Barkod zinciri:** Kendi DB → Open Food Facts → 3. parti API → OCR → Topluluk DB
Detay → `wiki/architecture/03-barkod-zinciri.md`

---

## Geliştirici Profili
- Teknik seviye yüksek — temel şeyleri açıklama, stratejik seviyede konuş
- Kısa ve eyleme dönük yanıtlar ver
- Her önerinin sonunda somut bir sonraki adım belirt
- Yeni özellik öncesi: varsayımları yüzeye çıkar, önce sor

---

## Kodlama Prensipleri (Karpathy Guidelines)

1. **Varsayım gizleme** — Belirsizlik varsa önce sor, sonra yaz.
   Birden fazla yorum varsa hepsini sun, sessizce seçme.

2. **Minimum kod** — İstenen kadar, fazlası değil.
   Tek kullanımlık kod için soyutlama yapma.
   200 satır yazıp 50'ye düşürebiliyorsan, düşür.

3. **Cerrahi değişiklik** — Sadece istenen yere dokun.
   Komşu kodu "iyileştirme" adına değiştirme.

4. **Doğrulanabilir hedef** — Her görev için başarı kriteri tanımla.

---

## Hafıza Sistemi (Obsidian Vault)

**Vault yolu:**
```
C:\Users\m_fat\OneDrive\Belgeler\Obsidian Vault\NutriLens\
```

### Vault Yapısı
```
wiki/
  00-project-overview.md   ← Proje özeti
  01-tech-stack.md         ← Stack özeti
  02-decisions-log.md      ← Kararlar
  03-current-sprint.md     ← Aktif görevler
  04-problems-open.md      ← Açık sorunlar
  05-ai-handoff.md         ← AI oturum özeti
  architecture/
    00-sistem-mimarisi.md
    01-veritabani-semasi.md
    02-hp-score.md         ← HP Score detayı (GÜNCEL KAYNAK)
    03-barkod-zinciri.md
  features/
    barkod-tarama.md
    gecmis-favoriler.md
    katki-maddesi.md
    ogünlerim.md
    premium.md
    sahte-urun.md
  release/
    store-release-checklist.md
raw/                       ← Ham notlar (AI'a verilmez)
schema/
  _schema.md               ← Vault kuralları
```

### Oturum başında oku:
- `wiki/03-current-sprint.md`       → Aktif görevler
- `wiki/04-problems-open.md`        → Açık sorunlar
- `wiki/05-ai-handoff.md`           → Genel bağlam

### Oturum boyunca güncelle:

| Durum | Dosya |
|---|---|
| Teknik/ürün kararı | `wiki/02-decisions-log.md` |
| Sprint görevi tamamlandı | `wiki/03-current-sprint.md` |
| Yeni sorun | `wiki/04-problems-open.md` |
| Sorun çözüldü | `wiki/04-problems-open.md`'den sil + `wiki/02-decisions-log.md`'ye ekle |
| Mimari değişti | `wiki/architecture/` altındaki ilgili dosyayı güncelle |
| Yeni özellik tasarlandı | `wiki/features/` altına yeni dosya ekle |

### ⚠️ Önemli
`wiki/architecture/02-hp-score.md` HP Score için **tek ve güncel kaynak.**
`wiki/01-tech-stack.md` içindeki HP Score özeti eskimiş olabilir —
çelişki varsa `architecture/02-hp-score.md`'yi esas al.

---

## Master Bağlam
```
C:\Users\m_fat\OneDrive\Belgeler\Obsidian Vault\Proje Prensipleri\wiki\02-ai-handoff.md
```
