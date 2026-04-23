# NutriLens — Claude Code Bağlam Dosyası

## Proje Özeti
Flutter mobil uygulama. Barkod tarayarak ürün içeriklerini analiz eder,
HP Score (0-100) üretir. Türkiye pazarı odaklı.

**Stack:** Flutter, Riverpod, Drift, GoRouter, fpdart, Supabase, Clean Architecture

**HP Score:**
```
HP Score = (Chemical Load x 0.50) + (Risk Factor x 0.30) + (Nutri Factor x 0.20)
```
Katsayılar → `lib/core/constants/score_constants.dart`

**Barkod zinciri:** Kendi DB → Open Food Facts → 3. parti API → OCR → Topluluk DB

---

## Geliştirici Profili
- Teknik seviye yüksek — temel şeyleri açıklama, stratejik seviyede konuş
- Kısa ve eyleme dönük yanıtlar ver
- Her önerinin sonunda somut bir sonraki adım belirt
- Yeni bir özellik veya karar öncesi: prensip → analitik → sezgi sırasını takip et

---

## Hafıza Sistemi

Bu projenin kalıcı hafızası Obsidian vault'unda tutulur.

**Vault yolu:**
```
C:\Users\m_fat\OneDrive\Belgeler\Obsidian Vault\NutriLens\context\
```

### Oturum başında oku:
- `03-current-sprint.md`  → Ne üzerinde çalışıyoruz
- `04-problems-open.md`   → Açık sorunlar
- `05-ai-handoff.md`      → Genel bağlam

### Oturum boyunca güncelle:

| Durum | Dosya |
|---|---|
| Yeni teknik/ürün kararı alındı | `02-decisions-log.md` |
| Sprint görevi tamamlandı | `03-current-sprint.md` → checkbox işaretle |
| Yeni sorun keşfedildi | `04-problems-open.md` → ekle |
| Sorun çözüldü | `04-problems-open.md`'den kaldır, `02-decisions-log.md`'ye çözüm notu ekle |
| Sprint değişti | `03-current-sprint.md` → güncelle |

### Güncelleme formatı (decisions-log):
```
## YYYY-MM | Karar başlığı
**Karar:** Ne yapıldı
**Gerekçesi:** Neden yapıldı
```

### Güncelleme formatı (problems-open):
```
### Sorun başlığı
**Sorun:** Ne oluyor
**Etki:** Ne etkileniyor
**Sonraki adım:** Ne yapılacak
```

---

## Master Bağlam
Geliştirici hakkında genel bağlam için:
```
C:\Users\m_fat\OneDrive\Belgeler\Obsidian Vault\Proje Prensipleri\02-ai-handoff.md
```
