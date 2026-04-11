import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/core/providers/monetization_provider.dart';
import 'package:nutrilens/core/services/subscription_service.dart';
import 'package:nutrilens/core/theme/app_colors.dart';
import 'package:nutrilens/features/premium/presentation/screens/paywall_screen.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class MockSubscriptionService extends Mock implements SubscriptionService {}

class MockPackage extends Mock implements Package {}

class MockStoreProduct extends Mock implements StoreProduct {}

Widget _buildSubject({required SubscriptionService service}) {
  return ProviderScope(
    overrides: [
      subscriptionServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp(
      theme: ThemeData(
        extensions: const [AppColorsExtension.light],
      ),
      home: const PaywallScreen(),
    ),
  );
}

void main() {
  late MockSubscriptionService mockService;

  setUp(() {
    mockService = MockSubscriptionService();
    when(() => mockService.statusStream).thenAnswer((_) => const Stream.empty());
  });

  group('PaywallScreen', () {
    testWidgets('shows loading indicator while fetching offerings', (tester) async {
      // Use Completer to avoid a pending timer that would fail the test
      final completer = Completer<List<Package>>();
      when(() => mockService.getOfferings()).thenAnswer((_) => completer.future);

      await tester.pumpWidget(_buildSubject(service: mockService));
      await tester.pump(); // Render the initial frame (loading = true)

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete so the widget tree can settle without pending futures
      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('renders premium feature tiles after loading empty offerings',
        (tester) async {
      when(() => mockService.getOfferings()).thenAnswer((_) async => []);

      await tester.pumpWidget(_buildSubject(service: mockService));
      await tester.pumpAndSettle();

      expect(find.text('NutriLens Premium'), findsOneWidget);
      expect(find.text('Sınırsız tarama'), findsOneWidget);
      expect(find.text('Reklamsız deneyim'), findsOneWidget);
      expect(find.text('Sınırsız AI tarama'), findsOneWidget);
      expect(find.text('Öncelikli destek'), findsOneWidget);
    });

    testWidgets('shows Devam Et button after offerings load', (tester) async {
      when(() => mockService.getOfferings()).thenAnswer((_) async => []);

      await tester.pumpWidget(_buildSubject(service: mockService));
      await tester.pumpAndSettle();

      expect(find.text('Devam Et'), findsOneWidget);
    });

    testWidgets('shows Geri Yükle button in app bar', (tester) async {
      when(() => mockService.getOfferings()).thenAnswer((_) async => []);

      await tester.pumpWidget(_buildSubject(service: mockService));
      await tester.pumpAndSettle();

      expect(find.text('Geri Yükle'), findsOneWidget);
    });

    testWidgets('shows legal disclaimer text', (tester) async {
      when(() => mockService.getOfferings()).thenAnswer((_) async => []);

      await tester.pumpWidget(_buildSubject(service: mockService));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Abonelik otomatik yenilenir'),
        findsOneWidget,
      );
    });

    testWidgets('renders package cards for each offering', (tester) async {
      final mockMonthly = MockPackage();
      final mockAnnual = MockPackage();
      final mockMonthlyProduct = MockStoreProduct();
      final mockAnnualProduct = MockStoreProduct();

      when(() => mockMonthly.packageType).thenReturn(PackageType.monthly);
      when(() => mockMonthly.storeProduct).thenReturn(mockMonthlyProduct);
      when(() => mockMonthlyProduct.priceString).thenReturn('₺49,99/ay');

      when(() => mockAnnual.packageType).thenReturn(PackageType.annual);
      when(() => mockAnnual.storeProduct).thenReturn(mockAnnualProduct);
      when(() => mockAnnualProduct.priceString).thenReturn('₺359,99/yıl');

      when(() => mockService.getOfferings())
          .thenAnswer((_) async => [mockMonthly, mockAnnual]);

      await tester.pumpWidget(_buildSubject(service: mockService));
      await tester.pumpAndSettle();

      expect(find.text('Aylık'), findsOneWidget);
      expect(find.text('Yıllık'), findsOneWidget);
      expect(find.text('₺49,99/ay'), findsOneWidget);
      expect(find.text('₺359,99/yıl'), findsOneWidget);
      expect(find.text('%40 tasarruf'), findsOneWidget);
    });

    testWidgets('shows success snackbar and pops on successful purchase',
        (tester) async {
      final mockPackage = MockPackage();
      final mockProduct = MockStoreProduct();

      when(() => mockPackage.packageType).thenReturn(PackageType.monthly);
      when(() => mockPackage.storeProduct).thenReturn(mockProduct);
      when(() => mockProduct.priceString).thenReturn('₺49,99/ay');
      when(() => mockService.getOfferings())
          .thenAnswer((_) async => [mockPackage]);
      when(() => mockService.purchase(mockPackage))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(_buildSubject(service: mockService));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Devam Et'));
      // pump() processes microtasks (future completion) without running the
      // SnackBar's 4-second auto-dismiss timer. pumpAndSettle() would run
      // that timer and dismiss the SnackBar before we can assert it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Premium aktif! 🎉'), findsOneWidget);
    });

    testWidgets('does not pop on failed purchase', (tester) async {
      final mockPackage = MockPackage();
      final mockProduct = MockStoreProduct();

      when(() => mockPackage.packageType).thenReturn(PackageType.monthly);
      when(() => mockPackage.storeProduct).thenReturn(mockProduct);
      when(() => mockProduct.priceString).thenReturn('₺49,99/ay');
      when(() => mockService.getOfferings())
          .thenAnswer((_) async => [mockPackage]);
      when(() => mockService.purchase(mockPackage))
          .thenAnswer((_) async => false);

      await tester.pumpWidget(_buildSubject(service: mockService));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Devam Et'));
      await tester.pumpAndSettle();

      // Screen should still be visible (not popped)
      expect(find.text('NutriLens Premium'), findsOneWidget);
    });

    testWidgets('restore shows success snackbar when subscription found',
        (tester) async {
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

    testWidgets('restore shows failure snackbar when no subscription found',
        (tester) async {
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
