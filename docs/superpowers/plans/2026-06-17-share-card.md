# Paylaşma (Markalı Share Kartı) (#3) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ürün detayını ve AI öğününü, üretilen markalı 1:1 (1080×1080) bir görsel kart olarak tek dokunuşla sosyal medyada paylaş.

**Architecture:** Saf, sabit boyutlu render widget'ları (`ProductShareCard`, `MealShareCard`) ekran dışı bir `Overlay` içinde `RepaintBoundary` ile PNG'ye çevrilir (`ShareService`), temp dosyaya yazılır ve `share_plus` ile paylaşılır. Kart sabit aydınlık/marka paleti kullanır (uygulamanın dark teması değil). Altyazı saf bir `ShareCaption` birleştiricisinden gelir. Butonlar ürün detayı ve öğün-sonucu ekranlarının AppBar'ına eklenir.

**Tech Stack:** Flutter, Riverpod, `share_plus` (yeni), `path_provider` (mevcut), `dart:ui` RepaintBoundary capture.

---

## Dosya Yapısı

- **Modify:** `pubspec.yaml` — `share_plus` bağımlılığı.
- **Create:** `lib/core/constants/app_links.dart` — paylaşım mağaza linki sabiti.
- **Create:** `lib/features/share/domain/share_caption.dart` — saf altyazı birleştirici.
- **Create:** `test/features/share/domain/share_caption_test.dart`
- **Create:** `lib/features/share/presentation/widgets/share_card_palette.dart` — sabit aydınlık palet.
- **Create:** `lib/features/share/presentation/widgets/product_share_card.dart` + test.
- **Create:** `lib/features/share/presentation/widgets/meal_share_card.dart` + test.
- **Create:** `lib/core/services/share_service.dart` — capture + temp file + share, `shareServiceProvider`.
- **Modify:** `lib/features/product/presentation/screens/product_detail_screen.dart` — AppBar "Paylaş".
- **Modify:** `lib/features/scanner/presentation/screens/food_result_screen.dart` — AppBar "Paylaş".
- **Modify:** `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb` — paylaşım metinleri.

