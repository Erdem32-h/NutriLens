# Gerçek Alternatifler (#1) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ürün detayında, aynı kategorideki kendinden daha sağlıklı ürünleri (HP skoruna göre) göster.

**Architecture:** Kategori, `community_products` tablosunda tek kanonik `category` kolonunda tutulur (tek doğruluk kaynağı). Kullanıcı ürünlerinde kategori Gemini `classify_category` ile tahmin edilip düzeltilebilir dropdown'a düşer; OFF ürünleri `categoriesTags`'ten `CategoryMapper` ile eşlenir. Alternatifler sorgusu `community_products` üzerinde `category = X AND hp_score > current` çalışır. Drift şeması değişmez — cache'te kategori `categoriesTags`'ten türetilir.

**Tech Stack:** Flutter/Dart, Riverpod, Supabase (Postgres + Edge Functions/Deno), Gemini Flash.

---

## Dosya Yapısı

- **Create:** `lib/core/constants/product_categories.dart` — kanonik kategori listesi (id + TR etiket).
- **Create:** `lib/features/product/data/mappers/category_mapper.dart` — OFF `categoriesTags` → kanonik kategori.
- **Create:** `test/features/product/data/mappers/category_mapper_test.dart`
- **Create:** `supabase/migrations/20260617_community_products_category.sql`
- **Modify:** `supabase/functions/gemini-proxy/index.ts` — `classify_category` aksiyonu.
- **Modify:** `lib/core/services/gemini_ai_service.dart` — `classifyCategory(...)`.
- **Modify:** `lib/features/product/domain/entities/product_entity.dart` — `category` alanı.
- **Modify:** `lib/features/product/data/models/product_dto.dart` — `category` map.
- **Modify:** `lib/features/product/data/datasources/community_product_source.dart` — `category` yaz + `getAlternatives`.
- **Modify:** `lib/features/product/presentation/providers/product_provider.dart` — `alternativesProvider` yeniden yazımı.
- **Modify:** `lib/features/product/presentation/screens/product_detail_screen.dart` — alternatif sekmesi kategori arg + boş durum.
- **Modify:** `lib/features/product/presentation/screens/edit_product_screen.dart` — kategori dropdown + Gemini auto-fill + kayıt.
- **Modify:** `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb` — kategori UI metinleri.

---

## Task 1: Kanonik kategori listesi + OFF mapper (pure Dart, TDD)

**Files:**
- Create: `lib/core/constants/product_categories.dart`
- Create: `lib/features/product/data/mappers/category_mapper.dart`
- Test: `test/features/product/data/mappers/category_mapper_test.dart`

- [ ] **Step 1: Kategori sabitleri**

`lib/core/constants/product_categories.dart`:
```dart
/// Canonical product categories (single string id used in DB + matching).
/// `label` is the Turkish UI label for the dropdown.
class ProductCategory {
  final String id;
  final String label;
  const ProductCategory(this.id, this.label);
}

abstract final class ProductCategories {
  static const all = <ProductCategory>[
    ProductCategory('sut', 'Süt'),
    ProductCategory('yogurt', 'Yoğurt'),
    ProductCategory('peynir', 'Peynir'),
    ProductCategory('yag', 'Tereyağı / Margarin'),
    ProductCategory('biskuvi', 'Bisküvi / Kraker'),
    ProductCategory('cikolata', 'Çikolata'),
    ProductCategory('sekerleme', 'Şekerleme'),
    ProductCategory('cips', 'Cips / Atıştırmalık'),
    ProductCategory('kuruyemis', 'Kuruyemiş'),
    ProductCategory('gazli_icecek', 'Gazlı içecek'),
    ProductCategory('meyve_suyu', 'Meyve suyu'),
    ProductCategory('su', 'Su / Maden suyu'),
    ProductCategory('kahve_cay', 'Kahve / Çay'),
    ProductCategory('ekmek', 'Ekmek / Unlu mamul'),
    ProductCategory('gevrek', 'Kahvaltılık gevrek'),
    ProductCategory('makarna', 'Makarna / Bakliyat'),
    ProductCategory('hazir_yemek', 'Hazır yemek / Konserve'),
    ProductCategory('sos', 'Sos'),
    ProductCategory('recel_bal', 'Reçel / Bal'),
    ProductCategory('et_sarkuteri', 'Et / Şarküteri'),
    ProductCategory('dondurma', 'Dondurma'),
    ProductCategory('diger', 'Diğer'),
  ];

  static const validIds = {
    'sut', 'yogurt', 'peynir', 'yag', 'biskuvi', 'cikolata', 'sekerleme',
    'cips', 'kuruyemis', 'gazli_icecek', 'meyve_suyu', 'su', 'kahve_cay',
    'ekmek', 'gevrek', 'makarna', 'hazir_yemek', 'sos', 'recel_bal',
    'et_sarkuteri', 'dondurma', 'diger',
  };

  static bool isValid(String? id) => id != null && validIds.contains(id);

  static String? labelFor(String? id) {
    if (id == null) return null;
    for (final c in all) {
      if (c.id == id) return c.label;
    }
    return null;
  }
}
```

