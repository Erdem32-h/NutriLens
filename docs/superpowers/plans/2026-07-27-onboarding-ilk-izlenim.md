# Onboarding İlk İzlenim — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Onboarding'in üç sayfasını jenerik Material ikonlarından uygulamanın gerçek widget'larıyla kurulmuş ürün önizlemelerine çevirmek — sayfa 0'daki %33'lük kaybı azaltmak.

**Architecture:** `OnboardingScreen` sabit `IconData` yerine sayfa başına bir `WidgetBuilder` taşır. Üç önizleme widget'ı yeni bir dosyaya çıkarılır. Tarama animasyonu `FoodResultScreen`'den paylaşılan `ScanningPhoto`'ya taşınır ve **sınırlı süpürme** yeteneği kazanır. Metinler yeni l10n anahtarlarına taşınır, yetim kalan 5 anahtar silinir.

**Tech Stack:** Flutter, Riverpod 3, `flutter_gen-l10n` (arb), `flutter_test`

**Spec:** `docs/superpowers/specs/2026-07-27-onboarding-ilk-izlenim-design.md`

## Global Constraints

- **`scanBarcodeTitle` anahtarına DOKUNULMAZ.** `lib/features/scanner/presentation/screens/food_result_screen.dart:231`'de "paketli ürün" diyaloğunun buton etiketi olarak kullanılıyor. Onboarding için yeniden kullanılmaz, değeri değiştirilmez.
- **Onboarding'de animasyon sonsuz olamaz.** `test/features/auth/onboarding_screen_test.dart` dört testte de `pumpAndSettle()` çağırıyor; sonsuz tekrarlayan animasyon bunu zaman aşımına düşürür.
- **Sabit satır sonu (`\n`) kullanılmaz** başlık/açıklama metinlerinde — 6 dilde farklı sarma gerekir.
- **Sabit yükseklik verilmez** önizleme widget'larına; `375×667` taşma testi geçmek zorunda.
- **Hitap "sen"** — tüm yeni Türkçe metinler ikinci tekil.
- **Örnek veriler illüstratiftir**; ekranda "hesaplandı" iddiası yoktur.
- Şablon arb `lib/l10n/app_tr.arb`; diğer 5 dil (`en`, `es`, `pt`, `ar`, `zh`) onu takip eder.
- Her task sonunda `flutter analyze` temiz olmalı.

---

### Task 1: l10n anahtarları (6 dil)

Yeni onboarding metinlerini ekle, yetim kalanları sil. Bu ilk task çünkü Task 3 ve 4 bu anahtarları kullanıyor.

**Files:**
- Modify: `lib/l10n/app_tr.arb` (71. satırdan sonra ekleme)
- Modify: `lib/l10n/app_en.arb` (71. satırdan sonra ekleme)
- Modify: `lib/l10n/app_es.arb` (71. satırdan sonra ekleme)
- Modify: `lib/l10n/app_pt.arb` (71. satırdan sonra ekleme)
- Modify: `lib/l10n/app_ar.arb` (71. satırdan sonra ekleme)
- Modify: `lib/l10n/app_zh.arb` (71. satırdan sonra ekleme)

**Interfaces:**
- Consumes: yok (ilk task)
- Produces: `AppLocalizations` üzerinde 9 yeni getter — `onboardingMealTitle`, `onboardingMealBody`, `onboardingBarcodeTitle`, `onboardingBarcodeBody`, `onboardingFiltersTitle`, `onboardingFiltersBody`, `onboardingSampleMealName`, `onboardingSamplePortion`, `onboardingSampleWarning` (hepsi `String get`)

> **Bu task yalnızca EKLER, hiçbir şey silmez.** Eski anahtarlar yerinde
> kalır ki derleme yeşil kalsın ve bu commit tek başına çalışır durumda
> olsun. Yetim kalan 5 anahtar, ekran onları kullanmayı bıraktıktan sonra
> Task 5'te silinir.

- [ ] **Step 1: Ekleme noktasının doğru olduğunu doğrula**

Altı dosyada da 71. satırın `personalFiltersDescription` olduğunu teyit et — yeni anahtarlar bunun hemen altına gelecek.

Run:
```bash
for f in tr en es pt ar zh; do printf '%s: ' "$f"; sed -n '71p' "lib/l10n/app_$f.arb"; done
```

Expected: altı satırın da `"personalFiltersDescription": ...` ile başlaması. Farklıysa o dosyada anahtarı elle bul ve ekleme noktasını ona göre seç.

- [ ] **Step 2: `app_tr.arb` — 71. satırdan sonra ekle**

```json
  "onboardingMealTitle": "Tabağını çek, gerisini biz sayalım.",
  "onboardingMealBody": "Kalori, protein ve sağlık puanı — tek fotoğrafla.",
  "onboardingBarcodeTitle": "Paketliyse barkodu okut.",
  "onboardingBarcodeBody": "Katkı maddeleri, şeker ve tuz tek bakışta.",
  "onboardingFiltersTitle": "Sana göre uyarı versin.",
  "onboardingFiltersBody": "Alerjenini ve diyetini seç, sakıncalıyı hemen gör.",
  "onboardingSampleMealName": "Kıymalı makarna",
  "onboardingSamplePortion": "~320 g porsiyon",
  "onboardingSampleWarning": "Bu üründe laktoz var — senin listende.",
```

