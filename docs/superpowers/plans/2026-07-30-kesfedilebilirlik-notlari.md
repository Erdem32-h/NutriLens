# Keşfedilebilirlik Notları Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kıyaslama ve topluluk-ürün-kaydı özelliklerini üç küçük UI notuyla keşfedilebilir yapmak (spec: `docs/superpowers/specs/2026-07-30-kesfedilebilirlik-notlari-design.md`).

**Architecture:** Tek seferlik kapatılabilir ipucu şeridi (`CompareHintStrip`, SharedPreferences flag + Riverpod `Provider<bool>`), ALTERNATİF sekmesinde kalıcı caption, `addProductIntro` metin güncellemesi. Yeni ekran/route/bağımlılık yok.

**Tech Stack:** Flutter, Riverpod 3 (`Provider` ana pakette — `legacy.dart` GEREKMEZ, yalnızca `StateProvider` için gerekirdi), shared_preferences, flutter gen-l10n (template: `app_tr.arb`).

## Global Constraints

- 6 dil: `app_tr.arb` (template), `app_en.arb`, `app_es.arb`, `app_pt.arb`, `app_ar.arb`, `app_zh.arb` — hepsi `lib/l10n/` altında. Bir anahtar 6 dosyanın 6'sına da girer.
- Arb dosyalarında `@`-metadata kullanılmıyor — düz `"anahtar": "değer"` satırı, mevcut dosya stiline uy.
- Metinler bu plandaki tablodan **birebir** kopyalanır (çeviriler onaylı kabul edilir; doğaçlama yok).
- `context.colors` kullanan her widget testi `MaterialApp(theme: AppTheme.light, ...)` ister — temasız `MaterialApp`, `app_colors.dart:311-320`'deki debug assert'i tetikler ve testi çökertir.
- Widget testlerinde `SharedPreferences.setMockInitialValues(...)` + `sharedPreferencesProvider.overrideWithValue(...)` (bkz. `test/core/session/app_session_test.dart` pattern'i).
- Commit mesajları conventional commits (`feat:`, `test:`, `docs:`); attribution yok.
- Her task sonunda `flutter analyze` temiz olmalı.

## Onaylı metin tablosu (tek kaynak)

Sekme adı TR'de "ALTERNATİF", diğer 5 dilde "ALTERNATIVE" (arb'lerde `tabAlternative` böyle) — şerit metinleri sekmeye bu adlarla atıf yapar.

**`compareHintStrip`** (yeni):
| dil | değer |
|---|---|
| tr | `İpucu: İki ürünü yan yana kıyaslayabilirsin — ALTERNATİF sekmesine bak.` |
| en | `Tip: You can compare two products side by side — see the ALTERNATIVE tab.` |
| es | `Consejo: puedes comparar dos productos lado a lado; entra en la pestaña ALTERNATIVE.` |
| pt | `Dica: você pode comparar dois produtos lado a lado — veja a aba ALTERNATIVE.` |
| ar | `نصيحة: يمكنك مقارنة منتجين جنبًا إلى جنب — انظر تبويب ALTERNATIVE.` |
| zh | `提示：可以并排对比两款产品——请查看 ALTERNATIVE 标签页。` |

**`compareCaption`** (yeni):
| dil | değer |
|---|---|
| tr | `İki ürünün besin değerlerini, katkılarını ve skorlarını yan yana gör.` |
| en | `See two products' nutrition, additives, and scores side by side.` |
| es | `Compara los valores nutricionales, aditivos y puntuaciones de dos productos lado a lado.` |
| pt | `Veja os valores nutricionais, aditivos e pontuações de dois produtos lado a lado.` |
| ar | `اعرض القيم الغذائية والمضافات والدرجات لمنتجين جنبًا إلى جنب.` |
| zh | `并排查看两款产品的营养成分、添加剂和评分。` |

**`compareHintDismiss`** (yeni — X butonunun erişilebilirlik/tooltip etiketi):
| dil | değer |
|---|---|
| tr | `Kapat` |
| en | `Dismiss` |
| es | `Cerrar` |
| pt | `Fechar` |
| ar | `إغلاق` |
| zh | `关闭` |