**Kapsam dışı:** deep link/app-links, story (9:16) varyantı, kıyas (#2) ekranı paylaşımı.

---

## Task 1: `share_plus` bağımlılığı + mağaza linki sabiti

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/constants/app_links.dart`

- [ ] **Step 1: Paketi ekle**

Run: `flutter pub add share_plus`
Expected: `pubspec.yaml`'a `share_plus: ^X` satırı eklenir (en güncel sürüm, ~12.x), `flutter pub get` çalışır.

> API notu (sonraki task'larda kullanılacak): güncel `share_plus` API'si `SharePlus.instance.share(ShareParams(files: [...], text: ...))` ve `XFile` (paketten re-export). Eğer kurulan sürüm eski çıkarsa (`SharePlus`/`ShareParams` sembolü yok), API `Share.shareXFiles([...], text: ...)` olur — Task 5'te buna göre uyarlanır.

- [ ] **Step 2: Mağaza linki sabiti**

`lib/core/constants/app_links.dart`:
```dart
abstract final class AppLinks {
  /// Play Store listing — used in share captions. Overridable via dart-define
  /// so a future custom landing page or App Store link is an ops change.
  static const shareStoreUrl = String.fromEnvironment(
    'SHARE_STORE_URL',
    defaultValue:
        'https://play.google.com/store/apps/details?id=com.nutrilensapp.android',
  );
}
```

- [ ] **Step 3: Verify**

Run: `flutter analyze lib/core/constants/app_links.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/constants/app_links.dart
git commit -m "build: add share_plus + store link constant"
```

---

## Task 2: `ShareCaption` saf altyazı birleştirici (TDD)

**Files:**
- Create: `lib/features/share/domain/share_caption.dart`
- Test: `test/features/share/domain/share_caption_test.dart`

- [ ] **Step 1: Failing test**

`test/features/share/domain/share_caption_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/share/domain/share_caption.dart';

void main() {
  const store = 'https://store.example/app';

  group('ShareCaption.forProduct', () {
    test('joins name, hp score and store with middots', () {
      final c = ShareCaption.forProduct(
        name: 'Sütaş Süt',
        hpScoreText: 'HP Skoru 82/100',
        scannedLabel: 'NutriLens ile tarandı',
        storeUrl: store,
      );
      expect(
        c,
        'Sütaş Süt — HP Skoru 82/100 · NutriLens ile tarandı · $store',
      );
    });

    test('omits the score segment when hpScoreText is null', () {
      final c = ShareCaption.forProduct(
        name: 'Sütaş Süt',
        hpScoreText: null,
        scannedLabel: 'NutriLens ile tarandı',
        storeUrl: store,
      );
      expect(c, 'Sütaş Süt · NutriLens ile tarandı · $store');
    });
  });

  group('ShareCaption.forMeal', () {
    test('joins food name, calories and store', () {
      final c = ShareCaption.forMeal(
        foodName: 'Mercimek Çorbası',
        calories: 240,
        calculatedLabel: 'NutriLens ile hesaplandı',
        storeUrl: store,
      );
      expect(
        c,
        'Mercimek Çorbası — 240 kcal · NutriLens ile hesaplandı · $store',
      );
    });
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/features/share/domain/share_caption_test.dart`
Expected: FAIL (`share_caption.dart` yok).

- [ ] **Step 3: Implement**

`lib/features/share/domain/share_caption.dart`:
```dart
/// Pure builders for the social-share caption text. Localized pieces
/// (`scannedLabel` / `calculatedLabel`) are passed in by the caller so this
/// stays locale-independent and unit-testable. Segments are joined with " · ".
abstract final class ShareCaption {
  static String forProduct({
    required String name,
    required String? hpScoreText,
    required String scannedLabel,
    required String storeUrl,
  }) {
    final head = hpScoreText == null ? name : '$name — $hpScoreText';
    return [head, scannedLabel, storeUrl].join(' · ');
  }

  static String forMeal({
    required String foodName,
    required int calories,
    required String calculatedLabel,
    required String storeUrl,
  }) {
    return ['$foodName — $calories kcal', calculatedLabel, storeUrl]
        .join(' · ');
  }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `flutter test test/features/share/domain/share_caption_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/share/domain/share_caption.dart test/features/share/domain/share_caption_test.dart
git commit -m "feat: pure share caption builder + tests"
```

---

## Task 3: Sabit palet + `ProductShareCard` (widget test)

**Files:**
- Create: `lib/features/share/presentation/widgets/share_card_palette.dart`
- Create: `lib/features/share/presentation/widgets/product_share_card.dart`
- Test: `test/features/share/presentation/widgets/product_share_card_test.dart`

- [ ] **Step 1: Sabit palet**

`lib/features/share/presentation/widgets/share_card_palette.dart`:
```dart
import 'package:flutter/material.dart';

/// Fixed light/brand palette for share cards — intentionally independent of
/// the app's (dark) theme so shared images read consistently on social feeds.
abstract final class ShareCardPalette {
  static const bg = Color(0xFFF6F8F4);
  static const surface = Color(0xFFFFFFFF);
  static const brand = Color(0xFF0E7A3B);
  static const textPrimary = Color(0xFF14201A);
  static const textMuted = Color(0xFF6B756E);
  static const border = Color(0xFFE2E8E2);

  // Gauge 1 (best) → 5 (worst).
  static const _gauge = <Color>[
    Color(0xFF2E9E5B),
    Color(0xFF7CB342),
    Color(0xFFF5A623),
    Color(0xFFEF6C00),
    Color(0xFFD7263D),
  ];

  static Color gaugeColor(int gauge) => _gauge[(gauge - 1).clamp(0, 4)];
}
```

- [ ] **Step 2: Failing widget test**

`test/features/share/presentation/widgets/product_share_card_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/share/presentation/widgets/product_share_card.dart';

void main() {
  testWidgets('renders name, brand, score and chips', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ProductShareCard(
              image: null,
              name: 'Sütaş Süt',
              brand: 'Sütaş',
              hpScore: 82,
              chips: ['Şeker: 5g', 'Katkı: 0', 'NOVA 1'],
              footer: 'NutriLens ile tarandı',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sütaş Süt'), findsOneWidget);
    expect(find.text('Sütaş'), findsOneWidget);
    expect(find.text('82'), findsOneWidget);
    expect(find.text('Şeker: 5g'), findsOneWidget);
    expect(find.text('Katkı: 0'), findsOneWidget);
    expect(find.text('NOVA 1'), findsOneWidget);
    expect(find.text('NutriLens ile tarandı'), findsOneWidget);
  });

  testWidgets('hides score badge when hpScore is null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ProductShareCard(
              image: null,
              name: 'X',
              brand: '',
              hpScore: null,
              chips: [],
              footer: 'f',
            ),
          ),
        ),
      ),
    );
    // No "HP" label rendered when score missing.
    expect(find.text('HP'), findsNothing);
  });
}
```

- [ ] **Step 3: Run — expect FAIL**

Run: `flutter test test/features/share/presentation/widgets/product_share_card_test.dart`
Expected: FAIL (`product_share_card.dart` yok).

- [ ] **Step 4: Implement**

`lib/features/share/presentation/widgets/product_share_card.dart`:
```dart
import 'package:flutter/material.dart';

import '../../../../core/constants/score_constants.dart';
import 'share_card_palette.dart';

/// Pure, fixed-size (360×360 logical) branded card for sharing a product.
/// Rendered off-screen and captured to a 1080px PNG by ShareService.
class ProductShareCard extends StatelessWidget {
  final ImageProvider? image;
  final String name;
  final String brand;
  final int? hpScore;
  final List<String> chips;
  final String footer;

  const ProductShareCard({
    super.key,
    required this.image,
    required this.name,
    required this.brand,
    required this.hpScore,
    required this.chips,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final gauge = ScoreConstants.hpToGauge(hpScore?.toDouble());
    final scoreColor = ShareCardPalette.gaugeColor(gauge);

    return Container(
      width: 360,
      height: 360,
      color: ShareCardPalette.bg,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: image != null
                      ? Image(
                          image: image!,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => _imgPlaceholder(),
                        )
                      : _imgPlaceholder(),
                ),
              ),
              const Spacer(),
              if (hpScore != null) _scoreBadge(hpScore!, scoreColor),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: ShareCardPalette.textPrimary,
              height: 1.15,
            ),
          ),
          if (brand.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              brand,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: ShareCardPalette.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final c in chips) _chip(c)],
          ),
          const Spacer(),
          _footerRow(footer),
        ],
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
    color: ShareCardPalette.surface,
    alignment: Alignment.center,
    child: const Icon(
      Icons.image_outlined,
      size: 36,
      color: ShareCardPalette.textMuted,
    ),
  );

  Widget _scoreBadge(int score, Color color) => Container(
    width: 76,
    height: 76,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 3),
    ),
    alignment: Alignment.center,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$score',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1,
          ),
        ),
        const Text(
          'HP',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: ShareCardPalette.textMuted,
          ),
        ),
      ],
    ),
  );

  Widget _chip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: ShareCardPalette.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: ShareCardPalette.border),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: ShareCardPalette.textPrimary,
      ),
    ),
  );

  Widget _footerRow(String text) => Row(
    children: [
      const Icon(Icons.qr_code_2_rounded, size: 28, color: ShareCardPalette.brand),
      const SizedBox(width: 8),
      Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: ShareCardPalette.brand,
        ),
      ),
    ],
  );
}
```

- [ ] **Step 5: Run — expect PASS**

Run: `flutter test test/features/share/presentation/widgets/product_share_card_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/share/presentation/widgets/share_card_palette.dart lib/features/share/presentation/widgets/product_share_card.dart test/features/share/presentation/widgets/product_share_card_test.dart
git commit -m "feat: product share card + fixed palette"
```

---

## Task 4: `MealShareCard` (widget test)

**Files:**
- Create: `lib/features/share/presentation/widgets/meal_share_card.dart`
- Test: `test/features/share/presentation/widgets/meal_share_card_test.dart`

- [ ] **Step 1: Failing widget test**

`test/features/share/presentation/widgets/meal_share_card_test.dart`:
```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/share/presentation/widgets/meal_share_card.dart';

void main() {
  testWidgets('renders food name, calories, macros and portion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MealShareCard(
              image: MemoryImage(Uint8List.fromList(const [0, 1, 2, 3])),
              foodName: 'Mercimek Çorbası',
              calories: 240,
              protein: 12,
              carbs: 30,
              fat: 6,
              portionGrams: 320,
              footer: 'NutriLens ile hesaplandı',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Mercimek Çorbası'), findsOneWidget);
    expect(find.text('240'), findsOneWidget);
    expect(find.text('12g'), findsOneWidget);
    expect(find.text('30g'), findsOneWidget);
    expect(find.text('6g'), findsOneWidget);
    expect(find.text('320 g'), findsOneWidget);
    expect(find.text('NutriLens ile hesaplandı'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/features/share/presentation/widgets/meal_share_card_test.dart`
Expected: FAIL (`meal_share_card.dart` yok).

- [ ] **Step 3: Implement**

`lib/features/share/presentation/widgets/meal_share_card.dart`:
```dart
import 'package:flutter/material.dart';

import 'share_card_palette.dart';

/// Pure, fixed-size (360×360 logical) branded card for sharing an AI meal.
/// Macro column labels use compact tokens (kcal / P / K / Y) — TR-first.
class MealShareCard extends StatelessWidget {
  final ImageProvider image;
  final String foodName;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int portionGrams;
  final String footer;

  const MealShareCard({
    super.key,
    required this.image,
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.portionGrams,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 360,
      color: ShareCardPalette.bg,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 132,
              width: double.infinity,
              child: Image(
                image: image,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  color: ShareCardPalette.surface,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.restaurant_rounded,
                    size: 36,
                    color: ShareCardPalette.textMuted,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            foodName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: ShareCardPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$portionGrams g',
            style: const TextStyle(
              fontSize: 13,
              color: ShareCardPalette.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _macro('$calories', 'kcal', ShareCardPalette.brand),
              _macro('${protein}g', 'P', ShareCardPalette.textPrimary),
              _macro('${carbs}g', 'K', ShareCardPalette.textPrimary),
              _macro('${fat}g', 'Y', ShareCardPalette.textPrimary),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(
                Icons.qr_code_2_rounded,
                size: 28,
                color: ShareCardPalette.brand,
              ),
              const SizedBox(width: 8),
              Text(
                footer,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ShareCardPalette.brand,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macro(String value, String label, Color color) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: ShareCardPalette.textMuted,
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `flutter test test/features/share/presentation/widgets/meal_share_card_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/share/presentation/widgets/meal_share_card.dart test/features/share/presentation/widgets/meal_share_card_test.dart
git commit -m "feat: meal share card"
```

---

## Task 5: `ShareService` — capture + temp file + share

**Files:**
- Create: `lib/core/services/share_service.dart`

> **Test note:** The capture+share path is intentionally **not** unit-tested. It needs a live render pipeline (`RenderRepaintBoundary.toImage` after a real frame) plus the platform share channel — neither runs reliably under `flutter test` (awaiting `endOfFrame` inside `tester.runAsync` hangs, and the share channel throws `MissingPluginException`). It is covered by the manual E2E in Task 8. The testable pieces (caption + both cards) already have automated tests.

- [ ] **Step 1: Implement service**

`lib/core/services/share_service.dart`:
```dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Renders a widget off-screen, captures it to a PNG, and opens the OS share
/// sheet. Reusable for any fixed-size card.
class ShareService {
  const ShareService();

  /// [card] is laid out at [logicalSize] in an off-screen Overlay and captured
  /// at [pixelRatio] (e.g. 360 logical × 3.0 = 1080px). Writes [fileName] to the
  /// temp dir and shares it with [caption]. [context] must have an Overlay
  /// (any routed screen does).
  Future<void> captureAndShare({
    required BuildContext context,
    required Widget card,
    required Size logicalSize,
    required double pixelRatio,
    required String fileName,
    required String caption,
  }) async {
    final boundaryKey = GlobalKey();
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        // Park it above the visible viewport: lays out at full size, unseen.
        left: 0,
        top: -logicalSize.height - 100,
        child: Material(
          type: MaterialType.transparency,
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: logicalSize.width,
              height: logicalSize.height,
              child: card,
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    try {
      // Let the off-screen subtree lay out + paint (image decode may need an
      // extra frame; caller precaches network/memory images beforehand).
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('share: capture produced no bytes');
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: caption),
      );
    } finally {
      entry.remove();
    }
  }
}

final shareServiceProvider = Provider<ShareService>(
  (ref) => const ShareService(),
);
```

- [ ] **Step 2: Verify analyze**

Run: `flutter analyze lib/core/services/share_service.dart`
Expected: No issues found. (If `SharePlus`/`ShareParams`/`XFile` are unresolved, the installed share_plus is older — switch the share call to `Share.shareXFiles([XFile(file.path)], text: caption)`.)

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/share_service.dart
git commit -m "feat: ShareService (off-screen capture -> PNG -> share)"
```

---

## Task 6: Ürün detayı "Paylaş" butonu + l10n

**Files:**
- Modify: `lib/features/product/presentation/screens/product_detail_screen.dart`
- Modify: `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb`

- [ ] **Step 1: l10n stringleri (her iki arb, `noHealthierAlternative` satırından sonra)**

`lib/l10n/app_tr.arb`:
```json
  "share": "Paylaş",
  "shareScannedWith": "NutriLens ile tarandı",
  "shareCalculatedWith": "NutriLens ile hesaplandı",
  "shareFailed": "Paylaşım başarısız",
```
`lib/l10n/app_en.arb`:
```json
  "share": "Share",
  "shareScannedWith": "Scanned with NutriLens",
  "shareCalculatedWith": "Calculated with NutriLens",
  "shareFailed": "Sharing failed",
```
Run: `flutter gen-l10n` → hatasız.

- [ ] **Step 2: Importlar**

`product_detail_screen.dart` üstüne ekle:
```dart
import '../../../../core/constants/app_links.dart';
import '../../../share/domain/share_caption.dart';
import '../../../share/presentation/widgets/product_share_card.dart';
```
(`product_provider.dart` zaten import edili — `shareServiceProvider` `core/services/share_service.dart`'ten gelir; onu da ekle:)
```dart
import '../../../../core/services/share_service.dart';
```

- [ ] **Step 3: `_shareProduct` metodu** (`_ProductDetailScreenState` içine, `_startCompare`'den sonra)

```dart
  Future<void> _shareProduct(ProductEntity product) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      ImageProvider? image;
      if (product.imageUrl != null) {
        image = NetworkImage(product.imageUrl!);
        // Off-screen capture can't wait on a network fetch — preload first.
        await precacheImage(image, context);
      }
      if (!mounted) return;

      final hp = product.calculatedHpScore;
      final n = product.nutriments;
      final chips = <String>[
        if (n.sugars != null) '${l10n.sugarLabel}: ${n.sugars!.round()}g',
        '${l10n.additives}: ${product.additivesTags.length}',
        if (product.novaGroup != null) 'NOVA ${product.novaGroup}',
      ];
      final name = product.productName ?? product.barcode;

      final card = ProductShareCard(
        image: image,
        name: name,
        brand: product.brands ?? '',
        hpScore: hp?.round(),
        chips: chips.take(3).toList(),
        footer: l10n.shareScannedWith,
      );
      final caption = ShareCaption.forProduct(
        name: name,
        hpScoreText: hp == null ? null : '${l10n.hpScoreLabel} ${hp.round()}/100',
        scannedLabel: l10n.shareScannedWith,
        storeUrl: AppLinks.shareStoreUrl,
      );

      await ref.read(shareServiceProvider).captureAndShare(
        context: context,
        card: card,
        logicalSize: const Size(360, 360),
        pixelRatio: 3.0,
        fileName: 'nutrilens_${product.barcode}.png',
        caption: caption,
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
      }
    }
  }
```

- [ ] **Step 4: AppBar'a "Paylaş" aksiyonu**

`build` içindeki AppBar `actions: productLoaded ? [ ... ] : null` listesinin **başına** (favori IconButton'dan önce) ekle:
```dart
                IconButton(
                  tooltip: l10n.share,
                  icon: const Icon(Icons.ios_share_rounded),
                  onPressed: () => _shareProduct(productAsync.value!),
                ),
```
(`productAsync` zaten `build` başında `ref.watch(productByBarcodeProvider(widget.barcode))` ile mevcut; `productLoaded == true` iken `productAsync.value` non-null.)

- [ ] **Step 5: Verify**

Run: `flutter analyze lib/features/product/presentation/screens/product_detail_screen.dart`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/features/product/presentation/screens/product_detail_screen.dart lib/l10n
git commit -m "feat: share branded product card from product detail"
```

---

## Task 7: Öğün sonucu "Paylaş" butonu

**Files:**
- Modify: `lib/features/scanner/presentation/screens/food_result_screen.dart`

- [ ] **Step 1: Importlar**

`food_result_screen.dart` üstüne ekle:
```dart
import '../../../../core/constants/app_links.dart';
import '../../../../core/services/share_service.dart';
import '../../../share/domain/share_caption.dart';
import '../../../share/presentation/widgets/meal_share_card.dart';
```

- [ ] **Step 2: `_shareMeal` metodu** (`_FoodResultScreenState` içine, `_saveMeal`'den sonra)

```dart
  Future<void> _shareMeal() async {
    final result = _result;
    if (result == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final image = MemoryImage(widget.imageBytes);
      await precacheImage(image, context);
      if (!mounted) return;

      final n = result.nutriments.scaled(_portionMultiplier);
      final cals = (n.energyKcal ?? 0).round();
      final card = MealShareCard(
        image: image,
        foodName: result.foodName,
        calories: cals,
        protein: (n.proteins ?? 0).round(),
        carbs: (n.carbohydrates ?? 0).round(),
        fat: (n.fat ?? 0).round(),
        portionGrams: (result.portionGrams * _portionMultiplier).round(),
        footer: l10n.shareCalculatedWith,
      );
      final caption = ShareCaption.forMeal(
        foodName: result.foodName,
        calories: cals,
        calculatedLabel: l10n.shareCalculatedWith,
        storeUrl: AppLinks.shareStoreUrl,
      );

      await ref.read(shareServiceProvider).captureAndShare(
        context: context,
        card: card,
        logicalSize: const Size(360, 360),
        pixelRatio: 3.0,
        fileName: 'nutrilens_meal_${DateTime.now().millisecondsSinceEpoch}.png',
        caption: caption,
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
      }
    }
  }
```

- [ ] **Step 3: AppBar'a "Paylaş" aksiyonu (sonuç hazırken)**

`build` içindeki AppBar'ı güncelle — sonuç yüklendiğinde aksiyon göster:
```dart
      appBar: AppBar(
        title: Text(l10n.aiAnalysisResult),
        backgroundColor: Colors.transparent,
        actions: [
          if (!_loading && _error == null && _result != null)
            IconButton(
              tooltip: l10n.share,
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: _shareMeal,
            ),
        ],
      ),
```

- [ ] **Step 4: Verify**

Run: `flutter analyze lib/features/scanner/presentation/screens/food_result_screen.dart`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/features/scanner/presentation/screens/food_result_screen.dart
git commit -m "feat: share branded meal card from food result"
```

---

## Task 8: Doğrulama

- [ ] **Step 1:** `flutter analyze` (tüm proje) → No issues found.
- [ ] **Step 2:** `flutter test` → mevcut + yeni testler (share_caption 3, product_share_card 2, meal_share_card 1) geçer.
- [ ] **Step 3: Manuel E2E (cihaz/emülatör gerekir):**
  - Ürün detayı → AppBar "Paylaş" → markalı kare kart + altyazı ile sistem share sheet açılır; görsel doğru ürün/HP/çipleri gösterir.
  - Görseli olmayan ürün → placeholder'lı kart, çökme yok.
  - AI öğün sonucu → "Paylaş" → öğün fotoğrafı + kalori/makro kartı paylaşılır; porsiyon çarpanı kartı etkiler.
  - iOS + Android'de share sheet açılır (share_plus soyutlar).

---

## Notlar / kapsam
- Kart sabit aydınlık palet (`ShareCardPalette`) kullanır — uygulamanın dark teması değil.
- ShareService herhangi bir sabit boyutlu widget'ı yakalar; karta bağımlı değil (DRY/yeniden kullanılabilir).
- Makro etiketleri (kcal/P/K/Y) TR-öncelikli kompakt tokenlar; kartın tam İngilizce yerelleştirmesi kapsam dışı (altyazı ve footer yerelleştirilir).
- Kıyas (#2) ekranı paylaşımı bilinçli olarak ertelendi (ShareService + ProductShareCard hazır olduğundan ileride kolay eklenir).
- `share_plus` API'si sür2üme göre değişebilir; Task 1/5 notuna göre `SharePlus.instance.share(ShareParams(...))` (yeni) ya da `Share.shareXFiles(...)` (eski).
