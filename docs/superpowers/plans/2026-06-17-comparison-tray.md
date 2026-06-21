# Kıyaslama Tepsisi (#2) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kullanıcının seçtiği 2 ürünü yan yana (versus tarzı) karşılaştır; her metrik satırında daha iyi tarafı yeşil ✓ ile vurgula.

**Architecture:** Karşılaştırma mantığı saf, locale-bağımsız bir fonksiyon (`comparisonMetrics`) içinde — her metriğin "daha iyi" yönü ve sayı formatı burada, unit-test edilir. Sunum tarafında `ComparisonScreen` (route `/compare`) iki barkodu mevcut `productByBarcodeProvider` ile çeker (yeni data katmanı yok); `ProductPickerSheet` 2. ürünü seçtirir; favorilerde çoklu-seçim modu ekran-içi local state ile çalışır. Yeni veri tablosu/migration YOK.

**Tech Stack:** Flutter/Dart, Riverpod, GoRouter. Yalnızca mevcut sağlayıcılar (`productByBarcodeProvider`, `favoritesProvider`, `scanHistoryProvider`) kullanılır.

---

## Dosya Yapısı

- **Create:** `lib/features/comparison/domain/product_comparison.dart` — saf karşılaştırma fonksiyonu + `ComparisonRow`/`ComparisonMetric`/`BetterSide`.
- **Create:** `test/features/comparison/domain/product_comparison_test.dart`
- **Create:** `lib/features/comparison/presentation/providers/comparison_provider.dart` — iki barkodu birleştiren `comparisonProvider`.
- **Create:** `lib/features/comparison/presentation/screens/comparison_screen.dart` — sticky başlık + satırlar.
- **Create:** `lib/features/comparison/presentation/widgets/product_picker_sheet.dart` — favoriler + geçmişten 2. ürün seçimi.
- **Modify:** `lib/config/router/route_names.dart` — `compare` route adı.
- **Modify:** `lib/config/router/app_router.dart` — `/compare` route'u.
- **Modify:** `lib/features/product/presentation/screens/product_detail_screen.dart` — alternatif sekmesine "Kıyasla" girişi.
- **Modify:** `lib/features/favorites/presentation/screens/favorites_screen.dart` — çoklu-seçim modu + "Kıyasla (n/2)" çubuğu.
- **Modify:** `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb` — kıyas UI metinleri.

**Kapsam dışı (bu plan değil):** 3+ ürün kıyası, kalıcı kıyas listesi/sepeti. **Paylaş butonu #3 planında** eklenir (şimdi ölü buton bırakma).

---

## Task 1: Saf karşılaştırma fonksiyonu (pure Dart, TDD)

**Files:**
- Create: `lib/features/comparison/domain/product_comparison.dart`
- Test: `test/features/comparison/domain/product_comparison_test.dart`

- [ ] **Step 1: Failing test yaz**