- [ ] **Step 2: Failing test**

`test/features/product/data/mappers/category_mapper_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/product/data/mappers/category_mapper.dart';

void main() {
  group('CategoryMapper.fromOffTags', () {
    test('maps milk tags to sut', () {
      expect(CategoryMapper.fromOffTags(['en:dairies', 'en:milks']), 'sut');
    });
    test('maps biscuit/cookie tags to biskuvi', () {
      expect(CategoryMapper.fromOffTags(['en:biscuits-and-cakes', 'en:biscuits']), 'biskuvi');
    });
    test('maps sodas to gazli_icecek', () {
      expect(CategoryMapper.fromOffTags(['en:beverages', 'en:sodas']), 'gazli_icecek');
    });
    test('returns null for empty', () {
      expect(CategoryMapper.fromOffTags(const []), isNull);
    });
    test('returns null for unmatched', () {
      expect(CategoryMapper.fromOffTags(['en:unicorn-food']), isNull);
    });
  });
}
```

- [ ] **Step 3: Run — expect FAIL**

Run: `flutter test test/features/product/data/mappers/category_mapper_test.dart`
Expected: FAIL (`category_mapper.dart` yok).

- [ ] **Step 4: Implement mapper**

`lib/features/product/data/mappers/category_mapper.dart`:
```dart
/// Maps Open Food Facts `categoriesTags` to a canonical [ProductCategories] id.
/// Keyword-substring match over the joined, lowercased tags — robust to OFF's
/// hierarchical tag noise (e.g. `en:dairies, en:fermented-foods, en:yogurts`).
abstract final class CategoryMapper {
  /// First match wins; order matters (specific before generic).
  static const _rules = <(String keyword, String categoryId)>[
    ('yogurt', 'yogurt'),
    ('cheese', 'peynir'),
    ('butter', 'yag'),
    ('margarine', 'yag'),
    ('biscuit', 'biskuvi'),
    ('cookie', 'biskuvi'),
    ('cracker', 'biskuvi'),
    ('chocolate', 'cikolata'),
    ('candies', 'sekerleme'),
    ('candy', 'sekerleme'),
    ('chips', 'cips'),
    ('crisps', 'cips'),
    ('nuts', 'kuruyemis'),
    ('soda', 'gazli_icecek'),
    ('carbonated', 'gazli_icecek'),
    ('fruit-juice', 'meyve_suyu'),
    ('juice', 'meyve_suyu'),
    ('waters', 'su'),
    ('coffee', 'kahve_cay'),
    ('teas', 'kahve_cay'),
    ('breakfast-cereal', 'gevrek'),
    ('cereals', 'gevrek'),
    ('bread', 'ekmek'),
    ('pasta', 'makarna'),
    ('legumes', 'makarna'),
    ('canned', 'hazir_yemek'),
    ('meals', 'hazir_yemek'),
    ('sauce', 'sos'),
    ('ketchup', 'sos'),
    ('jam', 'recel_bal'),
    ('honey', 'recel_bal'),
    ('charcuterie', 'et_sarkuteri'),
    ('sausage', 'et_sarkuteri'),
    ('ice-cream', 'dondurma'),
    ('milk', 'sut'),
    ('dairies', 'sut'),
  ];

  static String? fromOffTags(List<String> tags) {
    if (tags.isEmpty) return null;
    final hay = tags.join(' ').toLowerCase();
    for (final (keyword, id) in _rules) {
      if (hay.contains(keyword)) return id;
    }
    return null;
  }
}
```

- [ ] **Step 5: Run — expect PASS**

Run: `flutter test test/features/product/data/mappers/category_mapper_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/core/constants/product_categories.dart lib/features/product/data/mappers/category_mapper.dart test/features/product/data/mappers/category_mapper_test.dart
git commit -m "feat: canonical product categories + OFF tag mapper"
```

---