- [ ] **Step 3: `app_en.arb` — aynı noktaya ekle**

```json
  "onboardingMealTitle": "Snap your plate, we'll do the math.",
  "onboardingMealBody": "Calories, protein and a health score — from one photo.",
  "onboardingBarcodeTitle": "Packaged? Scan the barcode.",
  "onboardingBarcodeBody": "Additives, sugar and salt at a glance.",
  "onboardingFiltersTitle": "Get warnings that fit you.",
  "onboardingFiltersBody": "Pick your allergens and diet, spot problems instantly.",
  "onboardingSampleMealName": "Pasta with ground beef",
  "onboardingSamplePortion": "~320 g serving",
  "onboardingSampleWarning": "This product contains lactose — it's on your list.",
```

- [ ] **Step 4: `app_es.arb` — aynı noktaya ekle**

```json
  "onboardingMealTitle": "Fotografía tu plato, nosotros contamos.",
  "onboardingMealBody": "Calorías, proteína y puntuación de salud — con una foto.",
  "onboardingBarcodeTitle": "¿Envasado? Escanea el código.",
  "onboardingBarcodeBody": "Aditivos, azúcar y sal de un vistazo.",
  "onboardingFiltersTitle": "Avisos hechos para ti.",
  "onboardingFiltersBody": "Elige tus alérgenos y tu dieta, detecta lo dañino al instante.",
  "onboardingSampleMealName": "Pasta con carne picada",
  "onboardingSamplePortion": "~320 g de ración",
  "onboardingSampleWarning": "Este producto contiene lactosa — está en tu lista.",
```

- [ ] **Step 5: `app_pt.arb` — aynı noktaya ekle**

```json
  "onboardingMealTitle": "Fotografe seu prato, a conta é nossa.",
  "onboardingMealBody": "Calorias, proteína e pontuação de saúde — com uma foto.",
  "onboardingBarcodeTitle": "É embalado? Escaneie o código.",
  "onboardingBarcodeBody": "Aditivos, açúcar e sal num relance.",
  "onboardingFiltersTitle": "Avisos feitos para você.",
  "onboardingFiltersBody": "Escolha seus alergênicos e dieta, veja o problema na hora.",
  "onboardingSampleMealName": "Macarrão com carne moída",
  "onboardingSamplePortion": "~320 g de porção",
  "onboardingSampleWarning": "Este produto contém lactose — está na sua lista.",
```

- [ ] **Step 6: `app_ar.arb` — aynı noktaya ekle**

```json
  "onboardingMealTitle": "صوّر طبقك، ونحن نحسب الباقي.",
  "onboardingMealBody": "السعرات والبروتين ودرجة الصحة — من صورة واحدة.",
  "onboardingBarcodeTitle": "مُغلّف؟ امسح الباركود.",
  "onboardingBarcodeBody": "المضافات والسكر والملح بنظرة واحدة.",
  "onboardingFiltersTitle": "تنبيهات على مقاسك.",
  "onboardingFiltersBody": "اختر مسبّبات حساسيتك ونظامك الغذائي، واكتشف الضار فورًا.",
  "onboardingSampleMealName": "مكرونة باللحم المفروم",
  "onboardingSamplePortion": "~320 غ للحصة",
  "onboardingSampleWarning": "هذا المنتج يحتوي على اللاكتوز — وهو ضمن قائمتك.",
```

- [ ] **Step 7: `app_zh.arb` — aynı noktaya ekle**

```json
  "onboardingMealTitle": "拍下你的餐盘，剩下的交给我们。",
  "onboardingMealBody": "热量、蛋白质和健康评分——一张照片搞定。",
  "onboardingBarcodeTitle": "包装食品？扫描条形码。",
  "onboardingBarcodeBody": "添加剂、糖和盐，一目了然。",
  "onboardingFiltersTitle": "为你定制的提醒。",
  "onboardingFiltersBody": "选择过敏原和饮食偏好，问题立刻显现。",
  "onboardingSampleMealName": "肉酱意面",
  "onboardingSamplePortion": "约 320 克一份",
  "onboardingSampleWarning": "该产品含乳糖——在你的清单中。",
```

- [ ] **Step 8: Kod üretimini çalıştır**

Run: `flutter gen-l10n`
Expected: hatasız tamamlanır; `lib/l10n/generated/app_localizations.dart` içinde `onboardingMealTitle` getter'ı belirir.

Doğrula:
```bash
grep -c "onboardingMealTitle" lib/l10n/generated/app_localizations.dart
```
Expected: `1` (abstract tanım) — dil dosyalarında da ayrıca birer tane olur.

- [ ] **Step 9: Derlemenin hâlâ yeşil olduğunu doğrula**

