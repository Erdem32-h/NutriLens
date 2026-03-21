import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'config/drift/app_database.dart';
import 'config/supabase/supabase_config.dart';

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

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Drift database
  database = AppDatabase();
  logger.i('Drift database initialized');

  try {
    await SupabaseConfig.initialize();
    logger.i('Supabase initialized successfully');
  } catch (e) {
    logger.e('Failed to initialize Supabase: $e');
  }
}
