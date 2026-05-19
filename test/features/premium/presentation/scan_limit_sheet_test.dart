import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrilens/core/providers/monetization_provider.dart';
import 'package:nutrilens/core/services/ad_service.dart';
import 'package:nutrilens/core/services/scan_limit_service.dart';
import 'package:nutrilens/core/theme/app_colors.dart';
import 'package:nutrilens/features/premium/presentation/screens/paywall_screen.dart';
import 'package:nutrilens/features/premium/presentation/widgets/scan_limit_sheet.dart';
import 'package:nutrilens/core/services/subscription_service.dart';

// ── Fakes & Mocks ─────────────────────────────────────────────────────────────

class FakeAdService extends Fake implements AdService {
  final bool _adReady;
  final bool _rewardedResult;

  FakeAdService({bool adReady = false, bool rewardedResult = true})
    : _adReady = adReady,
      _rewardedResult = rewardedResult;

  @override
  bool get isRewardedAdReady => _adReady;

  @override
  Future<bool> showRewardedAd() async => _rewardedResult;

  @override
  void loadRewardedAd() {}

  @override
  void dispose() {}
}

class FakeScanLimitService extends Fake implements ScanLimitService {
  final BonusScanResult _bonusResult;
  int grantBonusScanCallCount = 0;

  FakeScanLimitService({BonusScanResult? bonusResult})
    : _bonusResult =
          bonusResult ??
          const BonusScanResult(granted: true, bonusRemaining: 1);

  @override
  Future<BonusScanResult> grantBonusScan() async {
    grantBonusScanCallCount++;
    return _bonusResult;
  }

  @override
  Future<ScanCheckResult> checkAndIncrement({
    bool localPremium = false,
  }) async => ScanCheckResult.unlimited;
}

class MockSubscriptionService extends Mock implements SubscriptionService {}

// ── Helpers ───────────────────────────────────────────────────────────────────

GoRouter _buildRouter({
  required AdService adService,
  required ScanLimitService scanLimitService,
}) {
  return GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(
        path: '/test',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => ScanLimitSheet.show(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) => const PaywallScreen(),
      ),
    ],
  );
}

Widget _buildSubject({
  AdService? adService,
  ScanLimitService? scanLimitService,
  SubscriptionService? subscriptionService,
}) {
  final ad = adService ?? FakeAdService();
  final scan = scanLimitService ?? FakeScanLimitService();
  final mockSub = subscriptionService ?? MockSubscriptionService();

  if (mockSub is MockSubscriptionService) {
    when(() => mockSub.getOfferings()).thenAnswer((_) async => []);
    when(() => mockSub.statusStream).thenAnswer((_) => const Stream.empty());
  }

  final router = _buildRouter(adService: ad, scanLimitService: scan);

  return ProviderScope(
    overrides: [
      adServiceProvider.overrideWithValue(ad),
      scanLimitServiceProvider.overrideWithValue(scan),
      subscriptionServiceProvider.overrideWithValue(mockSub),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(extensions: const [AppColorsExtension.light]),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('ScanLimitSheet', () {
    testWidgets('renders title and subtitle', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Günlük Tarama Hakkın Doldu'), findsOneWidget);
      expect(find.textContaining('sınırsız tarama'), findsOneWidget);
    });

    testWidgets("renders Premium'a Geç button", (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text("Premium'a Geç"), findsOneWidget);
    });

    testWidgets('renders Kapat button', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Kapat'), findsOneWidget);
    });

    testWidgets('does NOT show rewarded ad button when ad is not ready', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(adService: FakeAdService(adReady: false)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Reklam İzle → +1 Tarama'), findsNothing);
    });

    testWidgets('shows rewarded ad button when ad is ready', (tester) async {
      await tester.pumpWidget(
        _buildSubject(adService: FakeAdService(adReady: true)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Reklam İzle → +1 Tarama'), findsOneWidget);
    });

    testWidgets('Kapat button dismisses the sheet', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();

      expect(find.text('Günlük Tarama Hakkın Doldu'), findsNothing);
    });

    testWidgets("Premium'a Geç button navigates to paywall", (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Premium'a Geç"));
      await tester.pumpAndSettle();

      // Sheet is dismissed and paywall is pushed
      expect(find.text('Günlük Tarama Hakkın Doldu'), findsNothing);
      expect(find.text('Geri Yükle'), findsOneWidget);
    });

    testWidgets(
      'rewarded ad button dismisses sheet when ad watched and bonus granted',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            adService: FakeAdService(adReady: true),
            scanLimitService: FakeScanLimitService(
              bonusResult: const BonusScanResult(
                granted: true,
                bonusRemaining: 1,
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reklam İzle → +1 Tarama'));
        await tester.pumpAndSettle();

        // Sheet should be gone (bonus granted → scan allowed)
        expect(find.text('Günlük Tarama Hakkın Doldu'), findsNothing);
      },
    );

    testWidgets('rewarded ad cancellation does not grant bonus or dismiss', (
      tester,
    ) async {
      final scanLimitService = FakeScanLimitService();

      await tester.pumpWidget(
        _buildSubject(
          adService: FakeAdService(adReady: true, rewardedResult: false),
          scanLimitService: scanLimitService,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reklam İzle → +1 Tarama'));
      await tester.pumpAndSettle();

      expect(scanLimitService.grantBonusScanCallCount, 0);
      expect(find.text('Günlük Tarama Hakkın Doldu'), findsOneWidget);
    });

    testWidgets('rewarded ad keeps sheet open when bonus is denied', (
      tester,
    ) async {
      final scanLimitService = FakeScanLimitService(
        bonusResult: const BonusScanResult(
          granted: false,
          reason: 'max_bonus_reached',
        ),
      );

      await tester.pumpWidget(
        _buildSubject(
          adService: FakeAdService(adReady: true),
          scanLimitService: scanLimitService,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reklam İzle → +1 Tarama'));
      await tester.pumpAndSettle();

      expect(scanLimitService.grantBonusScanCallCount, 1);
      expect(find.text('Günlük Tarama Hakkın Doldu'), findsOneWidget);
    });
  });
}