Run: `flutter analyze lib/`
Expected: `No issues found!` — bu task yalnızca ekleme yaptı, hiçbir çağrı noktası bozulmadı.

- [ ] **Step 10: Commit**

```bash
git add lib/l10n/
git commit -m "feat(l10n): onboarding icin yeni metin anahtarlari (6 dil)

Vaat/urun uyumsuzlugunu ve jargonu gideren yeni metinler eklendi. Eski
anahtarlar simdilik yerinde birakildi ki derleme yesil kalsin; ekran
gecince Task 5'te silinecekler."
```

---

### Task 2: `ScanningPhoto` paylaşılan widget'a çıkarılıyor

Tarama çizgisi animasyonu bugün `food_result_screen.dart` içinde private. Onboarding'de yeniden kullanmak için çıkarılıyor ve **sınırlı süpürme** yeteneği kazanıyor.

**Files:**
- Create: `lib/core/widgets/scanning_photo.dart`
- Modify: `lib/features/scanner/presentation/screens/food_result_screen.dart` (satır ~469 kullanım; satır ~894-1030 private sınıflar silinecek)
- Test: `test/core/widgets/scanning_photo_test.dart`

**Interfaces:**
- Consumes: yok
- Produces: `class ScanningPhoto extends StatefulWidget` — kurucu `const ScanningPhoto({Key? key, required ImageProvider image, int? sweeps})`. `sweeps == null` → sonsuz tekrar (food-result davranışı). `sweeps` bir tamsayıysa o kadar tek yönlü geçişten sonra çizgi kaybolur.

- [ ] **Step 1: Başarısız testi yaz**

Create `test/core/widgets/scanning_photo_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/core/widgets/scanning_photo.dart';

/// 1x1 saydam PNG — testin görsel çözmeye değil animasyona odaklanması için.
final Uint8List _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQ'
  'GAhKmMIQAAAABJRU5ErkJggg==',
);

Future<void> _pump(WidgetTester tester, {int? sweeps}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SizedBox(
          width: 240,
          height: 135,
          child: ScanningPhoto(image: MemoryImage(_pixel), sweeps: sweeps),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('sinirli supurme yerlesir, pumpAndSettle kilitlenmez', (
    tester,
  ) async {
    // Onboarding bunu sonlu bir degerle cagirir. Sonsuz olsaydi
    // pumpAndSettle asla donmez ve onboarding testleri timeout'a duserdi.
    await _pump(tester, sweeps: 2);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('supurme bitince tarama cizgisi kaldirilir', (tester) async {
    await _pump(tester, sweeps: 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('scan-line')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('scan-line')), findsNothing);
  });

  testWidgets('sweeps null iken animasyon surer', (tester) async {
    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('scan-line')), findsOneWidget);

    // Sonsuz mod: birkac saniye sonra hala tarıyor olmali.
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(const ValueKey('scan-line')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test test/core/widgets/scanning_photo_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:nutrilens/core/widgets/scanning_photo.dart'`

- [ ] **Step 3: `ScanningPhoto`'yu oluştur**

Create `lib/core/widgets/scanning_photo.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fotoğrafın üzerinde yukarıdan aşağı süpüren tarama çizgisi.
///
/// `FoodResultScreen`'den çıkarıldı: onboarding, analiz ekranının kullandığı
/// animasyonun aynısını göstersin diye. Ayrı bir "onboarding animasyonu"
/// yazmak ikisini zamanla birbirinden uzaklaştırırdı.
///
/// [sweeps] animasyonu sınırlar:
///   * `null` — pencere kapanana kadar tekrarlar. `FoodResultScreen` bunu
///     kullanır; analiz bitince widget zaten sonuç görünümüyle değişir.
///   * tamsayı — o kadar tek yönlü geçişten sonra çizgi kaldırılır.
///
/// Onboarding **sonlu bir değer vermek zorundadır**: sonsuz animasyon
/// widget testlerindeki `pumpAndSettle()` çağrılarını zaman aşımına düşürür,
/// ve sayılar zaten ekrandayken durmadan tarayan bir fotoğraf kullanıcıya
/// "hâlâ yükleniyor" der.
class ScanningPhoto extends StatefulWidget {
  final ImageProvider image;
  final int? sweeps;

  const ScanningPhoto({super.key, required this.image, this.sweeps});

  @override
  State<ScanningPhoto> createState() => _ScanningPhotoState();
}

class _ScanningPhotoState extends State<ScanningPhoto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _passes = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.sweeps == null) {
      _controller.repeat(reverse: true);
    } else {
      _controller.addStatusListener(_onPassEnd);
      _controller.forward();
    }
  }

  void _onPassEnd(AnimationStatus status) {
    final isEnd =
        status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed;
    if (!isEnd) return;

    _passes++;
    if (_passes >= widget.sweeps!) {
      if (mounted) setState(() => _finished = true);
      return;
    }
    if (status == AnimationStatus.completed) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: widget.image,
          fit: BoxFit.cover,
          // Varlık yüklenemezse ekran çökmesin; sade bir dolgu yeterli.
          errorBuilder: (_, _, _) => ColoredBox(color: colors.surfaceCard),
        ),
        // Karartma yalnızca tarama sürerken: bittiğinde fotoğraf net kalsın.
        if (!_finished)
          Container(color: Colors.black.withValues(alpha: 0.18)),
        if (!_finished)
          AnimatedBuilder(
            key: const ValueKey('scan-line'),
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _ScanLinePainter(
                  progress: _controller.value,
                  color: colors.primary,
                ),
              );
            },
          ),
        IgnorePointer(
          child: CustomPaint(
            painter: _ViewfinderCornersPainter(color: colors.primary),
          ),
        ),
      ],
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;

  _ScanLinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 12.0;
    final top = inset;
    final bottom = size.height - inset;
    final y = top + (bottom - top) * progress;

    final bandHeight = size.height * 0.18;
    final bandRect = Rect.fromLTWH(
      inset,
      y - bandHeight,
      size.width - inset * 2,
      bandHeight,
    );
    final bandPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.0), color.withValues(alpha: 0.22)],
      ).createShader(bandRect);
    canvas.drawRect(bandRect, bandPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(inset, y), Offset(size.width - inset, y), linePaint);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter old) =>
      old.progress != progress || old.color != color;
}

class _ViewfinderCornersPainter extends CustomPainter {
  final Color color;

  _ViewfinderCornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const pad = 12.0;
    final len = size.shortestSide * 0.10;

    void corner(Offset origin, double dx, double dy) {
      canvas.drawLine(origin, origin.translate(len * dx, 0), p);
      canvas.drawLine(origin, origin.translate(0, len * dy), p);
    }

    corner(const Offset(pad, pad), 1, 1);
    corner(Offset(size.width - pad, pad), -1, 1);
    corner(Offset(pad, size.height - pad), 1, -1);
    corner(Offset(size.width - pad, size.height - pad), -1, -1);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderCornersPainter old) =>
      old.color != color;
}
```