## Task 2: `community_products.category` kolonu (migration)

**Files:**
- Create: `supabase/migrations/20260617_community_products_category.sql`

- [ ] **Step 1: Migration SQL**

```sql
-- Canonical category for same-category "healthier alternative" matching.
alter table public.community_products
  add column if not exists category text;

create index if not exists community_products_category_hp_idx
  on public.community_products (category, hp_score desc);
```

- [ ] **Step 2: Apply**

Supabase MCP `apply_migration` (project `jhcgfhbaafkhbftmndpi`, name `community_products_category`) ile uygula, ya da `supabase db push`.

- [ ] **Step 3: Verify**

`execute_sql`: `select column_name from information_schema.columns where table_name='community_products' and column_name='category';` → 1 satır.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260617_community_products_category.sql
git commit -m "feat(db): add category column + index to community_products"
```

---

## Task 3: `classify_category` edge function aksiyonu

**Files:**
- Modify: `supabase/functions/gemini-proxy/index.ts`

- [ ] **Step 1: Aksiyon union'a ekle**

`index.ts` içinde `action:` union tipine (~satır 206-211) ekle:
```ts
    | "classify_category"
```

- [ ] **Step 2: `buildPrompt` case ekle**

`buildPrompt` switch'ine (`ocr_nutrition_image` case'inden sonra, ~satır 423) ekle:
```ts
    case "classify_category": {
      const name = (payload.product_name ?? "").toString().slice(0, 120);
      const ingredients = (payload.ingredients_text ?? "").toString().slice(0, 600);
      const ids = [
        "sut","yogurt","peynir","yag","biskuvi","cikolata","sekerleme","cips",
        "kuruyemis","gazli_icecek","meyve_suyu","su","kahve_cay","ekmek","gevrek",
        "makarna","hazir_yemek","sos","recel_bal","et_sarkuteri","dondurma","diger",
      ].join(", ");
      return {
        contents: [{
          role: "user",
          parts: [{
            text:
              `Bir gıda ürününü tek bir kategoriye sınıflandır.\n` +
              `Ürün adı: ${name}\nİçindekiler: ${ingredients}\n\n` +
              `SADECE şu id'lerden BİRİNİ döndür (başka hiçbir şey yazma): ${ids}.\n` +
              `Emin değilsen 'diger' yaz.`,
          }],
        }],
        generationConfig: { temperature: 0, maxOutputTokens: 12 },
      };
    }
```
(`modelFor` zaten `default` ile `gemini-flash-latest` döndürüyor; ekleme gerekmez. Bu aksiyon authed; mevcut auth bloğundan geçer.)

- [ ] **Step 3: Deploy**

`supabase functions deploy gemini-proxy` (ya da mevcut CI/deploy akışı).

- [ ] **Step 4: Smoke test**

Authed bir client'tan `classify_category` çağır (örn. `{product_name:'Sütaş Süzme Yoğurt', ingredients_text:'inek sütü, maya'}`) → `result` `"yogurt"` benzeri tek kelime döner.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/gemini-proxy/index.ts
git commit -m "feat(edge): classify_category action on gemini-proxy"
```

---

## Task 4: `GeminiAiService.classifyCategory`

**Files:**
- Modify: `lib/core/services/gemini_ai_service.dart`

