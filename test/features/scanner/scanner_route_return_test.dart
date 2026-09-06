import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/core/providers/monetization_provider.dart';
import 'package:nutrilens/core/services/scan_limit_service.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/core/theme/app_colors.dart';
import 'package:nutrilens/features/scanner/presentation/providers/scanner_mode_provider.dart';
import 'package:nutrilens/features/scanner/presentation/screens/scanner_screen.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

class _UnusedClient extends Mock implements SupabaseClient {}

// Real ScannerScreen + MobileScannerController + GoRouter. Only the hardware
// boundary is fake; no Supabase, camera permission, AI call or scan debit.
class _ScannerHardware extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture?>.broadcast();
  final calls = <String>[];
  bool running = false;

  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    calls.add('start');
    running = true;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(640, 480),
    );
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    running = false;
  }

  @override
  Future<void> dispose() async {
    running = false;
  }

  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.green);
}

Future<void> _pumpCamera(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('barcode -> product -> back remounts preview and scans again', (
    tester,
  ) async {
    final original = MobileScannerPlatform.instance;
    final hardware = _ScannerHardware();
    MobileScannerPlatform.instance = hardware;
    addTearDown(() {
      MobileScannerPlatform.instance = original;
      unawaited(hardware.captures.close());
    });
    // Barcode restart retains the historical camera-plugin HAL workaround.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/camera'),
      (call) async => call.method == 'availableCameras' ? <Object>[] : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/camera'),
        null,
      ),
    );
    SharedPreferences.setMockInitialValues({'scanner.camera_worked_v1': true});
    final prefs = await SharedPreferences.getInstance();
    // Premium short-circuits the scan check. No Auth client/timer is needed.
    final client = _UnusedClient();
    final rootNavigator = GlobalKey<NavigatorState>();
    final router = GoRouter(
      navigatorKey: rootNavigator,
      initialLocation: '/scanner',
      routes: [
        ShellRoute(
          builder: (_, _, child) => Scaffold(body: child),
          routes: [
            GoRoute(path: '/scanner', builder: (_, _) => const ScannerScreen()),
          ],
        ),
        GoRoute(
          path: '/product/:barcode',
          parentNavigatorKey: rootNavigator,
          builder: (_, state) => Scaffold(
            appBar: AppBar(title: const Text('Product detail')),
            body: Text(state.pathParameters['barcode']!),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          pendingScannerModeProvider.overrideWith((ref) => 0),
          isGuestProvider.overrideWithValue(false),
          isPremiumProvider.overrideWithValue(true),
          scanLimitServiceProvider.overrideWithValue(ScanLimitService(client)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(extensions: const [AppColorsExtension.light]),
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await _pumpCamera(tester);
    expect(hardware.running, isTrue);
    for (final code in ['8695077002334', '8000500310427', '5449000000996']) {
      final previewState = tester.state(find.byType(MobileScanner));
      hardware.captures.add(
        BarcodeCapture(barcodes: [Barcode(rawValue: code)]),
      );
      await _pumpCamera(tester);
      expect(
        find.text('Product detail'),
        findsOneWidget,
        reason:
            'Hardware calls: ${hardware.calls}; route: ${router.routeInformationProvider.value.uri}',
      );
      expect(hardware.running, isFalse);
      final resumesFromBackground = code == '8000500310427';
      if (resumesFromBackground) {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await _pumpCamera(tester);
        expect(hardware.running, isFalse);
      }
      router.pop();
      await _pumpCamera(tester);
      if (resumesFromBackground) {
        expect(
          hardware.running,
          isFalse,
          reason: 'Returning while backgrounded must not start a camera',
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await _pumpCamera(tester);
      }
      expect(find.byType(ScannerScreen), findsOneWidget);
      expect(hardware.running, isTrue);
      expect(
        tester.state(find.byType(MobileScanner)),
        isNot(same(previewState)),
      );
      expect(tester.takeException(), isNull);
    }
    expect(hardware.calls.where((call) => call == 'start'), hasLength(4));
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpCamera(tester);
  });
}
