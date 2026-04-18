import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'config/drift/app_database.dart';
import 'config/supabase/supabase_config.dart';
import 'core/services/ad_service.dart';
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

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Drift database
  database = AppDatabase();
  logger.i('Drift database initialized');

  // Seed additive database (no-op if already seeded)
  unawaited(_seedAdditivesIfRequired(database));

  try {
    await SupabaseConfig.initialize().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        logger.w('Supabase initialization timed out after 10s — continuing offline');
      },
    );
    if (SupabaseConfig.isInitialized) {
      logger.i('Supabase initialized successfully');
    }
  } catch (e) {
    logger.e('Failed to initialize Supabase: $e');
  }

  // Initialize RevenueCat — store in the global so main.dart can pass it
  // to Riverpod via provider override (same pattern as AppDatabase).
  subscriptionService = RevenueCatSubscriptionService();
  await subscriptionService.initialize();

  // Link auth to RevenueCat
  final currentUser = SupabaseConfig.isInitialized
      ? SupabaseConfig.client.auth.currentUser
      : null;
  if (currentUser != null) {
    await subscriptionService.logIn(currentUser.id);
  }

  // Initialize AdMob
  await AdService.initialize();
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