- [ ] **Step 1: Metot ekle** (sınıf içinde, `recalculateMeal`'dan sonra):

```dart
  /// Classify a product into one canonical category id via the proxy.
  /// Returns a trimmed lowercase id, or `null` when the service failed or
  /// returned something unusable (caller falls back to manual dropdown).
  Future<String?> classifyCategory({
    required String productName,
    String? ingredientsText,
  }) async {
    try {
      final response = await _invoke('classify_category', {
        'product_name': productName,
        if (ingredientsText != null && ingredientsText.trim().isNotEmpty)
          'ingredients_text': ingredientsText,
      });
      final result = (response['result'] as String?)?.trim().toLowerCase();
      if (result == null || result.isEmpty) return null;
      return result;
    } on GeminiServiceException {
      return null;
    }
  }
```

- [ ] **Step 2: Verify compile**

Run: `flutter analyze lib/core/services/gemini_ai_service.dart` → No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/gemini_ai_service.dart
git commit -m "feat: GeminiAiService.classifyCategory client method"
```

---

## Task 5: `ProductEntity.category` + DTO mapping

**Files:**
- Modify: `lib/features/product/domain/entities/product_entity.dart`
- Modify: `lib/features/product/data/models/product_dto.dart`

- [ ] **Step 1: Entity alanı**

`product_entity.dart`: alan ekle (`countriesTags`'tan sonra):
```dart
  final String? category;
```
Constructor'a `this.category,` ekle; `copyWith` imzasına `String? category,` ve gövdesine `category: category ?? this.category,`; `props` listesine `category,`.

- [ ] **Step 2: DTO map — community (doğruluk kaynağı)**

`product_dto.dart` `fromCommunityRow` içinde ProductEntity'ye ekle:
```dart
      category: row['category']?.toString(),
```

- [ ] **Step 3: DTO map — OFF (mapper'dan türet)**

`fromOffProduct` içinde, `categoriesTags`'tan türet. Üstte import ekle:
```dart
import '../mappers/category_mapper.dart';
```
ProductEntity'ye ekle:
```dart
      category: CategoryMapper.fromOffTags(product.categoriesTags ?? const []),
```

- [ ] **Step 4: DTO map — Drift (fallback türetme, şema değişmeden)**

`fromDriftRow` içinde, `_jsonToList(categoriesTags)` zaten var; ProductEntity'ye ekle:
```dart
      category: CategoryMapper.fromOffTags(_jsonToList(categoriesTags)),
```
(Kullanıcı ürünleri cache'te boş `categoriesTags` ile null kategori alır; ama detay açılınca `productByBarcodeProvider` community satırını tazeleyip kategoriyi getirir.)

- [ ] **Step 5: Verify**

Run: `flutter analyze lib/features/product` → No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/product/domain/entities/product_entity.dart lib/features/product/data/models/product_dto.dart
git commit -m "feat: add category to ProductEntity + DTO mapping"
```

---

## Task 6: CommunityProductSource — kategori yaz + `getAlternatives`

**Files:**
- Modify: `lib/features/product/data/datasources/community_product_source.dart`

- [ ] **Step 1: `addProduct` ve `autoImportFromApi` upsert payload'una ekle**

Her iki `upsert({...})` map'ine ekle:
```dart
      'category': product.category,
```

- [ ] **Step 2: `getAlternatives` ekle** (sınıf içinde):

```dart
  /// Same-category products with a strictly better HP score than [currentHpScore],
  /// best first. Empty list on any error or when [category] is null.
  Future<List<ProductEntity>> getAlternatives({
    required String? category,
    required String selfBarcode,
    required double currentHpScore,
    int limit = 5,
  }) async {
    if (category == null) return const [];
    try {
      final rows = await _client
          .from('community_products')
          .select()
          .eq('category', category)
          .neq('barcode', selfBarcode)
          .gt('hp_score', currentHpScore)
          .order('hp_score', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) => ProductDto.fromCommunityRow(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.w('getAlternatives failed for $selfBarcode/$category: $e');
      return const [];
    }
  }
```

- [ ] **Step 3: Verify**

Run: `flutter analyze lib/features/product/data/datasources/community_product_source.dart` → No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/features/product/data/datasources/community_product_source.dart
git commit -m "feat: write category + same-category getAlternatives on community source"
```

---

## Task 7: `alternativesProvider` yeniden yazımı + detay sekmesi

**Files:**
- Modify: `lib/features/product/presentation/providers/product_provider.dart:220-234`
- Modify: `lib/features/product/presentation/screens/product_detail_screen.dart:441-491`

- [ ] **Step 1: Provider'ı community kaynağına çevir**

`product_provider.dart` mevcut `alternativesProvider`'ı değiştir:
```dart
/// Up to 5 same-category community products with a better HP score than the
/// current product. Returns [] when category is unknown.
final alternativesProvider =
    FutureProvider.family<
      List<ProductEntity>,
      ({String barcode, double hpScore, String? category})
    >((ref, args) async {
      final source = ref.watch(communityProductSourceProvider);
      return source.getAlternatives(
        category: args.category,
        selfBarcode: args.barcode,
        currentHpScore: args.hpScore,
      );
    });
```

- [ ] **Step 2: Detay sekmesi — kategoriyi geçir + boş durum**

`product_detail_screen.dart` `_buildAlternativeTab`:
- `alternativesProvider` çağrısını güncelle:
```dart
    final altAsync = ref.watch(
      alternativesProvider((
        barcode: product.barcode,
        hpScore: hpScore,
        category: product.category,
      )),
    );
```
- `data:` içindeki `if (alts.isEmpty) return const SizedBox.shrink();` satırını, kategori varken bilgilendirici boş mesaja çevir:
```dart
        data: (alts) {
          if (alts.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                context.l10n.noHealthierAlternative,
                style: TextStyle(fontSize: 13, color: context.colors.textMuted),
              ),
            );
          }
          // ... mevcut liste kodu aynı ...