- [ ] **Step 4: Testi çalıştır, geçtiğini gör**

Run: `flutter test test/core/widgets/scanning_photo_test.dart`
Expected: PASS (3 test)

- [ ] **Step 5: `FoodResultScreen`'i yeni widget'a bağla**

`lib/features/scanner/presentation/screens/food_result_screen.dart` içinde:

1. Import ekle (mevcut `core/...` import'larının arasına, alfabetik):
```dart
import '../../../../core/widgets/scanning_photo.dart';
```

2. `_buildLoading` içindeki kullanımı değiştir:
```dart
                child: _ScanningPhoto(imageBytes: widget.imageBytes),
```
yerine:
```dart
                child: ScanningPhoto(image: MemoryImage(widget.imageBytes)),
```
(`sweeps` verilmiyor → sonsuz; analiz bitince bu görünüm zaten değişiyor.)

3. Dosyanın sonundaki üç private sınıfı **tamamen sil**: `_ScanningPhoto`, `_ScanningPhotoState`, `_ScanLinePainter`, `_ViewfinderCornersPainter`. (`_PortionMultiplierSelector` ve `_PortionOption` **kalır**.)

- [ ] **Step 6: Analiz ve mevcut testleri çalıştır**

Run: `flutter analyze lib/core/widgets/scanning_photo.dart lib/features/scanner/presentation/screens/food_result_screen.dart`
Expected: `No issues found!`

Run: `flutter test test/core/services/nutrition_ocr_result_test.dart test/core/widgets/scanning_photo_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/core/widgets/scanning_photo.dart lib/features/scanner/presentation/screens/food_result_screen.dart test/core/widgets/scanning_photo_test.dart
git commit -m "refactor: tarama animasyonunu paylasilan ScanningPhoto'ya cikar

Onboarding ayni animasyonu yeniden kullanacak. sweeps parametresi sinirli
supurme sagliyor: sonsuz animasyon widget testlerindeki pumpAndSettle'i
kilitler ve kullaniciya 'hala yukleniyor' mesaji verir."
```

---

### Task 3: Üç önizleme widget'ı

**Files:**
- Create: `lib/features/auth/presentation/widgets/onboarding_previews.dart`
- Test: `test/features/auth/onboarding_previews_test.dart`

**Interfaces:**
- Consumes: `ScanningPhoto` (Task 2); Task 1'in l10n anahtarları
- Produces: `class MealPreview extends StatelessWidget` (`const MealPreview({Key? key})`), `class ScorePreview extends StatelessWidget` (`const ScorePreview({Key? key})`), `class FiltersPreview extends StatelessWidget` (`const FiltersPreview({Key? key})`) — üçü de parametresiz, `MainAxisSize.min` ile dikeyde kendi doğal yüksekliğini alır.

- [ ] **Step 1: Başarısız testi yaz**

Create `test/features/auth/onboarding_previews_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/auth/presentation/widgets/onboarding_previews.dart';
import 'package:nutrilens/features/product/presentation/widgets/health_score_bar.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  Locale locale = const Locale('tr'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('MealPreview ornek degerleri gosterir', (tester) async {
    await _pump(tester, const MealPreview());

    expect(find.text('Kıymalı makarna'), findsOneWidget);
    expect(find.text('486'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ScorePreview gauge 4 gosterir', (tester) async {
    await _pump(tester, const ScorePreview());

    // hpScore 26 -> ScoreConstants.hpToGauge -> 4. Katki sayisi da 4
    // oldugu icin duz find.text('4') iki eslesme bulur; gauge'i
    // HealthScoreBar'in icinde arayarak daraltiyoruz.
    expect(
      find.descendant(
        of: find.byType(HealthScoreBar),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('FiltersPreview cip ve uyariyi gosterir', (tester) async {
    await _pump(tester, const FiltersPreview());

    expect(find.text('Gluten'), findsOneWidget);
    expect(find.text('Laktoz'), findsOneWidget);
    expect(
      find.text('Bu üründe laktoz var — senin listende.'),
      findsOneWidget,
    );
  });

  testWidgets('uc onizleme de koyu temada hatasiz cizilir', (tester) async {
    for (final w in const [MealPreview(), ScorePreview(), FiltersPreview()]) {
      await _pump(tester, w, theme: AppTheme.dark);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('uc onizleme de Arapca (RTL) hatasiz cizilir', (tester) async {
    for (final w in const [MealPreview(), ScorePreview(), FiltersPreview()]) {
      await _pump(tester, w, locale: const Locale('ar'));
      expect(tester.takeException(), isNull);
    }
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test test/features/auth/onboarding_previews_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../onboarding_previews.dart'`

- [ ] **Step 3: Önizleme widget'larını yaz**

Create `lib/features/auth/presentation/widgets/onboarding_previews.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/score_constants.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/scanning_photo.dart';
import '../../../product/presentation/widgets/health_score_bar.dart';

/// Onboarding'de gösterilen örnek değerler.
///
/// İllüstratiftir — hesaplanmış sonuç değildir. Fotoğraftaki yemek için
/// makul seçildiler (≈320 g kıymalı makarna). Ekranda "hesaplandı" iddiası
/// yok; amaç ürünün ne ürettiğini göstermek.
abstract final class _Sample {
  /// 62 → ScoreConstants.hpToGauge → 2. Bilinçli olarak "iyi ama mükemmel
  /// değil": 1/5 ürünü işlevsiz gösterir, 5/5 ilk ekranda suçlayıcı durur.
  static const double mealHp = 62.0;
  static const int kcal = 486;
  static const int proteinG = 24;

  /// 26 → gauge 4. Paketli ürünün skorun işe yaradığını göstermesi için
  /// kötümser tarafta.
  static const double productHp = 26.0;
  static const int sugarG = 21;
  static const int additiveCount = 4;
  static const double saltG = 1.2;
}

/// Sayfa 0 — asıl akış: tabak fotoğrafı → kalori/protein/puan.
class MealPreview extends StatelessWidget {
  const MealPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            // sweeps sonlu olmak ZORUNDA — bkz. ScanningPhoto belgesi.
            child: const ScanningPhoto(
              image: AssetImage('assets/images/onboarding_meal.jpg'),
              sweeps: 2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.onboardingSampleMealName,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.onboardingSamplePortion,
          style: TextStyle(fontSize: 12, color: colors.textMuted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCell(value: '${_Sample.kcal}', label: 'kcal'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCell(
                value: '${_Sample.proteinG} g',
                label: l10n.proteinLabel,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCell(
                value: '${ScoreConstants.hpToGauge(_Sample.mealHp)}/5',
                label: l10n.healthScoreLabel,
                valueColor: colors.gaugeColor(
                  ScoreConstants.hpToGauge(_Sample.mealHp),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Sayfa 1 — paketli ürün: gerçek HealthScoreBar + ambalajda görülebilen
/// somut değerler (jargon değil).
class ScorePreview extends StatelessWidget {
  const ScorePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ürün ekranındaki widget'ın ta kendisi — onboarding'in vaadi ile
        // uygulamanın gösterdiği şey birebir aynı olsun diye.
        const HealthScoreBar(hpScore: _Sample.productHp),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _StatCell(
                value: '${_Sample.sugarG} g',
                label: l10n.sugarLabel,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCell(
                value: '${_Sample.additiveCount}',
                label: l10n.additives,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCell(
                value:
                    '${NumberFormat.decimalPattern(locale).format(_Sample.saltG)} g',
                label: l10n.saltLabel,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Sayfa 2 — kişiselleştirmenin somut çıktısı: bir uyarı.
///
/// Burası yalnızca anlatım görselidir; gerçek filtre ayarı profilde kalır.
class FiltersPreview extends StatelessWidget {
  const FiltersPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(label: l10n.filterGluten, selected: true),
            _Chip(label: l10n.filterLactose, selected: true),
            _Chip(label: l10n.vegan, selected: false),
            _Chip(label: l10n.halal, selected: false),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: colors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.onboardingSampleWarning,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: colors.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const _StatCell({
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor ?? colors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;

  const _Chip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? colors.primary.withValues(alpha: 0.15)
            : colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? colors.primary : colors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? colors.primary : colors.textMuted,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Testi çalıştır, geçtiğini gör**

Run: `flutter test test/features/auth/onboarding_previews_test.dart`
Expected: PASS (5 test)

- [ ] **Step 5: Analiz**

Run: `flutter analyze lib/features/auth/presentation/widgets/onboarding_previews.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/auth/presentation/widgets/onboarding_previews.dart test/features/auth/onboarding_previews_test.dart
git commit -m "feat(onboarding): urunun gercek widget'lariyla uc onizleme

MealPreview asil akisi (tabak fotografi), ScorePreview gercek
HealthScoreBar'i, FiltersPreview kisisellestirmenin somut ciktisini
gosteriyor. Ornek degerler illustratif; jargon yerine ambalajda gorulebilen
seyler kullanildi."
```

---

### Task 4: `OnboardingScreen`'i yeni yapıya bağla

**Files:**
- Modify: `lib/features/auth/presentation/screens/onboarding_screen.dart`
- Test: `test/features/auth/onboarding_screen_test.dart` (mevcut dosya, ekleme)

**Interfaces:**
- Consumes: `MealPreview`, `ScorePreview`, `FiltersPreview` (Task 3); Task 1 anahtarları
- Produces: yok (ekran son tüketici)

- [ ] **Step 1: `page=0` analitiği için başarısız testi yaz**

Ölçümü doğrulamanın yolu `test/core/analytics/analytics_service_test.dart`'ta zaten kurulu: sahte uploader + açık `flush()`. Aynı deseni kullan — `AnalyticsService`'e testler için yeni bir API **ekleme** (servis yalnızca `pendingCount` açıyor, olayların kendisini değil).

`test/features/auth/onboarding_screen_test.dart` başına import ekle:

```dart
import 'package:nutrilens/core/analytics/analytics_event.dart';
import 'package:nutrilens/core/analytics/analytics_provider.dart';
import 'package:nutrilens/core/analytics/analytics_service.dart';
import 'package:nutrilens/core/services/device_id_service.dart';
```

`_smallPhone` sabitinin altına sahte uploader'ı ekle:

```dart
/// Supabase'e gitmek yerine gönderilen partileri yakalar — analytics
/// servisinin kendi testlerindeki desenin aynısı.
class _RecordingUploader {
  final List<List<Map<String, Object?>>> batches = [];

  Future<void> call({
    required String deviceHash,
    required List<Map<String, Object?>> events,
  }) async {
    batches.add(events);
  }
}
```

`_pumpOnboarding`'in imzasını ve `prefs`'ten sonraki kısmını değiştir; router kurulumu ve `pumpWidget` aynen kalır:

```dart
Future<ProviderContainer> _pumpOnboarding(
  WidgetTester tester, {
  _RecordingUploader? uploader,
}) async {
  tester.view.physicalSize = _smallPhone;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  // flushInterval sıfır: flutter_test, widget ağacından uzun yaşayan bir
  // timer'a izin vermiyor ve bunu tearDown'dan ÖNCE denetliyor.
  final analytics = AnalyticsService(
    client: null,
    deviceId: DeviceIdService(prefs),
    prefs: prefs,
    uploader: uploader?.call,
    flushInterval: Duration.zero,
  );
  addTearDown(analytics.dispose);

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      currentUserProvider.overrideWithValue(null),
      analyticsServiceProvider.overrideWithValue(analytics),
    ],
  );
  addTearDown(container.dispose);