`test/features/comparison/domain/product_comparison_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/comparison/domain/product_comparison.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';
import 'package:nutrilens/features/product/domain/entities/product_entity.dart';

ProductEntity _p({
  required String barcode,
  double? hp,
  NutrimentsEntity nutriments = const NutrimentsEntity(),
  int? nova,
  String? nutriscore,
  List<String> additives = const [],
}) {
  return ProductEntity(
    barcode: barcode,
    productName: barcode,
    nutriments: nutriments,
    novaGroup: nova,
    nutriscoreGrade: nutriscore,
    additivesTags: additives,
    hpScore: hp,
  );
}

ComparisonRow _row(List<ComparisonRow> rows, ComparisonMetric m) =>
    rows.firstWhere((r) => r.metric == m);

void main() {
  group('comparisonMetrics', () {
    test('returns one row per metric in fixed order', () {
      final rows = comparisonMetrics(_p(barcode: 'a'), _p(barcode: 'b'));
      expect(rows.map((r) => r.metric).toList(), [
        ComparisonMetric.hpScore,
        ComparisonMetric.energy,
        ComparisonMetric.fat,
        ComparisonMetric.saturatedFat,
        ComparisonMetric.sugar,
        ComparisonMetric.salt,
        ComparisonMetric.protein,
        ComparisonMetric.fiber,
        ComparisonMetric.nova,
        ComparisonMetric.additives,
        ComparisonMetric.nutriScore,
      ]);
    });

    test('HP score: higher wins (side A)', () {
      final rows = comparisonMetrics(
        _p(barcode: 'a', hp: 82),
        _p(barcode: 'b', hp: 40),
      );
      final hp = _row(rows, ComparisonMetric.hpScore);
      expect(hp.displayA, '82');
      expect(hp.displayB, '40');
      expect(hp.betterSide, BetterSide.a);
    });

    test('energy: lower wins (side B)', () {
      final rows = comparisonMetrics(
        _p(barcode: 'a', nutriments: const NutrimentsEntity(energyKcal: 540)),
        _p(barcode: 'b', nutriments: const NutrimentsEntity(energyKcal: 120)),
      );
      final e = _row(rows, ComparisonMetric.energy);
      expect(e.displayA, '540');
      expect(e.displayB, '120');
      expect(e.betterSide, BetterSide.b);
    });

    test('protein: higher wins; grams trim trailing .0', () {
      final rows = comparisonMetrics(
        _p(barcode: 'a', nutriments: const NutrimentsEntity(proteins: 12)),
        _p(barcode: 'b', nutriments: const NutrimentsEntity(proteins: 3.2)),
      );
      final p = _row(rows, ComparisonMetric.protein);
      expect(p.displayA, '12');
      expect(p.displayB, '3.2');
      expect(p.betterSide, BetterSide.a);
    });

    test('nova: lower group wins', () {
      final rows = comparisonMetrics(
        _p(barcode: 'a', nova: 4),
        _p(barcode: 'b', nova: 1),
      );
      expect(_row(rows, ComparisonMetric.nova).betterSide, BetterSide.b);
    });

    test('additive count: fewer wins, never dashed', () {
      final rows = comparisonMetrics(
        _p(barcode: 'a', additives: const ['e1', 'e2', 'e3']),
        _p(barcode: 'b', additives: const ['e1']),
      );
      final ad = _row(rows, ComparisonMetric.additives);
      expect(ad.displayA, '3');
      expect(ad.displayB, '1');
      expect(ad.betterSide, BetterSide.b);
    });

    test('nutri-score: A beats C; display is uppercase letter', () {
      final rows = comparisonMetrics(
        _p(barcode: 'a', nutriscore: 'a'),
        _p(barcode: 'b', nutriscore: 'c'),
      );
      final ns = _row(rows, ComparisonMetric.nutriScore);
      expect(ns.displayA, 'A');
      expect(ns.displayB, 'C');
      expect(ns.betterSide, BetterSide.a);
    });

    test('missing value: dash + no highlight', () {
      final rows = comparisonMetrics(
        _p(barcode: 'a', nutriments: const NutrimentsEntity(sugars: 9)),
        _p(barcode: 'b'),
      );
      final s = _row(rows, ComparisonMetric.sugar);
      expect(s.displayA, '9');
      expect(s.displayB, '—');
      expect(s.betterSide, BetterSide.none);
    });

    test('equal values: no highlight', () {
      final rows = comparisonMetrics(
        _p(barcode: 'a', nutriments: const NutrimentsEntity(salt: 1)),
        _p(barcode: 'b', nutriments: const NutrimentsEntity(salt: 1)),
      );
      expect(_row(rows, ComparisonMetric.salt).betterSide, BetterSide.none);
    });
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/features/comparison/domain/product_comparison_test.dart`
Expected: FAIL (`product_comparison.dart` yok / derlenmez).

- [ ] **Step 3: Implement saf fonksiyon**

