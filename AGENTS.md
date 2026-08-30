# NutriLens — Context & Rules

## Proje Özeti
Flutter mobil uygulama. Barkod tarama & yemek fotoğrafı analizi ile içerik inceleme ve HP Score (0-100) üretimi (TR odaklı).
**Stack:** Flutter, Riverpod, Drift, GoRouter, fpdart, Supabase, Clean Architecture.

**HP Score (v4):**
`raw = 100 - (ChemLoad x 0.45) - (RiskFactor x 0.40) + (NutriFactor x 0.15) - penalty`
`HP Score = 10 (kritik) | min(raw, 54.9) (etkin NOVA 4) | raw`
*Detay & DB Trigger:* [[02-hp-score]]

**Zincir:** Kendi DB -> Open Food Facts -> 3. parti API -> OCR -> Topluluk DB.

---

## Geliştirici & Kodlama Prensipleri
- Teknik seviye yüksek, stratejik konuş, kısa ve eyleme dönük ol.
- Prensip: Varsayım gizleme (önce sor), minimum kod (cerrahi müdahale), doğrulanabilir hedef.

---

## Hafıza & Bağlam (Obsidian)
**Vault:** `C:\Users\m_fat\OneDrive\Belgeler\Obsidian Vault\NutriLens\wiki\`

### On-Demand Okuma Stratejisi:
- **Oturum Başında:** Sadece `05-ai-handoff.md` oku.
- **İhtiyaç Halinde Aç:**
  - Aktif sprint/görev -> `03-current-sprint.md`
  - Açık sorun/blokaj -> `04-problems-open.md`
  - Mimari & Şemalar -> `architecture/` | Kurallar -> `schema/_schema.md`
- **Master Bağlam:** `Proje Prensipleri/wiki/02-ai-handoff.md`

### Token Disiplini:
- `02-decisions-log.md` (128KB): asla tam okuma, grep ile ara.
- `docs/plans/` + `docs/superpowers/`: sadece aktif feature planı; bitmişler vault `archive/`'de.
- `graphify-out/GRAPH_REPORT.md`: sadece istenirse oku.
- Büyük dosya: offset/limit ile parça parça.

---

## İletişim Tarzı (Caveman Mode)
Respond terse like smart caveman. All technical substance stay. Only fluff die.
- Drop articles, fillers, pleasantries. Short synonyms. Exact technical terms & code.
- Pattern: [thing] [action] [reason]. [next step].