```

`main()` içine testi ekle:

```dart
  testWidgets('ilk sayfa gorunumu de olay olarak isaretlenir', (tester) async {
    final uploader = _RecordingUploader();
    final container = await _pumpOnboarding(tester, uploader: uploader);

    await container.read(analyticsServiceProvider).flush();

    // onboarding_page_viewed bugune kadar yalnizca onPageChanged'de
    // atesleniyordu, yani sayfa 0 hic olcumlenmiyordu ve huni ancak
    // onboarding_shown'dan cikarim yapilarak okunabiliyordu.
    final events = uploader.batches.expand((b) => b).toList();
    expect(
      events.where(
        (e) =>
            e['event'] == FunnelEvents.onboardingPageViewed &&
            (e['props'] as Map)['page'] == 0,
      ),
      hasLength(1),
    );
  });
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test test/features/auth/onboarding_screen_test.dart --plain-name "ilk sayfa gorunumu"`
Expected: FAIL — `Expected: an object with length of <1>` / `Actual: <[]>`; olay hiç ateşlenmiyor.

- [ ] **Step 3: `_PageData`'yı görsel builder'a çevir**

`onboarding_screen.dart` dosyasının sonundaki sınıfı değiştir:

```dart
class _PageData {
  /// Sayfanın görseli. Eskiden sabit bir `IconData` idi; üç sayfanın
  /// görseli artık birbirinden farklı gerçek ürün önizlemeleri.
  final WidgetBuilder visual;
  final String title;
  final String description;

