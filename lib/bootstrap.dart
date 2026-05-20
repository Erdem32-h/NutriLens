import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'config/drift/app_database.dart';
import 'config/supabase/supabase_config.dart';
import 'core/services/ad_service.dart';
import 'core/services/home_widget_service.dart';
import 'core/services/subscription_service.dart';
import 'features/additive/data/datasources/additive_local_datasource.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: false,
  ),
);

late final AppDatabase database;
late final SubscriptionService subscriptionService;

/// Bulletproof bootstrap. Every async hop is timeout-guarded and wrapped
/// so that **runApp() always gets called within a few seconds, no matter
/// what**. This was learned the hard way: App Review 1.0(7) reported a
/// blank-screen launch on iPadOS 26.5 / iOS 26.5 — `runApp()` never
/// reached the framework because one of the awaits below hung.
///
/// Diagnostic NSLog-style breadcrumbs (`print` reaches `Console.app`
/// when reviewing crash logs on Mac) tag every milestone with a numeric
/// prefix so an early-launch hang is greppable in the device logs:
///   `[boot 01] entered`, `[boot 02] orientation`, `[boot 03] drift`, …
///
/// Anything that fails — Supabase down, RevenueCat key wrong, AdMob
/// init slow — degrades silently; the app still opens, the user lands
/// on the login screen, and the failing subsystem stays off.
Future<void> bootstrap() async {
  // Step 1 — binding. This is fast and required.
  _milestone(1, 'entered');
  WidgetsFlutterBinding.ensureInitialized();

  // Step 2 — Android-only portrait lock. iOS gets to be free-form to
  // avoid the iPad multitasking conflict observed in 1.0(6).
  _milestone(2, 'orientation');
  if (!Platform.isIOS) {
    await _guard(
      'orientation',
      () => SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]),
      timeout: const Duration(seconds: 2),
    );
  }

  // Step 3 — Drift. Construction is synchronous; the file open happens
  // lazily on first query so this never blocks.
  _milestone(3, 'drift');
  database = AppDatabase();

  // Step 4 — seed additives in the background (not on the critical path).
  _milestone(4, 'seed-bg');
  unawaited(_seedAdditivesIfRequired(database));

  // Step 5 — Supabase. Already timeout-protected via the static helper.
  _milestone(5, 'supabase');
  await _guard('supabase', () async {
    await SupabaseConfig.initialize().timeout(const Duration(seconds: 10));
  }, timeout: const Duration(seconds: 12));

  // Step 6 — RevenueCat. If the iOS API key is missing, our impl
  // returns immediately. With a real key, configure() is fast (no
  // server round-trip). Still guard for paranoia.
  _milestone(6, 'revenuecat-init');
  subscriptionService = RevenueCatSubscriptionService();
  await _guard(
    'revenuecat-init',
    () => subscriptionService.initialize(),
    timeout: const Duration(seconds: 8),
  );

  // Step 7 — auth link to RevenueCat (only if Supabase had a session).
  _milestone(7, 'revenuecat-login');
  final currentUser = SupabaseConfig.isInitialized
      ? SupabaseConfig.client.auth.currentUser
      : null;
  if (currentUser != null) {
    await _guard(
      'revenuecat-login',
      () => subscriptionService.logIn(currentUser.id),
      timeout: const Duration(seconds: 6),
    );
  }

  // Step 8 — AdMob. iOS only initialises when a real App ID + at least
  // one unit ID are present (see AdConstants.isAdMobEnabled). The
  // initialise call itself can stall on devices that ask for ATT
  // permission, so the timeout is generous but firm.
  _milestone(8, 'admob');
  await _guard(
    'admob',
    () => AdService.initialize(),
    timeout: const Duration(seconds: 8),
  );

  // Step 9 — Home-screen widget app-group write. Pure UserDefaults
  // call, no network. Wrapped just so a future change can't surprise
  // us.
  _milestone(9, 'home-widget');
  await _guard(
    'home-widget-init',
    () => HomeWidgetService.initialize(),
    timeout: const Duration(seconds: 3),
  );
  unawaited(HomeWidgetService(database).refresh(userId: currentUser?.id));

  _milestone(10, 'done');
}

/// Wraps an async call in a try/catch + timeout. Logs failures and
/// returns normally so the bootstrap chain keeps moving.
Future<void> _guard(
  String label,
  Future<void> Function() body, {
  required Duration timeout,
}) async {
  try {
    await body().timeout(timeout);
  } on TimeoutException {
    logger.w('[bootstrap] $label timed out after ${timeout.inSeconds}s');
    // Also surface to device console so post-mortem crash logs show it.
    // ignore: avoid_print
    print('[boot-timeout] $label');
  } catch (e, st) {
    logger.e('[bootstrap] $label failed', error: e, stackTrace: st);
    // ignore: avoid_print
    print('[boot-fail] $label: $e');
  }
}

void _milestone(int n, String label) {
  // Console.app on macOS picks up `print` lines from a sideloaded app,
  // which is invaluable for App Review post-mortems where we don't
  // have a debugger attached.
  // ignore: avoid_print
  print('[boot ${n.toString().padLeft(2, '0')}] $label');
}

/// Seeds the additive database from the bundled JSON asset on first launch.
/// Runs in the background — does not block app startup.
Future<void> _seedAdditivesIfRequired(AppDatabase db) async {
  try {
    final dataSource = AdditiveLocalDataSourceImpl(db);
    final needsSeed = await dataSource.isSeedRequired();
    if (!needsSeed) return;

    final jsonStr = await rootBundle.loadString(
      'assets/additives/additives_database.json',
    );
    await dataSource.seedFromJson(jsonStr);
    logger.i('Additive database seeded successfully');
  } catch (e) {
    logger.e('Failed to seed additive database: $e');
  }
}
