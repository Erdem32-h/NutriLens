import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/core/providers/monetization_provider.dart';
import 'package:nutrilens/core/services/subscription_service.dart';
import 'package:nutrilens/core/theme/app_colors.dart';
import 'package:nutrilens/features/premium/presentation/screens/paywall_screen.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class MockSubscriptionService extends Mock implements SubscriptionService {}

class MockPackage extends Mock implements Package {}

class MockStoreProduct extends Mock implements StoreProduct {}

MockPackage _mockPackage({
  PackageType type = PackageType.monthly,
  String priceString = '₺49,99',
  String pricePerMonth = '₺49,99',
  double price = 49.99,
}) {
  final package = MockPackage();
  final product = MockStoreProduct();
  when(() => package.packageType).thenReturn(type);
  when(() => package.storeProduct).thenReturn(product);
  when(() => product.priceString).thenReturn(priceString);
  when(() => product.pricePerMonthString).thenReturn(pricePerMonth);
  when(() => product.price).thenReturn(price);
  // No free trial / intro offer by default.
  when(() => product.introductoryPrice).thenReturn(null);
  when(() => product.defaultOption).thenReturn(null);
  return package;
}

Widget _buildSubject({required SubscriptionService service}) {
  return ProviderScope(
    overrides: [subscriptionServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      // Force Turkish so the TR assertions below hold; production strings
      // are localized via AppLocalizations.
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(extensions: const [AppColorsExtension.light]),
      home: const PaywallScreen(),
    ),
  );
}

void main() {
  late MockSubscriptionService mockService;

  setUp(() {
    mockService = MockSubscriptionService();
    when(
      () => mockService.statusStream,
    ).thenAnswer((_) => const Stream.empty());
  });

  group('PaywallScreen', () {
    testWidgets('shows loading indicator while fetching offerings', (
      tester,
    ) async {
      // Use Completer to avoid a pending timer that would fail the test
      final completer = Completer<List<Package>>();
      when(
        () => mockService.getOfferings(),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(_buildSubject(service: mockService));
      await tester.pump(); // Render the initial frame (loading = true)

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete so the widget tree can settle without pending futures
      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('renders error state after loading empty offerings', (
      tester,
    ) async {
      when(() => mockService.getOfferings()).thenAnswer((_) async => []);

      await tester.pumpWidget(_buildSubject(service: mockService));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Abonelik paketleri yüklenemedi'),
        findsOneWidget,
      );
      expect(find.text('Tekrar Dene'), findsOneWidget);
    });

    testWidgets('shows the purchase CTA after offerings load', (tester) async {
      when(
        () => mockService.getOfferings(),
      ).thenAnswer((_) async => [_mockPackage()]);

      await tester.pumpWidget(_buildSubject(service: mockService));
      await tester.pumpAndSettle();

      // No free trial configured → continue CTA.
      expect(find.text("Premium'a Geç"), findsOneWidget);
    });

    testWidgets('shows Geri Yükle button in app bar', (tester) async {
      when(() => mockService.getOfferings()).thenAnswer((_) async => []);

      await tester.pumpWidget(_buildSubject(service: mockService));
      await tester.pumpAndSettle();

      expect(find.text('Geri Yükle'), findsOneWidget);
    });

    testWidgets('shows legal disclaimer text', (tester) async {
      when(
        () => mockService.getOfferings(),
      ).thenAnswer((_) async => [_mockPackage()]);

      await tester.pumpWidget(_buildSubject(service: mockService));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Abonelik otomatik yenilenir'),
        findsOneWidget,
      );
      expect(find.text('Gizlilik Politikası'), findsOneWidget);
      expect(find.text('Kullanım Koşulları'), findsOneWidget);
    });

    testWidgets('renders package cards with per-month price and real savings', (
      tester,
    ) async {
      final mockMonthly = _mockPackage();
      // Annual at ₺359,99/yr vs ₺49,99/mo*12 = ₺599,88 → ~40% saving.
      final mockAnnual = _mockPackage(
        type: PackageType.annual,
        priceString: '₺359,99',
        pricePerMonth: '₺30,00',
        price: 359.99,
      );

      when(
        () => mockService.getOfferings(),
      ).thenAnswer((_) async => [mockMonthly, mockAnnual]);

      await tester.pumpWidget(_buildSubject(service: mockService));
      await tester.pumpAndSettle();

      expect(find.text('Aylık'), findsOneWidget);
      expect(find.text('Yıllık'), findsOneWidget);
      expect(find.text('₺49,99/ay'), findsOneWidget); // monthly per-month
      expect(find.text('₺30,00/ay'), findsOneWidget); // annual per-month
      expect(find.textContaining('₺359,99'), findsOneWidget); // billed annually
      expect(find.text('%40 tasarruf'), findsOneWidget); // computed, not hardcoded
    });

    testWidgets('shows success snackbar and pops on successful purchase', (
      tester,
    ) async {
      final mockPackage = _mockPackage();
      when(
        () => mockService.getOfferings(),
      ).thenAnswer((_) async => [mockPackage]);
      when(
        () => mockService.purchase(mockPackage),
      ).thenAnswer((_) async => SubscriptionPurchaseResult.success);

      await tester.pumpWidget(_buildSubject(service: mockService));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Premium'a Geç"));
      // pump() processes microtasks (future completion) without running the
      // SnackBar's 4-second auto-dismiss timer. pumpAndSettle() would run
      // that timer and dismiss the SnackBar before we can assert it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Premium aktif! 🎉'), findsOneWidget);
    });

    testWidgets('does not pop on failed purchase', (tester) async {
      final mockPackage = _mockPackage();
      when(
        () => mockService.getOfferings(),
      ).thenAnswer((_) async => [mockPackage]);
      when(
        () => mockService.purchase(mockPackage),
      ).thenAnswer((_) async => SubscriptionPurchaseResult.failed);

      await tester.pumpWidget(_buildSubject(service: mockService));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Premium'a Geç"));
      await tester.pumpAndSettle();

      // Screen should still be visible (not popped)
      expect(find.text('NutriLens Premium'), findsWidgets);
    });

    testWidgets('restore shows success snackbar when subscription found', (
      tester,
    ) async {
      when(() => mockService.getOfferings()).thenAnswer((_) async => []);
      when(() => mockService.restorePurchases()).thenAnswer((_) async => true);

      await tester.pumpWidget(_buildSubject(service: mockService));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Geri Yükle'));
      // pump without pumpAndSettle to check SnackBar before it auto-dismisses
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Abonelik geri yüklendi!'), findsOneWidget);
    });

    testWidgets('restore shows failure snackbar when no subscription found', (
      tester,
    ) async {
      when(() => mockService.getOfferings()).thenAnswer((_) async => []);
      when(() => mockService.restorePurchases()).thenAnswer((_) async => false);

      await tester.pumpWidget(_buildSubject(service: mockService));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Geri Yükle'));
      await tester.pumpAndSettle();

      expect(find.text('Aktif abonelik bulunamadı.'), findsOneWidget);
    });
  });
}