**`addProductIntro`** (GÜNCELLEME — anahtar 6 dosyada da zaten var, yalnızca değer değişir; eski değerdeki `\n` yeni değerde YOK):
| dil | değer |
|---|---|
| tr | `Bu ürün henüz veritabanımızda yok. Bir kez kaydetmen yeterli — sonraki taramalarda anında açılır, diğer kullanıcılar da yararlanır.` |
| en | `This product isn't in our database yet. Add it once and you're done — future scans open it instantly, and other users benefit too.` |
| es | `Este producto aún no está en nuestra base de datos. Regístralo una sola vez: los próximos escaneos lo abrirán al instante y otros usuarios también se beneficiarán.` |
| pt | `Este produto ainda não está no nosso banco de dados. Cadastre-o uma única vez — as próximas leituras o abrirão na hora e outros usuários também se beneficiam.` |
| ar | `هذا المنتج غير موجود في قاعدة بياناتنا بعد. يكفي تسجيله مرة واحدة — سيفتح فورًا في عمليات المسح القادمة ويستفيد منه المستخدمون الآخرون أيضًا.` |
| zh | `该产品尚未收录到我们的数据库。只需登记一次——之后扫描即可立即打开，其他用户也能受益。` |

---

### Task 1: l10n anahtarları (3 yeni + 1 güncelleme × 6 dil)

**Files:**
- Modify: `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`, `lib/l10n/app_pt.arb`, `lib/l10n/app_ar.arb`, `lib/l10n/app_zh.arb`

