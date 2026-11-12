# Su kartı en üstte + tek dokunuşla bardak — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Su kartını Öğünler sekmesinin en üstüne al, karta "+1 bardak" butonu ekle, `water_glass_added` olayına kaynak bilgisi koy.

**Architecture:** Yalnız mevcut widget'lar ve controller değişir; yeni dosya yok (test hariç). Sıra `MealsScreen` sliver listesinde, buton `WaterCard` üst satırında, kaynak `WaterController.addGlass` parametresinde.

**Tech Stack:** Flutter, Riverpod, flutter_test, mocktail.

**Spec:** `docs/superpowers/specs/2026-11-12-water-card-top-design.md`

## Global Constraints
- Dal: `feat/water-card-top`. **Commit ve push yok** (Fatih).
- Yeni metin yok: buton `l10n.waterAddGlass` ("+1 bardak") kullanır.
- `source` değerleri tam olarak: `card_button`, `glass`, `screen_button`.
- Ramazan/oruç kartlarının birbirine göre sırası değişmez.

## Review Focus
- Hedef aşılınca (ör. 11/10) buton hâlâ çalışır, sınır yok → Task 2 testi.
- Butona dokunmak su ekranını açmamalı (kart `onTap`'i ile çakışma) → Task 2 testi.
- İlk bardakta hatırlatma sorusu butonla da tek sefer çıkar → mevcut davranış, `addWaterGlass` paylaşıldığı için değişmez; Task 2 testi.
- Dar ekran / büyük yazı: buton ilerleme metnini taşırmasın → cihazda ekran görüntüsüyle (Task 4).
- Kalori grafiği kart altında da çalışır → mevcut `meals_screen_chart_test` geçmeli.

---

### Task 1: `water_glass_added` kaynak bilgisi

**Files:**
- Modify: `lib/features/water/presentation/providers/water_provider.dart` (`addGlass`)
- Modify: `lib/features/water/presentation/water_actions.dart` (`addWaterGlass`)
- Modify: `lib/features/water/presentation/widgets/water_glasses.dart`, `lib/features/water/presentation/screens/water_screen.dart` (çağıranlar)
- Test: `test/features/water/water_controller_test.dart`

**Interfaces — Produces:**
- `Future<WaterDay?> WaterController.addGlass(WaterReminderCopy copy, {String source = 'glass'})` → `track(FunnelEvents.waterGlassAdded, props: {'source': source})`
- `Future<void> addWaterGlass(BuildContext context, WidgetRef ref, {required String source})`

- [ ] Test: `'+1 kaynagi olaya yazar'` — `addGlass(_copy, source: 'card_button')` sonrası `analytics.props[FunnelEvents.waterGlassAdded]` == `{'source': 'card_button'}`.
- [ ] Çalıştır → FAIL (`source` parametresi yok).
- [ ] Uygula; `WaterGlasses` → `source: 'glass'`, su ekranı butonu → `source: 'screen_button'`.
- [ ] `flutter test test/features/water/` → PASS.

### Task 2: `WaterCard` üzerinde "+1 bardak" butonu

**Files:**
- Modify: `lib/features/water/presentation/widgets/water_card.dart`
- Test: `test/features/water/water_card_test.dart`

**Interfaces — Consumes:** `addWaterGlass(context, ref, source: 'card_button')`.

- [ ] Testler:
  - `'+1 bardak butonu bir bardak ekler'` — `find.widgetWithText(FilledButton, '+1 bardak')` dokun → `'1 / 10 bardak'`, analytics `source == 'card_button'`.
  - `'buton hedef asilinca da ekler'` — hedef 1, iki dokunuş → `'2 / 1 bardak'`.
  - `'buton su ekranini acmaz'` — GoRouter'lı harness yerine: dokunuştan sonra `find.byType(WaterCard)` hâlâ görünür ve navigator push yok.
  - `'butonla ilk bardakta hatirlatma sorusu cikar'` — `'2 saatte bir hatırlatayım mı?'` görünür.
- [ ] Çalıştır → FAIL (buton yok).
- [ ] Uygula: üst satırda eksi `IconButton`'dan sonra `FilledButton.tonal` (kompakt), metin `l10n.waterAddGlass`.
- [ ] `flutter test test/features/water/` → PASS.

### Task 3: Kart Öğünler sekmesinin en üstünde

**Files:**
- Modify: `lib/features/meals/presentation/screens/meals_screen.dart` (sliver sırası)
- Test: `test/features/meals/presentation/meals_screen_chart_test.dart`

- [ ] Test: `'su karti kalori grafiginin ustunde'` — `tester.getTopLeft(find.byType(WaterCard)).dy < tester.getTopLeft(find.text('Hafta')).dy`.
- [ ] Çalıştır → FAIL.
- [ ] Uygula: `WaterCard` sliver'ını `CozyHeader`'ın hemen altına taşı, padding `fromLTRB(20, 8, 20, 18)`; `_CalorieInsights` üst boşluğu `0`.
- [ ] `flutter test test/features/meals/` → PASS.

### Task 4: Doğrulama
- [ ] `flutter analyze` → "No issues found!"
- [ ] `flutter test` → hepsi geçer.
- [ ] Cihaz/emülatörde Öğünler sekmesi ekran görüntüsü: açık tema + büyük yazı ölçeği; kart en üstte, buton taşmıyor.
