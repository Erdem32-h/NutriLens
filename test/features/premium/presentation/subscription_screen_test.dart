import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/core/providers/monetization_provider.dart';
import 'package:nutrilens/core/services/subscription_service.dart';
import 'package:nutrilens/core/theme/app_colors.dart';
import 'package:nutrilens/features/premium/presentation/screens/subscription_screen.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class MockSubscriptionService extends Mock implements SubscriptionService {}

class MockPackage extends Mock implements Package {}

class MockStoreProduct extends Mock implements StoreProduct {}

MockPackage _mockPackage({
  required String identifier,
  PackageType type = PackageType.monthly,
  String priceString = '₺49,99',
  String pricePerMonth = '₺49,99',
  double price = 49.99,
}) {
  final package = MockPackage();
  final product = MockStoreProduct();
  when(() => package.packageType).thenReturn(type);
  when(() => package.storeProduct).thenReturn(product);
  when(() => product.identifier).thenReturn(identifier);
  when(() => product.priceString).thenReturn(priceString);
  when(() => product.pricePerMonthString).thenReturn(pricePerMonth);
  when(() => product.price).thenReturn(price);
  when(() => product.introductoryPrice).thenReturn(null);
  when(() => product.defaultOption).thenReturn(null);
  return package;
}

MockPackage _monthly() => _mockPackage(identifier: 'nutrilens_monthly');

/// Annual at ₺359,99/yr vs ₺49,99/mo × 12 = ₺599,88 → ~40% saving.
MockPackage _annual() => _mockPackage(
  identifier: 'nutrilens_annual',
  type: PackageType.annual,
  priceString: '₺359,99',
  pricePerMonth: '₺30,00',
  price: 359.99,
);

Widget _subject({
  required SubscriptionService service,
  required bool isPremium,
}) {
  return ProviderScope(
    overrides: [
      subscriptionServiceProvider.overrideWithValue(service),
      // Overridden rather than exercised: the real provider reaches into
      // Supabase and the auth session, neither of which this screen's
      // behaviour depends on.
      isPremiumProvider.overrideWithValue(isPremium),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(extensions: const [AppColorsExtension.light]),
      home: const SubscriptionScreen(),
    ),
  );
}

void main() {
  late MockSubscriptionService service;

  setUpAll(() {
    registerFallbackValue(MockPackage());
  });

  setUp(() {
    service = MockSubscriptionService();
    when(() => service.statusStream).thenAnswer((_) => const Stream.empty());
  });

  void givenStatus(SubscriptionStatus status, {List<Package>? packages}) {
    when(() => service.getStatus()).thenAnswer((_) async => status);
    when(
      () => service.getOfferings(),
    ).thenAnswer((_) async => packages ?? [_monthly(), _annual()]);
  }

  group('an active monthly subscriber', () {
    final status = SubscriptionStatus(
      tier: SubscriptionTier.premium,
      productId: 'nutrilens_monthly',
      willRenew: true,
      expiresAt: DateTime.utc(2026, 9, 12, 12),
      managementUrl: 'https://play.google.com/store/account/subscriptions',
    );

    testWidgets('sees the plan they are on, not an offer to buy it again', (
      tester,
    ) async {
      givenStatus(status);
      await tester.pumpWidget(_subject(service: service, isPremium: true));
      await tester.pumpAndSettle();

      expect(find.text('Mevcut planın'), findsOneWidget);
      // "Aylık" appears exactly once — as the current plan. A second one
      // would mean the screen is selling them the plan they already pay for,
      // which is what the paywall was doing.
      expect(find.text('Aylık'), findsOneWidget);
    });

    testWidgets('is told when the subscription renews', (tester) async {
      givenStatus(status);
      await tester.pumpWidget(_subject(service: service, isPremium: true));
      await tester.pumpAndSettle();

      expect(find.textContaining('yenilenir'), findsOneWidget);
      expect(find.textContaining('Eylül'), findsOneWidget);
    });

    testWidgets('can reach the store page to cancel', (tester) async {
      givenStatus(status);
      await tester.pumpWidget(_subject(service: service, isPremium: true));
      await tester.pumpAndSettle();

      // The whole reason this screen exists: neither store lets an app
      // cancel a subscription, so the only honest cancel is a way out to
      // the store. Previously there was none anywhere in the app.
      expect(find.text('Aboneliği yönet'), findsOneWidget);
    });

    testWidgets('is offered the annual plan as the one upgrade', (
      tester,
    ) async {
      givenStatus(status);
      await tester.pumpWidget(_subject(service: service, isPremium: true));
      await tester.pumpAndSettle();

      expect(find.text('Yıllık plana geç'), findsOneWidget);
      expect(find.text('%40 tasarruf'), findsOneWidget);
    });

    testWidgets('switching plans tells the store which product it replaces', (
      tester,
    ) async {
      givenStatus(status);
      when(
        () => service.purchase(any(), replacingProductId: any(named: 'replacingProductId')),
      ).thenAnswer((_) async => SubscriptionPurchaseResult.success);

      await tester.pumpWidget(_subject(service: service, isPremium: true));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Yıllık plana geç'));
      await tester.tap(find.text('Yıllık plana geç'));
      await tester.pump();

      // Play rejects a plain purchase inside a subscription group the buyer
      // is already in; the old product has to be named or the upgrade fails
      // at the billing sheet.
      final captured = verify(
        () => service.purchase(
          any(),
          replacingProductId: captureAny(named: 'replacingProductId'),
        ),
      ).captured;
      expect(captured.single, 'nutrilens_monthly');
    });
  });

  testWidgets('an annual subscriber is offered no plan change at all', (
    tester,
  ) async {
    givenStatus(
      SubscriptionStatus(
        tier: SubscriptionTier.premium,
        productId: 'nutrilens_annual',
        willRenew: true,
        expiresAt: DateTime.utc(2027, 1, 4, 12),
      ),
    );
    await tester.pumpWidget(_subject(service: service, isPremium: true));
    await tester.pumpAndSettle();

    expect(find.text('Yıllık'), findsOneWidget);
    expect(find.text('Yıllık plana geç'), findsNothing);
    // A downgrade to monthly is not our business to push — they can do it
    // from the store page.
    expect(find.text('Aylık'), findsNothing);
  });

  testWidgets('a cancelled subscription reads as ending, not renewing', (
    tester,
  ) async {
    givenStatus(
      SubscriptionStatus(
        tier: SubscriptionTier.premium,
        productId: 'nutrilens_monthly',
        willRenew: false,
        expiresAt: DateTime.utc(2026, 9, 12, 12),
      ),
    );
    await tester.pumpWidget(_subject(service: service, isPremium: true));
    await tester.pumpAndSettle();

    // Same date, opposite news.
    expect(find.textContaining('sona erecek'), findsOneWidget);
    expect(find.textContaining('yenilenir'), findsNothing);
    expect(find.text('İptal edildi'), findsOneWidget);
  });

  testWidgets('a comp-granted account is not sent hunting for a subscription '
      'to cancel', (tester) async {
    // Premium from a Supabase grant: real access, no RevenueCat entitlement
    // and nothing in any store to manage.
    givenStatus(SubscriptionStatus.free);
    await tester.pumpWidget(_subject(service: service, isPremium: true));
    await tester.pumpAndSettle();

    expect(find.textContaining('doğrudan tanımlı'), findsOneWidget);
    expect(find.text('Aboneliği yönet'), findsNothing);
  });
}