**Interfaces:**
- Consumes: —
- Produces: `context.l10n.compareHintStrip`, `context.l10n.compareCaption`, `context.l10n.compareHintDismiss` (String getter'lar) + güncellenmiş `context.l10n.addProductIntro`. Sonraki task'lar bu getter'ları kullanır.

- [ ] **Step 1: 6 arb dosyasına 3 yeni anahtarı ekle**

Her dosyada `"comparePickerEmpty"` satırının HEMEN ALTINA (satır ~231, kıyas anahtarları bir arada kalsın), yukarıdaki tablodan o dilin değerleriyle:

```json
  "comparePickerEmpty": "<mevcut değer — dokunma>",
  "compareHintStrip": "<tablodan bu dilin değeri>",
  "compareCaption": "<tablodan bu dilin değeri>",
  "compareHintDismiss": "<tablodan bu dilin değeri>",
```

- [ ] **Step 2: 6 arb dosyasında `addProductIntro` değerini değiştir**

Anahtar 6 dosyada da mevcut (tr'de satır ~557). Yalnızca değeri tablodaki yeni metinle değiştir — eski değerdeki `\n` kaçışı yeni metinde yok.

- [ ] **Step 3: Kod üret ve doğrula**

Run: `flutter gen-l10n`
Expected: hatasız; `lib/l10n/generated/app_localizations.dart` içinde `compareHintStrip` getter'ı oluşur (6 dil dosyasının hepsinde `String get compareHintStrip`).

- [ ] **Step 4: Suite hâlâ yeşil mi**

Run: `flutter analyze && flutter test`
Expected: analyze temiz, tüm testler geçer (hiçbir test `addProductIntro`'nun eski metnine exact-match assert etmiyor — 2026-07-30'da tarandı).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/
git commit -m "feat(l10n): kesfedilebilirlik notu anahtarlari (compareHintStrip/Caption/Dismiss) + addProductIntro tek-seferlik-kayit vurgusu"
```

---

### Task 2: `compareHintDismissedProvider` + prefs sabiti + `dismissCompareHint`

**Files:**
- Create: `lib/features/product/presentation/providers/compare_hint_provider.dart`
- Test: `test/features/product/presentation/compare_hint_provider_test.dart`

**Interfaces:**
- Consumes: `sharedPreferencesProvider` (`lib/core/providers/locale_provider.dart` — override edilmemişse `UnimplementedError` fırlatır, bu KASITLI; `main()` yalnızca prefs başarıyla açıldıysa override eder).
- Produces: `const String kCompareHintDismissedKey = 'compare_hint_dismissed'`; `final compareHintDismissedProvider = Provider<bool>` (true → şerit gizli); `Future<void> dismissCompareHint(WidgetRef ref)`. Task 3 üçünü de kullanır.

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/product/presentation/compare_hint_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/features/product/presentation/providers/compare_hint_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> containerWith({
  Map<String, Object> prefs = const {},
  bool withPreferences = true,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      if (withPreferences)
        sharedPreferencesProvider.overrideWithValue(instance),
    ],
  );
}

void main() {
  test('taze kurulumda false döner (şerit görünür)', () async {
    final container = await containerWith();
    addTearDown(container.dispose);
    expect(container.read(compareHintDismissedProvider), isFalse);
  });

  test('flag yazılmışsa true döner (şerit gizli)', () async {
    final container =
        await containerWith(prefs: {kCompareHintDismissedKey: true});
    addTearDown(container.dispose);
    expect(container.read(compareHintDismissedProvider), isTrue);
  });

  test('prefs erişilemezse true döner (savunmacı: ipucu gösterilmez)',
      () async {
    final container = await containerWith(withPreferences: false);
    addTearDown(container.dispose);
    expect(container.read(compareHintDismissedProvider), isTrue);
  });
}
```

- [ ] **Step 2: Testlerin FAIL ettiğini gör**

Run: `flutter test test/features/product/presentation/compare_hint_provider_test.dart`
Expected: FAIL — `compare_hint_provider.dart` yok (URI does not exist).

- [ ] **Step 3: Provider dosyasını yaz**

`lib/features/product/presentation/providers/compare_hint_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/locale_provider.dart';

/// Yazıldıktan sonra kıyas ipucu şeridi bir daha hiç gösterilmez.
const String kCompareHintDismissedKey = 'compare_hint_dismissed';

/// true → şerit gizli. Prefs erişilemiyorsa da true: bozuk bir prefs
/// eklentisi kullanıcıyı her açılışta aynı ipucuyla rahatsız etmesin
/// (kOnboardingSeenKey'in savunmacı varsayılanıyla aynı gerekçe, ters yön —
/// bkz. app_session.dart `_prefsOrNull`).
final compareHintDismissedProvider = Provider<bool>((ref) {
  try {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(kCompareHintDismissedKey) ?? false;
  } catch (_) {
    return true;
  }
});

/// X butonunun aksiyonu: flag'i kalıcı yaz, provider'ı tazele.
/// Prefs yoksa yazma sessizce atlanır — provider o durumda zaten true
/// döndüğü için şerit ekranda değildir, buraya normalde gelinmez.
Future<void> dismissCompareHint(WidgetRef ref) async {
  try {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(kCompareHintDismissedKey, true);
  } catch (_) {}
  ref.invalidate(compareHintDismissedProvider);
}
```

Not: `Provider` Riverpod 3'te ana pakette (`flutter_riverpod.dart`) — `legacy.dart` import ETME (o yalnızca `StateProvider` için gerekir).

- [ ] **Step 4: Testler PASS**

Run: `flutter test test/features/product/presentation/compare_hint_provider_test.dart`
Expected: 3/3 PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/product/presentation/providers/compare_hint_provider.dart test/features/product/presentation/compare_hint_provider_test.dart
git commit -m "feat(product): compareHintDismissedProvider - tek seferlik kiyas ipucu flag'i"
```

---

### Task 3: `CompareHintStrip` widget'ı

**Files:**
- Create: `lib/features/product/presentation/widgets/compare_hint_strip.dart`
- Test: `test/features/product/presentation/widgets/compare_hint_strip_test.dart`

**Interfaces:**
- Consumes: `compareHintDismissedProvider`, `dismissCompareHint(ref)`, `kCompareHintDismissedKey` (Task 2); `context.l10n.compareHintStrip` / `.compareHintDismiss` (Task 1); `context.colors` (`core/theme/app_colors.dart`).
- Produces: `class CompareHintStrip extends ConsumerWidget` — parametresiz `const CompareHintStrip()`. Task 4 bunu ekrana yerleştirir.

- [ ] **Step 1: Başarısız widget testlerini yaz**

`test/features/product/presentation/widgets/compare_hint_strip_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/product/presentation/providers/compare_hint_provider.dart';
import 'package:nutrilens/features/product/presentation/widgets/compare_hint_strip.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget wrap({SharedPreferences? prefs}) => ProviderScope(
      overrides: [
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        // context.colors, AppColorsExtension'sız temada debug assert
        // fırlatır (app_colors.dart:311-320) — theme şart.
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('tr'),
        home: const Scaffold(body: CompareHintStrip()),
      ),
    );

void main() {
  testWidgets('taze kurulumda görünür; X flag yazar ve şeridi gizler',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(wrap(prefs: prefs));
    await tester.pumpAndSettle();
    expect(
      find.text(
          'İpucu: İki ürünü yan yana kıyaslayabilirsin — ALTERNATİF sekmesine bak.'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(prefs.getBool(kCompareHintDismissedKey), isTrue);
  });

  testWidgets('flag daha önce yazılmışsa hiç render olmaz', (tester) async {
    SharedPreferences.setMockInitialValues({kCompareHintDismissedKey: true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(wrap(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(find.byIcon(Icons.compare_arrows_rounded), findsNothing);
  });

  testWidgets('prefs erişilemezse hiç render olmaz (savunmacı)',
      (tester) async {
    // Override yok → sharedPreferencesProvider UnimplementedError fırlatır,
    // provider bunu yakalayıp true (gizli) döner.
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });
}
```

- [ ] **Step 2: Testlerin FAIL ettiğini gör**

Run: `flutter test test/features/product/presentation/widgets/compare_hint_strip_test.dart`
Expected: FAIL — `compare_hint_strip.dart` yok.

- [ ] **Step 3: Widget'ı yaz**

`lib/features/product/presentation/widgets/compare_hint_strip.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/compare_hint_provider.dart';

/// Tek seferlik keşfedilebilirlik şeridi: kıyaslama özelliğinin varlığını
/// ve yerini (ALTERNATİF sekmesi) söyler. X'e basılınca cihazda kalıcı
/// olarak kapanır; otomatik kaybolmaz (spec 2.1).
class CompareHintStrip extends ConsumerWidget {
  const CompareHintStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(compareHintDismissedProvider);
    if (dismissed) return const SizedBox.shrink();

    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.compare_arrows_rounded,
            size: 18,
            color: colors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.compareHintStrip,
              style: TextStyle(fontSize: 12.5, color: colors.textMuted),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: colors.textMuted,
            tooltip: context.l10n.compareHintDismiss,
            visualDensity: VisualDensity.compact,
            onPressed: () => dismissCompareHint(ref),
          ),
        ],
      ),
    );
  }
}
```

RTL notu: `Row` + `EdgeInsets.fromLTRB` Arapça'da otomatik aynalanmaz ama
kenar boşlukları simetrik olduğundan (24/24) görsel sorun yaratmaz; ikonlar
yön bağımsız. Ek işlem gerekmez.

- [ ] **Step 4: Testler PASS**

Run: `flutter test test/features/product/presentation/widgets/compare_hint_strip_test.dart`
Expected: 3/3 PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/product/presentation/widgets/compare_hint_strip.dart test/features/product/presentation/widgets/compare_hint_strip_test.dart
git commit -m "feat(product): CompareHintStrip - kapatilabilir kiyas ipucu seridi"
```

---

### Task 4: ProductDetailScreen entegrasyonu (şerit + caption)

**Files:**
- Modify: `lib/features/product/presentation/screens/product_detail_screen.dart` (iki nokta: ~satır 337-341 `PillTabBar` bloğu; ~satır 560-571 `_buildAlternativeTab` içindeki Kıyasla butonu)

**Interfaces:**
- Consumes: `CompareHintStrip` (Task 3), `context.l10n.compareCaption` (Task 1).
- Produces: — (uç entegrasyon; Task 5 canlı doğrular).

Not: Bu ekran için widget testi KASITLI olarak yok — `ProductDetailScreen`
ağır provider zinciri ister (productByBarcode, blacklist, counterfeit,
analytics...); şeridin tüm davranışı Task 3'te bağımsız test edildi, caption
statik metin. Entegrasyon Task 5'te emülatörde görsel doğrulanır
(live-device-verification dersi gereği bu adım atlanamaz).

- [ ] **Step 1: Şeridi PillTabBar'ın hemen altına ekle**

`product_detail_screen.dart` dosyasının başına import ekle (mevcut
`../widgets/alternative_placeholder.dart` importunun yanına):

```dart
import '../widgets/compare_hint_strip.dart';
```

`_buildProductDetail` içinde (~satır 337) mevcut blok:

```dart
          PillTabBar(
            selectedIndex: _selectedTab,
            onTabChanged: (i) => setState(() => _selectedTab = i),
          ),
          const SizedBox(height: 16),
```

şöyle olacak:

```dart
          PillTabBar(
            selectedIndex: _selectedTab,
            onTabChanged: (i) => setState(() => _selectedTab = i),
          ),
          const CompareHintStrip(),
          const SizedBox(height: 16),
```

- [ ] **Step 2: Kıyasla butonunun altına caption ekle**

`_buildAlternativeTab` içinde (~satır 560) mevcut blok:

```dart
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
```

şu bloğun eklenmesiyle devam edecek (butonun Padding'inin HEMEN ARDINA,
`// "Did you know?" tip card` yorumundan ÖNCE):

```dart
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: Text(
          context.l10n.compareCaption,
          style: TextStyle(fontSize: 12.5, color: context.colors.textMuted),
        ),
      ),
```

- [ ] **Step 3: Analyze + tam suite**

Run: `flutter analyze && flutter test`
Expected: analyze temiz, tüm testler geçer.

- [ ] **Step 4: Commit**

```bash
git add lib/features/product/presentation/screens/product_detail_screen.dart
git commit -m "feat(product): urun detayina kiyas ipucu seridi + ALTERNATIF sekmesine kiyas aciklamasi"
```

---

### Task 5: Canlı emülatör doğrulaması (zorunlu)

**Files:**
- Test: yok — görsel doğrulama + ekran görüntüleri

**Interfaces:**
- Consumes: Task 1-4'ün tamamı, cihazda.
- Produces: 3 notun ekran görüntüsüyle teyidi; başarı kriterinin kapanışı.

Gerekçe: kalori grafiğinde tüm widget testleri yeşilken segmentler gerçek
cihazda görünmezdi (`ColoredBox` sıfır-genişlik) — görsel işler emülatörde
görülmeden bitmiş sayılmaz.

- [ ] **Step 1: Emülatörü başlat ve uygulamayı kur**

`Pixel_8_Pro_API_34` AVD'si bu makinede sorunsuz (Pixel_8_API_34 adb
"unauthorized" hatası veriyor — ona zaman harcama, direkt Pro'yu kullan):

```bash
flutter emulators --launch Pixel_8_Pro_API_34
flutter run -d emulator-5554 --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

(dart-define değerleri `.env`'den; `scripts/build_android_release.ps1`
hangi anahtarları geçtiğini gösterir. Debug'da Sentry DSN'siz olması normal.)

- [ ] **Step 2: Şeridi doğrula (taze kurulum)**

Tarayıcıda manuel barkod girişiyle bilinen bir ürün aç (örn. `3017620422003`
— Nutella, OFF'ta kesin var; ya da geçmişteki herhangi bir ürün):
- Ürün detayında sekme çubuğunun altında ipucu şeridi görünüyor mu?
- Ekran görüntüsü al: `adb exec-out screencap -p > strip_visible.png` — bak.

- [ ] **Step 3: X'i ve kalıcılığı doğrula**

- X'e bas → şerit anında kayboluyor mu?
- Uygulamayı tamamen kapat (`adb shell am force-stop <package>`) ve yeniden
  aç, aynı ürünü aç → şerit GELMEMELİ. Ekran görüntüsüyle teyit.

- [ ] **Step 4: ALTERNATİF caption'ını doğrula**

ALTERNATİF sekmesine geç → Kıyasla butonunun altında caption okunaklı mı?
Ekran görüntüsü al.

- [ ] **Step 5: Not-found intro'sunu doğrula**

Manuel barkod girişine rastgele 13 hane gir (örn. `8699999999998`) →
ürün-bulunamadı ekranında yeni "bir kez kaydetmen yeterli" metni görünüyor
mu? Metin taşma/kırpılma yok mu? Ekran görüntüsü al.

- [ ] **Step 6: Dil spot-check**

Profil → dil → English yap, aynı üç yeri hızla kontrol et (metinler EN
gelmeli, "ALTERNATIVE" atfı sekme adıyla eşleşmeli). Geri TR'ye al.

- [ ] **Step 7: Kapanış**

Sorun bulunduysa düzelt (düzeltme + varsa regresyon testi ayrı commit),
bulunmadıysa iş bitti — vault sprint dosyasına tek satır işaret koy
(`03-current-sprint.md` 1.2.2 bölümüne "keşfedilebilirlik notları dahil").