`lib/features/comparison/domain/product_comparison.dart`:
```dart
import '../../product/domain/entities/product_entity.dart';

/// Metrics compared, in fixed display order.
enum ComparisonMetric {
  hpScore,
  energy,
  fat,
  saturatedFat,
  sugar,
  salt,
  protein,
  fiber,
  nova,
  additives,
  nutriScore,
}

/// Which product wins a metric (or neither).
enum BetterSide { a, b, none }

/// One comparison row. [displayA]/[displayB] are formatted numbers/letters
/// WITHOUT units (the UI adds " g" / " kcal" and the localized label). A
/// missing value renders as "—" and forces [betterSide] = none.
class ComparisonRow {
  final ComparisonMetric metric;
  final String displayA;
  final String displayB;
  final BetterSide betterSide;

  const ComparisonRow({
    required this.metric,
    required this.displayA,
    required this.displayB,
    required this.betterSide,
  });
}

/// Pure, locale-independent comparison of two products. Returns one row per
/// [ComparisonMetric] in a fixed order. Direction ("higher better" vs "lower
/// better") and number formatting live here so they are unit-testable.
List<ComparisonRow> comparisonMetrics(ProductEntity a, ProductEntity b) {
  final na = a.nutriments;
  final nb = b.nutriments;
  return [
    _numRow(ComparisonMetric.hpScore, a.calculatedHpScore, b.calculatedHpScore,
        higherBetter: true, format: _fmtInt),
    _numRow(ComparisonMetric.energy, na.energyKcal, nb.energyKcal,
        higherBetter: false, format: _fmtInt),
    _numRow(ComparisonMetric.fat, na.fat, nb.fat,
        higherBetter: false, format: _fmtG),
    _numRow(ComparisonMetric.saturatedFat, na.saturatedFat, nb.saturatedFat,
        higherBetter: false, format: _fmtG),
    _numRow(ComparisonMetric.sugar, na.sugars, nb.sugars,
        higherBetter: false, format: _fmtG),
    _numRow(ComparisonMetric.salt, na.salt, nb.salt,
        higherBetter: false, format: _fmtG),
    _numRow(ComparisonMetric.protein, na.proteins, nb.proteins,
        higherBetter: true, format: _fmtG),
    _numRow(ComparisonMetric.fiber, na.fiber, nb.fiber,
        higherBetter: true, format: _fmtG),
    _numRow(ComparisonMetric.nova, a.novaGroup?.toDouble(),
        b.novaGroup?.toDouble(), higherBetter: false, format: _fmtInt),
    _numRow(
        ComparisonMetric.additives,
        a.additivesTags.length.toDouble(),
        b.additivesTags.length.toDouble(),
        higherBetter: false,
        format: _fmtInt),
    _nutriScoreRow(a.nutriscoreGrade, b.nutriscoreGrade),
  ];
}

ComparisonRow _numRow(
  ComparisonMetric metric,
  double? a,
  double? b, {
  required bool higherBetter,
  required String Function(double?) format,
}) {
  return ComparisonRow(
    metric: metric,
    displayA: format(a),
    displayB: format(b),
    betterSide: _better(a, b, higherBetter: higherBetter),
  );
}

ComparisonRow _nutriScoreRow(String? a, String? b) {
  return ComparisonRow(
    metric: ComparisonMetric.nutriScore,
    displayA: _fmtGrade(a),
    displayB: _fmtGrade(b),
    // Nutri-Score: A(1) is best → lower ordinal wins.
    betterSide: _better(
      _nutriOrdinal(a)?.toDouble(),
      _nutriOrdinal(b)?.toDouble(),
      higherBetter: false,
    ),
  );
}

BetterSide _better(double? a, double? b, {required bool higherBetter}) {
  if (a == null || b == null) return BetterSide.none;
  if (a == b) return BetterSide.none;
  final aWins = higherBetter ? a > b : a < b;
  return aWins ? BetterSide.a : BetterSide.b;
}

String _fmtInt(double? v) => v == null ? '—' : v.round().toString();

String _fmtG(double? v) {
  if (v == null) return '—';
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}

int? _nutriOrdinal(String? grade) {
  if (grade == null) return null;
  switch (grade.trim().toLowerCase()) {
    case 'a':
      return 1;
    case 'b':
      return 2;
    case 'c':
      return 3;
    case 'd':
      return 4;
    case 'e':
      return 5;
    default:
      return null;
  }
}

String _fmtGrade(String? grade) {
  if (grade == null || grade.trim().isEmpty) return '—';
  return _nutriOrdinal(grade) == null ? '—' : grade.trim().toUpperCase();
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `flutter test test/features/comparison/domain/product_comparison_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/comparison/domain/product_comparison.dart test/features/comparison/domain/product_comparison_test.dart
git commit -m "feat: pure product comparison metrics + tests"
```

---

## Task 2: `comparisonProvider` + `/compare` route

**Files:**
- Create: `lib/features/comparison/presentation/providers/comparison_provider.dart`
- Modify: `lib/config/router/route_names.dart`
- Modify: `lib/config/router/app_router.dart`

- [ ] **Step 1: Provider — iki barkodu birleştir**

`lib/features/comparison/presentation/providers/comparison_provider.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../product/domain/entities/product_entity.dart';
import '../../../product/presentation/providers/product_provider.dart';