```

- [ ] **Step 3: l10n stringleri**

`lib/l10n/app_tr.arb`: `"noHealthierAlternative": "Bu kategoride daha sağlıklı bir alternatif bulunamadı."`
`lib/l10n/app_en.arb`: `"noHealthierAlternative": "No healthier alternative found in this category."`
Run: `flutter gen-l10n`.

- [ ] **Step 4: Verify**

Run: `flutter analyze lib/features/product/presentation` → No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/product/presentation lib/l10n
git commit -m "feat: category-aware alternatives query + empty state"
```

---

## Task 8: Kayıt formuna kategori dropdown + Gemini auto-fill

**Files:**
- Modify: `lib/features/product/presentation/screens/edit_product_screen.dart`
- Modify: `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb`

- [ ] **Step 1: State alanı**

`_EditProductScreenState`'e ekle:
```dart
  String? _selectedCategory;
  bool _classifyingCategory = false;
```
`_populateFromProduct` içinde: `_selectedCategory = product.category;`

- [ ] **Step 2: Dropdown widget'ı** (formda, marka alanından sonra)

```dart
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            decoration: InputDecoration(
              labelText: '${l10n.category} *',
              filled: true,
              fillColor: context.colors.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            items: [
              for (final c in ProductCategories.all)
                DropdownMenuItem(value: c.id, child: Text(c.label)),
            ],
            validator: (v) => v == null ? l10n.fieldRequired : null,
            onChanged: (v) => setState(() => _selectedCategory = v),
          ),
          const SizedBox(height: 16),
```
Üstte import: `import '../../../../core/constants/product_categories.dart';`

- [ ] **Step 3: Gemini auto-fill**

İçindekiler OCR'ı bittikten sonra (ingredients case'inin sonunda, `_showMessage(l10n.ocrSuccess)`'tan önce) ya da ayrı bir "Kategori öner" yardımıyla, ad+içindekiler doluysa ve `_selectedCategory == null` ise:
```dart
          if (_selectedCategory == null && _nameController.text.trim().isNotEmpty) {
            final guess = await ref.read(geminiAiServiceProvider).classifyCategory(
                  productName: _nameController.text.trim(),
                  ingredientsText: _ingredientsController.text.trim(),
                );
            if (mounted && ProductCategories.isValid(guess)) {
              setState(() => _selectedCategory = guess);
            }
          }
```

- [ ] **Step 4: Kayıtta category'i geçir**

`_save` içinde `updatedProduct` oluşturulurken `ProductEntity(...)` çağrısına ekle:
```dart
        category: _selectedCategory,
```

- [ ] **Step 5: l10n**

`app_tr.arb`: `"category": "Kategori"` · `app_en.arb`: `"category": "Category"`. `flutter gen-l10n`.

- [ ] **Step 6: Verify**

Run: `flutter analyze lib/features/product/presentation/screens/edit_product_screen.dart` → No issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/product/presentation/screens/edit_product_screen.dart lib/l10n
git commit -m "feat: category dropdown + Gemini auto-classify on product edit"
```

---

## Task 9: Doğrulama

- [ ] **Step 1:** `flutter analyze` (tüm proje) → No issues.
- [ ] **Step 2:** `flutter test` → mevcut + yeni testler geçer.
- [ ] **Step 3: Manuel E2E:**
  - Aynı kategoride 2+ ürün ekle (örn. 2 yoğurt, farklı HP).
  - Düşük skorlu yoğurdu aç → alternatif sekmesinde yüksek skorlu yoğurt çıkmalı; başka kategori çıkmamalı.
  - Kategorisi olmayan/tekil kategorili üründe "daha sağlıklı alternatif bulunamadı" mesajı.

---

## Notlar / kapsam
- Drift şeması bilinçli olarak değişmez; cache'te kategori `categoriesTags`'ten türetilir, kullanıcı ürünlerinde authoritative kategori community satırından gelir.
- Mevcut community ürünlerinde `category` başlangıçta null → alternatif çıkmaz; korpus yeni kayıt/auto-import ile dolar. (İsteğe bağlı backfill ayrı iş.)
- OFF→kategori eşleme listesi (`CategoryMapper._rules`) ilk sürüm; gerçek veriyle genişletilir.
