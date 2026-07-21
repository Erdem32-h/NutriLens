import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/product/presentation/providers/product_provider.dart'
    show supabaseClientProvider;
import '../providers/locale_provider.dart' show sharedPreferencesProvider;
import '../services/device_id_service.dart';
import 'analytics_service.dart';

/// Off in debug so local development never pollutes the production funnel —
/// the whole point of these numbers is that they describe real users. Pass
/// `--dart-define=ANALYTICS_FORCE_ENABLE=true` to exercise the pipeline
/// against a real Supabase project from a debug build.
const _forceEnable = bool.fromEnvironment('ANALYTICS_FORCE_ENABLE');

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  // Both dependencies throw when they were never overridden (see main.dart —
  // the overrides are conditional on a successful init). Analytics must never
  // be the reason a screen fails to build, so a missing dependency degrades
  // to "no analytics" instead of propagating out of this provider.
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {
    prefs = null;
  }

  SupabaseClient? client;
  try {
    client = ref.watch(supabaseClientProvider);
  } catch (_) {
    client = null;
  }

  final service = AnalyticsService(
    client: client,
    deviceId: prefs == null ? null : DeviceIdService(prefs),
    prefs: prefs,
    enabled: !kDebugMode || _forceEnable,
  );
  ref.onDispose(service.dispose);
  return service;
});