/// Resolves both products for the compare screen by reusing the existing
/// `productByBarcodeProvider` (community → OFF → barcode lookup + HP enrich).
/// Throws when either product can't be resolved so the screen shows an error.
final comparisonProvider = FutureProvider.family<
    ({ProductEntity a, ProductEntity b}),
    ({String barcodeA, String barcodeB})>((ref, args) async {
  final a = await ref.watch(productByBarcodeProvider(args.barcodeA).future);
  final b = await ref.watch(productByBarcodeProvider(args.barcodeB).future);
  if (a == null || b == null) {
    throw Exception('comparison: product not resolved');
  }
  return (a: a, b: b);
});
```

- [ ] **Step 2: Route adı**

`lib/config/router/route_names.dart` — `// Product` bloğundan sonra ekle:
```dart
  // Comparison
  static const String compare = 'compare';
```

- [ ] **Step 3: Route tanımı**

`lib/config/router/app_router.dart` — üstte import ekle (diğer ekran importlarının yanına):
```dart
import '../../features/comparison/presentation/screens/comparison_screen.dart';
```
`/paywall` GoRoute'undan hemen sonra (routes listesinde) ekle:
```dart
      GoRoute(
        path: '/compare',
        name: RouteNames.compare,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final a = extra?['a'] as String?;
          final b = extra?['b'] as String?;
          if (a == null || b == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.goNamed(RouteNames.meals);
            });
            return const SizedBox.shrink();
          }
          return ComparisonScreen(barcodeA: a, barcodeB: b);
        },
      ),
```
(`WidgetsBinding`/`SizedBox` zaten bu dosyada kullanılıyor — ekstra import gerekmez.)