  const _PageData({
    required this.visual,
    required this.title,
    required this.description,
  });
}
```

- [ ] **Step 4: `pages` listesini ve `itemBuilder`'ı değiştir**

`build` içindeki `pages` listesini şununla değiştir:

```dart
    final pages = [
      _PageData(
        visual: (_) => const MealPreview(),
        title: l10n.onboardingMealTitle,
        description: l10n.onboardingMealBody,
      ),
      _PageData(
        visual: (_) => const ScorePreview(),
        title: l10n.onboardingBarcodeTitle,
        description: l10n.onboardingBarcodeBody,
      ),
      _PageData(
        visual: (_) => const FiltersPreview(),
        title: l10n.onboardingFiltersTitle,
        description: l10n.onboardingFiltersBody,
      ),
    ];
```

`itemBuilder` içindeki `FadeTransition`'ın çocuğunu şununla değiştir (ikon `Container`'ı ve ardındaki `SizedBox(height: 48)` gider):

```dart
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Görsele sabit yükseklik verilmez: küçük
                                  // ekranda (375x667) metinle birlikte
                                  // taşmasın diye görünürlüğün yarısıyla
                                  // sınırlanır.
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: constraints.maxHeight * 0.5,
                                    ),
                                    child: page.visual(context),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    page.title,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: context.colors.textPrimary,
                                      letterSpacing: -0.5,
                                      height: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    page.description,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      color: context.colors.textMuted,
                                      height: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
