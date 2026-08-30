# NutriLens — Claude Code Context

## Proje Özeti
Flutter mobil uygulama. Barkod tarama & AI yemek analizi ile HP Score (0-100) üretimi.
**Stack:** Flutter, Riverpod, Drift, GoRouter, fpdart, Supabase, Clean Architecture.
**HP Score (v4):** Detay -> `wiki/architecture/02-hp-score.md` (Postgres trigger ile senkron tut).

---

## Sürüm & Build
- **Android Release:** `pwsh scripts/build_android_release.ps1` (asla çıplak `flutter build appbundle` yapma; Sentry DSN ve AdMob env'den geçer).
- **Detaylı release & sürüm kuralları:** `wiki/release/store-release-checklist.md`

---

## Kodlama Prensipleri (Karpathy)
1. **Varsayım gizleme:** Belirsizlik varsa önce sor.
2. **Minimum kod:** İstenen kadar yaz, gereksiz soyutlama yapma.
3. **Cerrahi değişiklik:** Sadece hedefe dokun, komşu kodu bozma.
4. **Doğrulanabilir hedef:** Başarı kriterini netleştir.

---

## Hafıza & Bağlam (Obsidian)
**Vault:** `C:\Users\m_fat\OneDrive\Belgeler\Obsidian Vault\NutriLens\wiki\`
- **Başlangıç:** Yalnızca `wiki/05-ai-handoff.md` oku.
- **On-Demand:** `wiki/03-current-sprint.md` (sprint), `wiki/04-problems-open.md` (blokajlar), `wiki/02-decisions-log.md` (kararlar).
- **Formatlar & Kurallar:** `schema/_schema.md`

---

## Token Disiplini
- `wiki/02-decisions-log.md` (128KB): **asla tam okuma** — grep ile ilgili kararı bul, sadece o bölümü oku.
- `docs/plans/` + `docs/superpowers/`: yalnızca aktif feature'ın planını oku; bitmiş planlar vault `archive/`'de.
- `graphify-out/GRAPH_REPORT.md`: yalnızca açıkça istenirse oku; aksi halde harcanmaz.
- Büyük dosya gerekirse offset/limit ile parça parça oku.

---

## Araçlar
- **Graphify:** Kod yapısı için `graphify-out/GRAPH_REPORT.md`. Kod değişiminden sonra: `graphify update .`
- **Task Observer:** Oturum boyu çalışma kalıplarını ve gözlemleri izle.