- [ ] **Step 4: Verify (ComparisonScreen Task 3'te oluşturulacak)**

Bu task tek başına derlenmez çünkü `ComparisonScreen` henüz yok. Task 3'ten sonra `flutter analyze lib/config/router` çalıştırılacak. Şimdilik dosyaları kaydet.

- [ ] **Step 5: Commit**

```bash
git add lib/features/comparison/presentation/providers/comparison_provider.dart lib/config/router/route_names.dart lib/config/router/app_router.dart
git commit -m "feat: comparison provider + /compare route"
```

---

## Task 3: `ComparisonScreen` — sticky başlık + satırlar

**Files:**
- Create: `lib/features/comparison/presentation/screens/comparison_screen.dart`
- Modify: `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb`

- [ ] **Step 1: l10n stringleri ekle**

`lib/l10n/app_tr.arb` — benzersiz `"noHealthierAlternative"` satırından **hemen sonra** ekle (`"category"` anahtarı dosyada iki kez geçtiği için onu çapa olarak kullanma):
```json
  "compare": "Kıyasla",
  "comparePickSecond": "Karşılaştırılacak ikinci ürünü seç",
  "compareMaxTwo": "En fazla 2 ürün seçebilirsin",
  "comparePickerEmpty": "Kıyaslanacak ürün bulunamadı",
  "hpScoreLabel": "HP Skoru",
  "nutriScoreLabel": "Nutri-Score",
```
`lib/l10n/app_en.arb` — aynı şekilde `"noHealthierAlternative"` satırından hemen sonra ekle:
```json
  "compare": "Compare",
  "comparePickSecond": "Pick a second product to compare",
  "compareMaxTwo": "You can select at most 2 products",
  "comparePickerEmpty": "No products to compare",
  "hpScoreLabel": "HP Score",
  "nutriScoreLabel": "Nutri-Score",
```
> Not: `noHealthierAlternative` satırının zaten sonunda virgül var (ardından `category` geliyor); yeni 6 satır araya temiz girer, ekstra virgül düzeltmesi gerekmez. JSON anahtar adları benzersiz olmalı — yeni anahtarların hiçbiri dosyada mevcut değil.

- [ ] **Step 2: Gen-l10n**

Run: `flutter gen-l10n`
Expected: hatasız üretim.

- [ ] **Step 3: Ekranı yaz**

`lib/features/comparison/presentation/screens/comparison_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/score_constants.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../product/domain/entities/product_entity.dart';
import '../../domain/product_comparison.dart';
import '../providers/comparison_provider.dart';

class ComparisonScreen extends ConsumerWidget {
  final String barcodeA;
  final String barcodeB;

  const ComparisonScreen({
    super.key,
    required this.barcodeA,
    required this.barcodeB,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(
      comparisonProvider((barcodeA: barcodeA, barcodeB: barcodeB)),
    );

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(l10n.compare),
        backgroundColor: Colors.transparent,
      ),
      body: async.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.colors.primary),
        ),
        error: (e, s) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.saveFailed,
              style: TextStyle(color: context.colors.textMuted),
            ),
          ),
        ),
        data: (pair) {
          final rows = comparisonMetrics(pair.a, pair.b);
          return CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _CompareHeaderDelegate(a: pair.a, b: pair.b),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _ComparisonRowTile(row: rows[i]),
                  childCount: rows.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }
}

// ── Sticky two-product header ────────────────────────────────────────────────

class _CompareHeaderDelegate extends SliverPersistentHeaderDelegate {
  final ProductEntity a;
  final ProductEntity b;

  _CompareHeaderDelegate({required this.a, required this.b});

  static const double _height = 184;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colors = context.colors;
    return Container(
      height: _height,
      color: colors.background,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(child: _HeaderCard(product: a)),
          const SizedBox(width: 12),
          Expanded(child: _HeaderCard(product: b)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CompareHeaderDelegate oldDelegate) {
    return oldDelegate.a.barcode != a.barcode ||
        oldDelegate.b.barcode != b.barcode;
  }
}

class _HeaderCard extends StatelessWidget {
  final ProductEntity product;

  const _HeaderCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gauge = ScoreConstants.hpToGauge(product.calculatedHpScore);
    final gaugeColor = colors.gaugeColor(gauge);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: product.imageUrl != null
                ? Image.network(
                    product.imageUrl!,
                    height: 56,
                    width: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, e, s) => _imgPlaceholder(colors),
                  )
                : _imgPlaceholder(colors),
          ),
          const SizedBox(height: 6),
          Text(
            product.productName ?? product.barcode,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
              height: 1.2,
            ),
          ),
          if (product.brands != null && product.brands!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              product.brands!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: colors.textMuted),
            ),
          ],
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: gaugeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$gauge/5',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: gaugeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder(AppColorsExtension colors) {
    return Container(
      height: 56,
      width: 56,
      decoration: BoxDecoration(
        color: colors.surfaceCard2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.image_outlined, size: 24, color: colors.textMuted),
    );
  }
}

// ── One metric row ───────────────────────────────────────────────────────────

class _ComparisonRowTile extends StatelessWidget {
  final ComparisonRow row;

  const _ComparisonRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unit = _unit(row.metric);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _valueCell(
              context,
              display: row.displayA,
              unit: unit,
              isBetter: row.betterSide == BetterSide.a,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              _label(context, row.metric),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: _valueCell(
              context,
              display: row.displayB,
              unit: unit,
              isBetter: row.betterSide == BetterSide.b,
            ),
          ),
        ],
      ),
    );
  }

  Widget _valueCell(
    BuildContext context, {
    required String display,
    required String unit,
    required bool isBetter,
  }) {
    final colors = context.colors;
    // Gauge 1 == best == green; reuse the theme's green for "better".
    final betterColor = colors.gaugeColor(1);
    final text = display == '—' ? display : '$display$unit';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isBetter
            ? betterColor.withValues(alpha: 0.12)
            : colors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isBetter) ...[
            Icon(Icons.check_circle, size: 14, color: betterColor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBetter ? FontWeight.w800 : FontWeight.w600,
                color: isBetter ? betterColor : colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _label(BuildContext c, ComparisonMetric m) {
    final l10n = c.l10n;
    return switch (m) {
      ComparisonMetric.hpScore => l10n.hpScoreLabel,
      ComparisonMetric.energy => l10n.energyValue,
      ComparisonMetric.fat => l10n.fatLabel,
      ComparisonMetric.saturatedFat => l10n.saturatedFatLabel,
      ComparisonMetric.sugar => l10n.sugarLabel,
      ComparisonMetric.salt => l10n.saltLabel,
      ComparisonMetric.protein => l10n.proteinLabel,
      ComparisonMetric.fiber => l10n.fiberLabel,
      ComparisonMetric.nova => l10n.novaGroup,
      ComparisonMetric.additives => l10n.additives,
      ComparisonMetric.nutriScore => l10n.nutriScoreLabel,
    };
  }

  String _unit(ComparisonMetric m) {
    return switch (m) {
      ComparisonMetric.energy => ' kcal',
      ComparisonMetric.fat ||
      ComparisonMetric.saturatedFat ||
      ComparisonMetric.sugar ||
      ComparisonMetric.salt ||
      ComparisonMetric.protein ||
      ComparisonMetric.fiber => ' g',
      _ => '',
    };
  }
}
```

- [ ] **Step 4: Verify**

Run: `flutter analyze lib/features/comparison lib/config/router`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/features/comparison/presentation/screens/comparison_screen.dart lib/l10n
git commit -m "feat: comparison screen (sticky headers + better-side rows)"
```

---

## Task 4: `ProductPickerSheet` — 2. ürün seçimi

**Files:**
- Create: `lib/features/comparison/presentation/widgets/product_picker_sheet.dart`

- [ ] **Step 1: Picker widget'ı + show helper**

`lib/features/comparison/presentation/widgets/product_picker_sheet.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/score_constants.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../history/data/datasources/scan_history_local_datasource.dart';
import '../../../history/presentation/providers/history_provider.dart';

/// Bottom sheet that lists favorites + recent scans so the user can pick the
/// SECOND product to compare against [excludeBarcode]. Returns the chosen
/// barcode (or null if dismissed).
class ProductPickerSheet extends ConsumerWidget {
  final String excludeBarcode;

  const ProductPickerSheet({super.key, required this.excludeBarcode});

  /// Opens the sheet and resolves to the picked barcode, or null.
  static Future<String?> show(
    BuildContext context, {
    required String excludeBarcode,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductPickerSheet(excludeBarcode: excludeBarcode),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final favoritesAsync = ref.watch(favoritesProvider);
    final historyAsync = ref.watch(scanHistoryProvider);

    // Merge favorites + history, dedupe by barcode, drop the current product.
    final List<ScanHistoryWithProduct> items = [
      ...favoritesAsync.asData?.value ?? const [],
      ...historyAsync.asData?.value ?? const [],
    ];
    final seen = <String>{excludeBarcode};
    final picks = <ScanHistoryWithProduct>[];
    for (final it in items) {
      if (seen.add(it.barcode)) picks.add(it);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.comparePickSecond,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: picks.isEmpty
                    ? Center(
                        child: Text(
                          l10n.comparePickerEmpty,
                          style: TextStyle(color: colors.textMuted),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: picks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _PickTile(
                          item: picks[i],
                          onTap: () => Navigator.pop(ctx, picks[i].barcode),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PickTile extends StatelessWidget {
  final ScanHistoryWithProduct item;
  final VoidCallback onTap;

  const _PickTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gauge = ScoreConstants.hpToGauge(item.effectiveHpScore);
    final gaugeColor = colors.gaugeColor(gauge);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: item.imageUrl != null
                  ? Image.network(
                      item.imageUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, e, s) =>
                          Icon(Icons.image_outlined, color: colors.textMuted),
                    )
                  : Icon(Icons.image_outlined, color: colors.textMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.productName ?? item.barcode,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            if (item.effectiveHpScore != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: gaugeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$gauge/5',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: gaugeColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/features/comparison/presentation/widgets/product_picker_sheet.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/features/comparison/presentation/widgets/product_picker_sheet.dart
git commit -m "feat: product picker sheet (favorites + history) for compare"
```

---

## Task 5: Ürün detayından "Kıyasla" girişi

**Files:**
- Modify: `lib/features/product/presentation/screens/product_detail_screen.dart`

- [ ] **Step 1: Importlar**

`product_detail_screen.dart` üstüne ekle:
```dart
import 'package:go_router/go_router.dart'; // already imported — verify, do not duplicate
import '../../../comparison/presentation/widgets/product_picker_sheet.dart';
```
> `go_router` zaten import edilmiş (line 3). Yalnızca `product_picker_sheet.dart` importunu ekle.

- [ ] **Step 2: Alternatif sekmesine "Kıyasla" butonu**

`_buildAlternativeTab` içinde, `return [ const AlternativePlaceholder(),` listesinin **ilk** öğesi olarak, placeholder'dan önce bir buton ekle. Mevcut:
```dart
    return [
      // "Did you know?" tip card — always visible
      const AlternativePlaceholder(),
```
Şununla değiştir:
```dart
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.compare_arrows_rounded, size: 18),
            label: Text(context.l10n.compare),
            onPressed: () => _startCompare(product),
          ),
        ),
      ),
      // "Did you know?" tip card — always visible
      const AlternativePlaceholder(),
```

- [ ] **Step 3: `_startCompare` metodu**

`_ProductDetailScreenState` içine (örn. `_redirectToEdit`'ten sonra) ekle:
```dart
  Future<void> _startCompare(ProductEntity product) async {
    final picked = await ProductPickerSheet.show(
      context,
      excludeBarcode: product.barcode,
    );
    if (picked == null || !mounted) return;
    context.push('/compare', extra: {'a': product.barcode, 'b': picked});
  }
```

- [ ] **Step 4: Verify**

Run: `flutter analyze lib/features/product/presentation/screens/product_detail_screen.dart`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/features/product/presentation/screens/product_detail_screen.dart
git commit -m "feat: compare entry point from product detail (picker → /compare)"
```

---

## Task 6: Favorilerde çoklu-seçim modu + "Kıyasla (n/2)"

**Files:**
- Modify: `lib/features/favorites/presentation/screens/favorites_screen.dart`

- [ ] **Step 1: Seç-modu state'i + AppBar aksiyonu**

`_FavoritesScreenState`'e alanlar ekle (TabController'ın yanına):
```dart
  bool _selectMode = false;
  final Set<String> _selected = {};

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      if (!_selectMode) _selected.clear();
    });
  }

  void _onToggleSelection(String barcode) {
    setState(() {
      if (_selected.contains(barcode)) {
        _selected.remove(barcode);
      } else if (_selected.length < 2) {
        _selected.add(barcode);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.compareMaxTwo)),
        );
      }
    });
  }

  void _goCompare() {
    if (_selected.length != 2) return;
    final list = _selected.toList();
    final a = list[0];
    final b = list[1];
    setState(() {
      _selectMode = false;
      _selected.clear();
    });
    context.push('/compare', extra: {'a': a, 'b': b});
  }
```

`build` içinde AppBar'a `actions:` ekle (favoriler tab'ında anlamlı; her zaman göster):
```dart
      appBar: AppBar(
        title: Text(l10n.favorites),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: l10n.compare,
            icon: Icon(_selectMode ? Icons.close : Icons.compare_arrows_rounded),
            onPressed: _toggleSelectMode,
          ),
        ],
        bottom: TabBar(
          // ... mevcut TabBar aynı ...
```

- [ ] **Step 2: Body'ye "Kıyasla (n/2)" çubuğu ekle**

`build`'deki `body:` mevcut hali:
```dart
      body: TabBarView(
        controller: _tabController,
        children: [_FavoritesTab(), _BlacklistTab()],
      ),
```
Şununla değiştir (seçimi `_FavoritesTab`'a geçir + alt çubuk):
```dart
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FavoritesTab(
                  selectMode: _selectMode,
                  selected: _selected,
                  onToggle: _onToggleSelection,
                ),
                _BlacklistTab(),
              ],
            ),
          ),
          if (_selectMode)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.compare_arrows_rounded),
                    label: Text('${l10n.compare} (${_selected.length}/2)'),
                    onPressed: _selected.length == 2 ? _goCompare : null,
                  ),
                ),
              ),
            ),
        ],
      ),
```

- [ ] **Step 3: `_FavoritesTab` seçim parametreleri**

`_FavoritesTab` sınıf imzasını güncelle:
```dart
class _FavoritesTab extends ConsumerWidget {
  final bool selectMode;
  final Set<String> selected;
  final void Function(String barcode) onToggle;

  const _FavoritesTab({
    required this.selectMode,
    required this.selected,
    required this.onToggle,
  });
```
`_buildList`'i seçim bilgisini iletecek şekilde güncelle:
```dart
  Widget _buildList(
    BuildContext context,
    List<ScanHistoryWithProduct> favorites,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: favorites.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
      itemBuilder: (ctx, index) => _FavoriteTile(
        item: favorites[index],
        selectMode: selectMode,
        isSelected: selected.contains(favorites[index].barcode),
        onToggleSelect: onToggle,
      ),
    );
  }
```

- [ ] **Step 4: `_FavoriteTile` — seçim davranışı**

`_FavoriteTile` imzasına alanlar ekle:
```dart
class _FavoriteTile extends ConsumerWidget {
  final ScanHistoryWithProduct item;
  final bool selectMode;
  final bool isSelected;
  final void Function(String barcode) onToggleSelect;

  const _FavoriteTile({
    required this.item,
    this.selectMode = false,
    this.isSelected = false,
    required this.onToggleSelect,
  });
```
`build`'deki `GestureDetector`'ı seç-moda göre davranacak şekilde güncelle:
- `onTap`: seç-modda `onToggleSelect(item.barcode)`, değilse mevcut `context.push('/product/${item.barcode}')`.
- `onLongPress`: seç-modda devre dışı (`null`).
- Satırın başına seç-modda bir checkbox ekle; seçiliyken kenarlığı vurgula.

Mevcut:
```dart
    return GestureDetector(
      onLongPress: () => _showRemoveDialog(context, ref),
      onTap: () => context.push('/product/${item.barcode}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colors.border.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
```
Şununla değiştir:
```dart
    return GestureDetector(
      onLongPress: selectMode ? null : () => _showRemoveDialog(context, ref),
      onTap: selectMode
          ? () => onToggleSelect(item.barcode)
          : () => context.push('/product/${item.barcode}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? context.colors.primary
                : context.colors.border.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (selectMode) ...[
              Icon(
                isSelected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? context.colors.primary
                    : context.colors.textMuted,
                size: 22,
              ),
              const SizedBox(width: 10),
            ],
```
> Not: Bu son `child: Row(children: [` bloğunun hemen ardına gelen **mevcut** ürün-görseli `Container`'ı ve devamı aynı kalır; yalnızca yukarıdaki `if (selectMode) ...[ ... ]` öğelerini Row'un ilk çocukları olarak eklemiş oluyorsun.

- [ ] **Step 5: Verify**

Run: `flutter analyze lib/features/favorites`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/features/favorites/presentation/screens/favorites_screen.dart
git commit -m "feat: favorites multi-select → compare two products"
```

---

## Task 7: Doğrulama

- [ ] **Step 1:** `flutter analyze` (tüm proje) → No issues found.
- [ ] **Step 2:** `flutter test` → mevcut + yeni testler (9 yeni) geçer.
- [ ] **Step 3: Manuel E2E:**
  - Favoriler → AppBar "Kıyasla" ikonu → 2 ürün seç → "Kıyasla (2/2)" → kıyas ekranı; başlıklar sticky, daha iyi taraf yeşil ✓.
  - 3. ürünü seçmeye çalış → "En fazla 2 ürün seçebilirsin" snackbar.
  - Ürün detayı → Alternatifler sekmesi → "Kıyasla" → picker'dan 2. ürün → kıyas ekranı.
  - Eksik veri (örn. AI öğün, `ai_` barkod) → ilgili satırlar "—", vurgu yok.

---

## Notlar / kapsam
- Yeni tablo/migration yok; kıyaslama tamamen mevcut sağlayıcılar üzerinden çalışır.
- "Daha iyi" yönü ve sayı formatı saf fonksiyonda; UI yalnızca etiket + birim + vurgu ekler.
- **Paylaş** butonu kasıtlı olarak burada yok — #3 (Paylaşma) planında `ComparisonScreen` altına eklenecek (şimdi ölü buton bırakılmaz).
- `ProductPickerSheet` favoriler + son taramaları birleştirip barkoda göre tekilleştirir; mevcut ürünü hariç tutar.
```