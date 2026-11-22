# Besin Rehberi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Profil'den açılan, vitamin / mineral / amino asit bilgi kütüphanesi (işlev, eksiklik, fazlalık, kaynaklar, günlük ihtiyaç) ekle.

**Architecture:** İçerik tek bir gömülü `assets/nutrients/nutrients.json`. `lib/features/nutrient_guide/` altında domain (entity + repository arayüzü), data (parser + asset repository) ve presentation (Riverpod provider'lar, liste ve detay ekranı). Sunucu, Drift, Supabase ve HP Score'a dokunulmaz.

**Tech Stack:** Flutter, Riverpod (`FutureProvider`), GoRouter, `equatable`, `gen-l10n`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-23-nutrient-guide-design.md`

## Global Constraints
- İçerik dilleri: `tr` ve `en` eksiksiz; `tr` dışındaki tüm UI dilleri (ar/en/es/pt/zh) içerikte İngilizceye düşer (`Localized.of`).
- Kapsam: 13 vitamin, 14 mineral, 9 temel amino asit (tam id listeleri Task 4–6'da). Her kayıtta `source` (ör. "NIH ODS", "EFSA") zorunlu.
- UI string'leri `lib/l10n/app_*.arb` içinde; şablon `app_tr.arb`. `tr` dışı arb'lere **İngilizce metin** yazılır (eksik anahtar şablonun Türkçesine düşer, bu istenmiyor). Üretilen dosyalar commit'lenir: `flutter gen-l10n`.
- Detay ekranında her zaman "tıbbi tavsiye değildir" uyarısı.
- Tema: `context.colors` / `context.l10n`; widget testleri `AppTheme.light` + `AppLocalizations` delege'leriyle (bkz. `test/features/profile/analytics_opt_out_tile_test.dart`).
- Mevcut `NutrimentsEntity`, Drift, Supabase şeması değişmez.
- Commit adımları yalnızca Fatih commit istediyse çalıştırılır; dosyalar tek tek eklenir; mesajın sonuna `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## Review Focus
1. Arama Türkçe karakterleri katlamalı: "iyot" sorgusu "İyot"u, "selenyum" sorgusu "Selenyum"u, "sut" sorgusu "süt"ü bulur (Task 3).
2. Arama sonuç vermezse boş durum mesajı gösterilir, liste çökmez (Task 8).
3. Rotada bilinmeyen `id` → "bulunamadı" gövdesi, çökme yok (Task 9).
4. Asset yüklenemez/bozuksa liste hata durumu + "tekrar dene" gösterir; tekrar deneyince çalışır (Task 2, 8).
5. `ar`/`zh`/`es`/`pt` locale'inde içerik İngilizce görünür, boş metin yok; büyük yazı tipinde (textScale 2.0) detay taşmadan kayar (Task 1, 9).

---

### Task 1: Domain modeli ve parser

**Files:**
- Create: `lib/features/nutrient_guide/domain/entities/nutrient_entity.dart`
- Create: `lib/features/nutrient_guide/data/nutrient_parser.dart`
- Test: `test/features/nutrient_guide/data/nutrient_parser_test.dart`

**Interfaces:**
- Produces:
  - `class Localized<T> extends Equatable { const Localized({required T tr, required T en}); final T tr, en; T of(String languageCode); }` — `of('tr')` → `tr`, diğer her kod → `en`.
  - `enum NutrientCategory { vitamin, mineral, aminoAcid }` (JSON değerleri: `vitamin`, `mineral`, `amino_acid`).
  - `class NutrientEntity extends Equatable`: `String id`, `NutrientCategory category`, `Localized<String> name`, `Localized<String>? altName`, `Localized<String> function`, `Localized<List<String>> deficiency`, `Localized<List<String>> excess`, `Localized<List<String>> sources`, `String dailyNeed`, `String? upperLimit`, `String source`.
  - `List<NutrientEntity> parseNutrients(String jsonSource)` — `{"version","updated_at","nutrients":[...]}`; alan adları: `id`, `category`, `name_tr/en`, `alt_name_tr/en` (ikisi birden ya da hiçbiri), `function_tr/en`, `deficiency_tr/en`, `excess_tr/en`, `sources_tr/en` (string dizileri), `daily_need`, `upper_limit` (opsiyonel), `source`.

- [ ] **Step 1: Failing testler yaz** (`nutrient_parser_test.dart`; satır içi JSON fixture):
  - `parses a complete entry` → `id == 'vitamin_c'`, `category == NutrientCategory.vitamin`, `name.tr == 'C Vitamini'`, `deficiency.en.length == 2`, `upperLimit == '2000 mg'`.
  - `maps amino_acid category` → `NutrientCategory.aminoAcid`.
  - `altName is null when absent`.
  - `Localized.of falls back to en for non-tr locales` → `of('tr')=='tr değer'`, `of('ar')`, `of('zh')`, `of('es')` hepsi `'en value'`.
  - `throws FormatException on malformed json`.
  - `throws FormatException naming the id when a required field is missing or empty` (ör. `function_en` yok; `deficiency_tr: []`) — mesaj id'yi içerir.
  - `throws FormatException on unknown category`.
  - `throws FormatException on duplicate ids`.
  - `throws FormatException when only one of alt_name_tr/alt_name_en is present`.
- [ ] **Step 2: Çalıştır, fail gördüğünü doğrula:** `flutter test test/features/nutrient_guide/data/nutrient_parser_test.dart` → derleme hatası/FAIL.
- [ ] **Step 3: `nutrient_entity.dart` ve `nutrient_parser.dart` yaz.** Parser `dart:convert` `jsonDecode` kullanır, her hatayı `FormatException` olarak fırlatır; boş string ve boş liste "eksik" sayılır.
- [ ] **Step 4: Aynı komut → PASS.**
- [ ] **Step 5: Commit** — `feat(nutrient-guide): add nutrient entity and JSON parser`.

### Task 2: Repository, provider'lar, asset kaydı ve tohum içerik

**Files:**
- Create: `lib/features/nutrient_guide/domain/repositories/nutrient_repository.dart`
- Create: `lib/features/nutrient_guide/data/asset_nutrient_repository.dart`
- Create: `lib/features/nutrient_guide/presentation/providers/nutrient_provider.dart`
- Create: `assets/nutrients/nutrients.json` (tohum: yalnızca `vitamin_c`)
- Modify: `pubspec.yaml` (assets listesine `- assets/nutrients/`, `assets/additives/` satırının yanına)
- Test: `test/features/nutrient_guide/data/asset_nutrient_repository_test.dart`

**Interfaces:**
- Consumes: `parseNutrients`, `NutrientEntity` (Task 1).
- Produces:
  - `abstract class NutrientRepository { Future<List<NutrientEntity>> getAll(); }`
  - `class AssetNutrientRepository implements NutrientRepository { AssetNutrientRepository(AssetBundle bundle, {String assetPath = 'assets/nutrients/nutrients.json'}); }` — başarılı sonucu önbellekler; **hata durumunda önbelleği temizler** ki tekrar deneme çalışsın.
  - `nutrientRepositoryProvider` (`Provider<NutrientRepository>`, `rootBundle`), `nutrientsProvider` (`FutureProvider<List<NutrientEntity>>`), `nutrientByIdProvider` (`FutureProvider.family<NutrientEntity?, String>`; bulunamazsa `null`).

- [ ] **Step 1: Failing testler** (sahte `AssetBundle` ile, `rootBundle` yok):
  - `getAll parses the asset once and caches` → `loadString` çağrı sayısı 1 (iki `getAll` sonrası).
  - `getAll rethrows FormatException for corrupt asset`.
  - `a failed load is not cached: next call succeeds` (ilk `loadString` fırlatır, ikincisi geçerli JSON döner → ikinci `getAll` listeyi döner).
  - `nutrientByIdProvider returns null for unknown id` (`ProviderContainer`, `nutrientRepositoryProvider` override).
- [ ] **Step 2: Çalıştır → FAIL.**
- [ ] **Step 3: Implement.** `assets/nutrients/nutrients.json`'a tek `vitamin_c` kaydı yaz: `daily_need: "75–90 mg"`, `upper_limit: "2000 mg"`, `source: "NIH ODS"`, tr+en tüm alanlar dolu (en az 2 eksiklik, 2 fazlalık, 3 kaynak maddesi). `pubspec.yaml`'a asset klasörünü ekle, `flutter pub get`.
- [ ] **Step 4: Testler → PASS.**
- [ ] **Step 5: Commit** — `feat(nutrient-guide): add asset repository and providers`.

### Task 3: Arama (Türkçe katlama)

**Files:**
- Create: `lib/features/nutrient_guide/domain/nutrient_search.dart`
- Test: `test/features/nutrient_guide/domain/nutrient_search_test.dart`

**Interfaces:**
- Consumes: `NutrientEntity`, `Localized.of`.
- Produces: `String foldForSearch(String input)` ve `List<NutrientEntity> searchNutrients(List<NutrientEntity> all, String query, String languageCode)` — ada (`name`) ve `altName`'e göre, verilen dilde, katlanmış alt-dize eşleşmesi; boş/boşluk sorgusu tüm listeyi aynı sırada döner.

- [ ] **Step 1: Failing testler:**
  - `foldForSearch('İYOT') == foldForSearch('iyot')`, `foldForSearch('ŞEKER') == 'seker'`, `foldForSearch('Süt') == 'sut'`, `foldForSearch('ığüöşç') == 'igusoc'` (`I`, `İ`, `ı` hepsi `i`).
  - `'iyot'` sorgusu `name.tr == 'İyot'` kaydını bulur; `'selenyum'` `Selenyum`'u; `'sut'` bir `alt_name.tr = 'Süt ...'` kaydını bulur.
  - `'  '` ve `''` → tüm liste, aynı sıra.
  - Eşleşmeyen sorgu → boş liste.
  - `languageCode: 'en'` iken `en` adıyla arar (tr adıyla bulmaz).
- [ ] **Step 2: → FAIL.**
- [ ] **Step 3: Implement** (önce `İ`/`I`/`ı`→`i` haritası, sonra `toLowerCase`, sonra `ş→s ğ→g ü→u ö→o ç→c`; sorguyu `trim`'le).
- [ ] **Step 4: → PASS.**
- [ ] **Step 5: Commit** — `feat(nutrient-guide): add Turkish-folding search`.

### Task 4: UI metinleri (6 arb) ve içerik bütünlük testi iskeleti

**Files:**
- Modify: `lib/l10n/app_tr.arb`, `app_en.arb`, `app_ar.arb`, `app_es.arb`, `app_pt.arb`, `app_zh.arb`; çıktı: `lib/l10n/generated/*` (`flutter gen-l10n`)
- Test: `test/features/nutrient_guide/data/nutrients_content_test.dart`

**Interfaces:**
- Produces anahtarlar (tr değeri / en değeri; `ar/es/pt/zh` = en değeri):
  `nutrientGuideTitle` "Besin Rehberi"/"Nutrient Guide", `nutrientGuideSubtitle` "Vitamin, mineral ve amino asitler"/"Vitamins, minerals and amino acids", `nutrientTabVitamins` "Vitaminler"/"Vitamins", `nutrientTabMinerals` "Mineraller"/"Minerals", `nutrientTabAminoAcids` "Amino asitler"/"Amino acids", `nutrientSearchHint` "Besin ara"/"Search nutrients", `nutrientNoResults` "Sonuç bulunamadı"/"No results found", `nutrientSectionFunction` "Ne işe yarar"/"What it does", `nutrientSectionDeficiency` "Eksikse"/"If you get too little", `nutrientSectionExcess` "Fazlaysa"/"If you get too much", `nutrientSectionSources` "Nerede bulunur"/"Where to find it", `nutrientSectionDailyNeed` "Günlük ihtiyaç (yetişkin)"/"Daily need (adult)", `nutrientUpperLimitLabel` "Üst sınır"/"Upper limit", `nutrientDisclaimer` "Bu bilgiler genel bilgilendirme amaçlıdır, tıbbi tavsiye değildir. Sağlık sorunları için bir hekime danışın."/İngilizce karşılığı, `nutrientSourceLabel` "Kaynak: {source}"/"Source: {source}" (`source` String placeholder), `nutrientLoadError` "İçerik yüklenemedi"/"Could not load content", `nutrientRetry` "Tekrar dene"/"Try again", `nutrientNotFound` "Bu besin bulunamadı"/"Nutrient not found".

- [ ] **Step 1: Anahtarları 6 arb dosyasına ekle**, `flutter gen-l10n`, `flutter analyze lib/l10n` temiz.
- [ ] **Step 2: İçerik bütünlük testini yaz** (`nutrients_content_test.dart`, gerçek `assets/nutrients/nutrients.json`'ı `File` ile okur, `parseNutrients` çağırır): `every nutrient has all required fields` (parser zaten doğrular → test parse'ın fırlatmadığını ve her kaydın `source`, `dailyNeed`, `function.tr`, `function.en` boş olmadığını doğrular), `ids are unique`, `expected counts per category` — `const expected = {vitamin: 1, mineral: 0, aminoAcid: 0}` şimdilik (Task 5–7'de güncellenir).
- [ ] **Step 3: `flutter test test/features/nutrient_guide/data/nutrients_content_test.dart` → PASS.**
- [ ] **Step 4: Commit** — `feat(nutrient-guide): add l10n strings and content integrity test`.

### Task 5: İçerik — 13 vitamin

**Files:** Modify `assets/nutrients/nutrients.json`; Modify `test/features/nutrient_guide/data/nutrients_content_test.dart` (beklenen sayı).

İdler (sırayla): `vitamin_a`, `vitamin_b1`, `vitamin_b2`, `vitamin_b3`, `vitamin_b5`, `vitamin_b6`, `vitamin_b7`, `vitamin_b9`, `vitamin_b12`, `vitamin_c` (mevcut), `vitamin_d`, `vitamin_e`, `vitamin_k`. `category: "vitamin"`.

- [ ] **Step 1: Test beklentisini güncelle:** `vitamin: 13`; çalıştır → FAIL (şu an 1).
- [ ] **Step 2: 12 yeni kaydı yaz.** Kurallar: yetişkin günlük ihtiyaç/üst sınır değerleri NIH ODS fact sheet'lerinden (kadın–erkek aralığı, birim açık); `source` alanına kullanılan kaynağı ("NIH ODS" ya da "EFSA") yaz; eksiklik/fazlalık maddeleri kısa belirti ifadeleri (tek cümle ya da kısa öbek); **emin olunmayan değeri uydurma — belirsizse `upper_limit` alanını boş bırak** ve kayıt notunu Fatih'e raporla; vücutta işlev tek-iki cümle; en 3 besin kaynağı; tr ve en birebir aynı bilgiyi taşır.
- [ ] **Step 3: Testi çalıştır → PASS.**
- [ ] **Step 4: Fatih'e gözden geçirme için üst sınır + fazlalık belirtileri özeti ver** (rapora yaz, kod değişikliği değil).
- [ ] **Step 5: Commit** — `feat(nutrient-guide): add vitamin content`.

### Task 6: İçerik — 14 mineral

**Files:** Modify `assets/nutrients/nutrients.json`; Modify içerik testi.

İdler: `calcium`, `phosphorus`, `magnesium`, `sodium`, `potassium`, `iron`, `zinc`, `copper`, `manganese`, `iodine`, `selenium`, `chromium`, `molybdenum`, `fluoride`. `category: "mineral"`. Aynı yazım kuralları (Task 5 Step 2); tr adları: Kalsiyum, Fosfor, Magnezyum, Sodyum, Potasyum, Demir, Çinko, Bakır, Mangan, İyot, Selenyum, Krom, Molibden, Florür.

- [ ] **Step 1: Beklenti `mineral: 14` → FAIL.**
- [ ] **Step 2: Kayıtları yaz.**
- [ ] **Step 3: → PASS.**
- [ ] **Step 4: Commit** — `feat(nutrient-guide): add mineral content`.

### Task 7: İçerik — 9 temel amino asit

**Files:** Modify `assets/nutrients/nutrients.json`; Modify içerik testi.

İdler: `histidine`, `isoleucine`, `leucine`, `lysine`, `methionine`, `phenylalanine`, `threonine`, `tryptophan`, `valine`. `category: "amino_acid"`. tr adları: Histidin, İzolösin, Lösin, Lizin, Metiyonin, Fenilalanin, Treonin, Triptofan, Valin. `daily_need` NIH/IOM ya da WHO/FAO'nun mg/kg vücut ağırlığı değerlerinden ("Yetişkin: X mg/kg/gün" biçiminde); üst sınır genellikle tanımsız → `upper_limit` boş. Aynı yazım kuralları. Fenilketonüri uyarısı fenilalanin kaydının fazlalık maddelerinde yer alır.

- [ ] **Step 1: Beklenti `aminoAcid: 9` → FAIL.**
- [ ] **Step 2: Kayıtları yaz.**
- [ ] **Step 3: → PASS.**
- [ ] **Step 4: Commit** — `feat(nutrient-guide): add amino acid content`.

### Task 8: Liste ekranı + route

**Files:**
- Create: `lib/features/nutrient_guide/presentation/screens/nutrient_guide_screen.dart`
- Modify: `lib/config/router/route_names.dart` (`nutrientGuide = 'nutrientGuide'`, `nutrientDetail = 'nutrientDetail'`). `app_router.dart` bu task'ta değişmez; iki route Task 9'da birlikte eklenir (detay ekranı henüz yok).
- Test: `test/features/nutrient_guide/presentation/nutrient_guide_screen_test.dart`

**Interfaces:**
- Consumes: `nutrientsProvider`, `searchNutrients`, l10n anahtarları.
- Produces: `class NutrientGuideScreen extends ConsumerStatefulWidget` — `DefaultTabController(length: 3)`, üstte arama alanı, kategoriye göre filtrelenmiş liste; satıra dokununca `context.pushNamed(RouteNames.nutrientDetail, pathParameters: {'id': n.id})`. Yükleme: `CircularProgressIndicator`; hata: `nutrientLoadError` + `nutrientRetry` düğmesi (`ref.invalidate(nutrientsProvider)`); boş sonuç: `nutrientNoResults`.

- [ ] **Step 1: Failing widget testleri** (`nutrientsProvider` `overrideWith` ile sahte liste; harness: `AppTheme.light`, `locale: tr`, l10n delege'leri, `GoRouter` gerekmez — satır tıklaması ayrı doğrulanmaz, `onTap` route'a gider ve test için `RouteNames` stub'lı küçük `GoRouter` kullan):
  - `shows three tabs and the vitamin list by default`.
  - `switching to Mineraller shows only minerals`.
  - `typing "iyot" shows İyot and hides others` (Türkçe katlama).
  - `no match shows nutrientNoResults`.
  - `load error shows retry and recovers after retry` (ilk `FutureProvider` hata verir, tekrar dene → liste).
  - `locale ar shows English names` (`locale: Locale('ar')`).
- [ ] **Step 2: → FAIL.**
- [ ] **Step 3: Ekranı ve `RouteNames` sabitlerini yaz.** Liste satırı: `CozyTile`/`cozyCardDecoration` düzeni (`lib/core/widgets/cozy_tile.dart`), başlık adı, alt başlık `altName` (varsa).
- [ ] **Step 4: → PASS.**
- [ ] **Step 5: Commit** — `feat(nutrient-guide): add guide list screen`.

### Task 9: Detay ekranı + route

**Files:**
- Create: `lib/features/nutrient_guide/presentation/screens/nutrient_detail_screen.dart`
- Modify: `lib/config/router/app_router.dart` (iki route birlikte eklenir: `/nutrients`, `/nutrient/:id`)
- Test: `test/features/nutrient_guide/presentation/nutrient_detail_screen_test.dart`

**Interfaces:**
- Consumes: `nutrientByIdProvider(id)`, l10n anahtarları.
- Produces: `class NutrientDetailScreen extends ConsumerWidget { const NutrientDetailScreen({super.key, required this.nutrientId}); }` — `additive_detail_screen.dart` düzenini izler (AppBar + `_Body`); bölümler: işlev, eksikse (madde listesi), fazlaysa (madde listesi), nerede bulunur, günlük ihtiyaç (+ `upperLimit` varsa), kaynak satırı (`nutrientSourceLabel`), en altta `nutrientDisclaimer`. Dil: `Localizations.localeOf(context).languageCode` → `Localized.of`.

- [ ] **Step 1: Failing widget testleri:**
  - `renders every section and the disclaimer for tr`.
  - `shows upper limit only when present`.
  - `unknown id shows nutrientNotFound` (override `null`).
  - `locale zh renders English text, no empty section titles`.
  - `scrolls without overflow at textScale 2.0` (`MediaQuery` `textScaler: TextScaler.linear(2.0)`; `tester.takeException()` null; bir `drag` ile disclaimer görünür olur).
- [ ] **Step 2: → FAIL.**
- [ ] **Step 3: Ekranı yaz, iki route'u ekle.**
- [ ] **Step 4: → PASS.**
- [ ] **Step 5: Commit** — `feat(nutrient-guide): add detail screen and routes`.

### Task 10: Profil giriş kartı

**Files:**
- Modify: `lib/features/profile/presentation/screens/profile_screen.dart` (sağlık filtreleri bölümünün sonuna, `chemicalFilters` tile'ından sonra — yaklaşık satır 239)
- Test: `test/features/profile/profile_screen_nutrient_guide_tile_test.dart` (var olan `profile_screen_calorie_target_test.dart` harness'ini örnek al)

- [ ] **Step 1: Failing test:** profil ekranında `l10n.nutrientGuideTitle` metni görünür ve dokununca `/nutrients` route'una gider (stub `GoRouter` ile `RouteNames.nutrientGuide`).
- [ ] **Step 2: → FAIL.**
- [ ] **Step 3: `_SettingsTile` ekle:** `icon: Icons.menu_book_rounded`, `title: l10n.nutrientGuideTitle`, `subtitle: l10n.nutrientGuideSubtitle`, `tint: cozy.sky`, `onTap: () => context.pushNamed(RouteNames.nutrientGuide)`.
- [ ] **Step 4: → PASS.**
- [ ] **Step 5: Commit** — `feat(profile): link nutrient guide from profile`.

### Task 11: Doğrulama ve kapanış

- [ ] **Step 1:** `flutter analyze` temiz; `flutter test` tamamı geçer (proje temeli: 1021 Flutter testi + yenileri). Raporla: önceki sayı → yeni sayı.
- [ ] **Step 2:** Emülatörde (`mcp__flutter-skill__*` ya da `flutter run`) Profil → Besin Rehberi → bir vitamin, bir mineral, bir amino asit detayı; ekran görüntüleri; "iyot" araması; karanlık tema; TR ve EN dil. Cihazda doğrulanmadıysa bunu açıkça yaz.
- [ ] **Step 3:** `graphify update .` (CLAUDE.md kuralı).
- [ ] **Step 4:** Fatih'e içerik gözden geçirme listesi ver: her kategori için üst sınır ve fazlalık belirtileri; yayından önce onay beklenir.
- [ ] **Step 5:** Vault handoff'unu (`NutriLens/wiki/05-ai-handoff.md`) "Son Oturum" bölümünü üzerine yazarak güncelle ve bu özelliği 1.5.4 adayları arasına not düş (Fatih istemedikçe commit yok).