```

Import ekle:
```dart
import '../widgets/onboarding_previews.dart';
```

- [ ] **Step 5: `page=0` olayını ateşle**

`initState` içindeki mevcut satırı:
```dart
    ref.read(analyticsServiceProvider).track(FunnelEvents.onboardingShown);
```
şununla değiştir:
```dart
    final analytics = ref.read(analyticsServiceProvider);
    analytics.track(FunnelEvents.onboardingShown);
    // PageView.onPageChanged ilk sayfa için ateşlenmez, dolayısıyla sayfa 0
    // bugüne kadar hiç ölçülmedi ve huni ancak onboarding_shown'dan çıkarım
    // yapılarak okunabiliyordu. Karşılaştırma metriği değişmiyor (§3):
    // öncesi/sonrası hâlâ page=1 / onboarding_shown üzerinden okunur.
    analytics.track(FunnelEvents.onboardingPageViewed, props: {'page': 0});
```

- [ ] **Step 6: Tüm onboarding testlerini çalıştır**

Run: `flutter test test/features/auth/onboarding_screen_test.dart`
Expected: PASS (5 test — mevcut 4 + yeni 1)

**Taşma olursa** (`renders on a 375x667 screen without overflowing` başarısız): sırayla uygula, her adımdan sonra testi tekrar çalıştır —
1. `maxHeight` çarpanını `0.5` → `0.42` yap.
2. `SizedBox(height: 24)` → `16`, `SizedBox(height: 12)` → `8`.
3. Hâlâ taşıyorsa `Column`'u `SingleChildScrollView` + `ConstrainedBox(minHeight: constraints.maxHeight)` + `IntrinsicHeight` sarmalına al.

- [ ] **Step 7: Analiz**

Run: `flutter analyze lib/features/auth/`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/auth/ test/features/auth/onboarding_screen_test.dart
git commit -m "feat(onboarding): sayfalari urun onizlemeleriyle degistir

Jenerik Material ikonlari yerine gercek widget'larla kurulmus onizlemeler.
Sayfa 0 artik uygulamanin gercekten acildigi modu (yemek fotografi)
anlatiyor; barkod 2. sayfaya alindi.

Ayrica sayfa 0 gorunumu artik olay olarak isaretleniyor - onPageChanged
ilk sayfa icin atesenmedigi icin bu adim hic olculmemisti."
```

---

### Task 5: Çapraz doğrulama, yetim anahtar temizliği ve tam süit

**Files:**
- Test: `test/features/auth/onboarding_screen_test.dart` (ekleme)
- Modify: `lib/l10n/app_tr.arb`, `app_en.arb`, `app_es.arb`, `app_pt.arb`, `app_ar.arb`, `app_zh.arb` (5 yetim anahtarın silinmesi)

**Interfaces:**
- Consumes: Task 4'ün tamamlanmış ekranı
- Produces: yok

- [ ] **Step 1: Tema ve RTL testlerini yaz**

`_pumpOnboarding`'in imzasına tema ve dil parametrelerini **ekle** — `uploader` parametresi Task 4'te eklenmişti, korunuyor:

```dart
Future<ProviderContainer> _pumpOnboarding(
  WidgetTester tester, {
  _RecordingUploader? uploader,
  ThemeData? theme,
  Locale locale = const Locale('tr'),
}) async {
```
ve `MaterialApp.router` içinde:
```dart
        theme: theme ?? AppTheme.light,
        locale: locale,
```

`main()` içine ekle:

```dart
  testWidgets('koyu temada 375x667 ekranda tasma yok', (tester) async {
    await _pumpOnboarding(tester, theme: AppTheme.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arapca (RTL) 375x667 ekranda tasma yok', (tester) async {
    // En uzun ceviriler ve ters yon duzeni birlikte en zorlu durum.
    await _pumpOnboarding(tester, locale: const Locale('ar'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uc sayfa da kaydirilarak gezilebilir', (tester) async {
    await _pumpOnboarding(tester);

    // Sayfa 0 -> 1
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Paketliyse barkodu okut.'), findsOneWidget);

    // Sayfa 1 -> 2
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Sana göre uyarı versin.'), findsOneWidget);
    // Son sayfada birincil eylem "Ucretsiz basla" olur.
    expect(find.text('Ücretsiz başla'), findsOneWidget);
  });
```

- [ ] **Step 2: Testleri çalıştır**

Run: `flutter test test/features/auth/onboarding_screen_test.dart`
Expected: PASS (8 test)

Taşma çıkarsa Task 4 Step 6'daki merdiveni uygula.

- [ ] **Step 3: Test kapsamını commit'le**

```bash
git add test/features/auth/onboarding_screen_test.dart
git commit -m "test(onboarding): koyu tema, RTL ve sayfa gezinme kapsamini ekle

375x667 tasma testi artik acik/koyu tema ve Arapca dahil kosuyor - yeni
sayfa 0 eskisinden uzun oldugu icin en gercek risk buydu."
```

- [ ] **Step 4: Yetim anahtarların gerçekten yetim olduğunu doğrula**

Ekran artık yeni anahtarları kullanıyor; eskilerin hiçbir çağrı noktası kalmamış olmalı. Generated dosyalar hariç tutuluyor çünkü onlar arb'den türetiliyor.

Run:
```bash
grep -rn "scanBarcodeDescription\|healthScoreTitle\|healthScoreDescription\|personalFilters" lib --include=*.dart | grep -v "/generated/"
```

Expected: **hiçbir çıktı yok** (çıkış kodu 1). Bir dosya listelenirse **dur** — o anahtar hâlâ kullanımda, silme listesinden çıkar.

> `scanBarcodeTitle` bu aramada yok ve **silinmiyor** — `food_result_screen.dart` kullanıyor.

- [ ] **Step 5: Beş yetim anahtarı 6 arb dosyasından sil**

Her dosyada şu beş satırı sil (`scanBarcodeTitle` satırına dokunma):
`scanBarcodeDescription`, `healthScoreTitle`, `healthScoreDescription`, `personalFilters`, `personalFiltersDescription`

Run: `flutter gen-l10n`
Expected: hatasız tamamlanır.

Doğrula — hiçbir dilde kalmamalı:
```bash
grep -rc "personalFiltersDescription" lib/l10n/*.arb
```
Expected: altı dosya için de `0`.

- [ ] **Step 6: Tüm test süitini ve analizi çalıştır**

Run: `flutter test`
Expected: Tüm testler PASS.

Not: Depoda önceden bilinen 2 başarısız test olabilir (`anthropic_ai_service_test.dart` porsiyon tavanı 100 vs 350 — bkz. `wiki/04-problems-open.md` "Porsiyon tavanı testi stale"). Bunlar bu planla ilgisizdir; **düzeltilmez, dokunulmaz**. Başka bir başarısızlık çıkarsa bu planın regresyonudur ve düzeltilmelidir.

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/l10n/
git commit -m "chore(l10n): onboarding'in birakti 5 yetim anahtari sil

Ekran yeni anahtarlara gectikten sonra bu besinin baska cagri noktasi
kalmadi. scanBarcodeTitle korundu - food_result_screen kullaniyor."
```

---

## Uygulama sonrası

Kod tarafı bitince — bu plan dışında, sırayla:

1. **Sürümü yükselt ve yayınla.** `pubspec.yaml` şu an `1.2.2+12` (enstrümantasyon yaması için yükseltilmişti). Onboarding değişikliği de aynı sürüme giriyorsa ek yükseltme gerekmez.
2. **Ölçümü oku** (yayından ~4 gün sonra): hedef `page=1 / onboarding_shown ≥ %80` (bugün %66). Kohort bazlı bak, tüm zaman ortalamasıyla değil:
   ```sql
   select date(min_ts) as cohort, count(*) filter (where saw_p1) * 100.0 / count(*) as pct
   from (
     select device_hash, min(received_at) as min_ts,
            bool_or(event='onboarding_page_viewed' and props->>'page'='1') as saw_p1
     from analytics_events
     where platform='android' and event in ('onboarding_shown','onboarding_page_viewed')
     group by device_hash
   ) d group by 1 order by 1;
   ```
3. **Koruma metriğini kontrol et:** `(onboarding_completed + onboarding_skipped) / onboarding_shown` %61'in altına düşmemeli.
4. **Vault'u güncelle:** `wiki/02-decisions-log.md` (karar + sonuç), `wiki/04-problems-open.md` (huni maddesi).
