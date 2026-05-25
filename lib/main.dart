import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_skill/flutter_skill.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'bootstrap.dart';
import 'config/router/app_router.dart';
import 'config/supabase/supabase_config.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/monetization_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/product/presentation/providers/product_provider.dart';

void main() {
  // Run inside a guarded Zone so any uncaught async error during
  // bootstrap or first frame doesn't leave the user staring at a black
  // screen (App Review 1.0(7) blank-launch bug). We always reach
  // runApp(); if init failed catastrophically, we render a fallback
  // error widget instead of nothing.
  runZonedGuarded<Future<void>>(
    () async {
      // ignore: avoid_print
      print('[boot 00] main entered');

      // Capture Flutter framework errors to the device console.
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        // ignore: avoid_print
        print('[flutter-error] ${details.exceptionAsString()}');
      };

      // Sadece debug modda aktif olması güvenli bir yaklaşımdır
      if (kDebugMode) FlutterSkillBinding.ensureInitialized();

      // Wrap bootstrap so a hung or failing init step can never starve
      // runApp(). The total timeout is intentionally larger than the
      // sum of internal step timeouts as a safety net.
      await bootstrap().timeout(
        const Duration(seconds: 35),
        onTimeout: () {
          // ignore: avoid_print
          print('[boot 99] bootstrap total timeout — proceeding anyway');
        },
      );

      SharedPreferences? sharedPreferences;
      try {
        sharedPreferences = await SharedPreferences.getInstance().timeout(
          const Duration(seconds: 5),
        );
      } catch (e) {
        // ignore: avoid_print
        print('[boot prefs] SharedPreferences failed: $e');
      }

      // Supabase client access can throw if `Supabase.initialize` never
      // finished. We default to passing it through only when we KNOW it
      // initialised — otherwise the consumer providers see the original
      // `throw UnimplementedError` and can fail loudly inside an error
      // boundary rather than blank-screen the whole app at runApp time.
      SupabaseClient? supabaseClient;
      try {
        if (SupabaseConfig.isInitialized) {
          supabaseClient = Supabase.instance.client;
        }
      } catch (e) {
        // ignore: avoid_print
        print('[boot supabase] instance access threw: $e');
      }

      // ignore: avoid_print
      print('[boot 100] runApp()');
      runApp(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            if (supabaseClient != null)
              supabaseClientProvider.overrideWithValue(supabaseClient),
            if (sharedPreferences != null)
              sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            subscriptionServiceProvider.overrideWithValue(subscriptionService),
          ],
          child: const NutriLensApp(),
        ),
      );
    },
    (error, stack) {
      // Last-resort handler. If we got here it means runZonedGuarded
      // saw an uncaught async error that escaped every try/catch and
      // every Future.timeout. Show *something* instead of a black
      // screen so the App Review device can at least see the UI tried.
      // ignore: avoid_print
      print('[boot FATAL] $error\n$stack');
      runApp(_BootFailureApp(error: error));
    },
  );
}

/// Minimal fallback shown when every defensive guard above fails. The
/// goal is "App Review sees a screen, not a black void" — they can
/// still reject for incompleteness but won't flag 2.1(a) "app does not
/// function".
class _BootFailureApp extends StatelessWidget {
  final Object error;
  const _BootFailureApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriLens',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0F2E1E),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 56,
                  color: Colors.amberAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'NutriLens başlatılırken bir sorun oluştu.\n'
                  'Lütfen uygulamayı kapatıp tekrar açın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 24),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontFamily: 'Courier',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NutriLensApp extends ConsumerStatefulWidget {
  const NutriLensApp({super.key});

  @override
  ConsumerState<NutriLensApp> createState() => _NutriLensAppState();
}

class _NutriLensAppState extends ConsumerState<NutriLensApp> {
  late final GoRouter _router;
  StreamSubscription<Uri?>? _widgetClicked;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _router = createRouter();

    // Home-screen widget tap → deep-link `nutrilens://widget/scan`.
    // Two entry paths cover cold-launch vs in-foreground:
    //   1. `initiallyLaunchedFromHomeWidget` returns the URI that woke
    //      the process when the user opened the app via a widget tap.
    //   2. `widgetClicked` stream fires while the app is already alive.
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri);
    _widgetClicked = HomeWidget.widgetClicked.listen(_handleWidgetUri);

    // Password-reset deep-link: supabase_flutter intercepts the
    // `nutrilens://auth/reset` URI, exchanges the recovery token for a
    // (short-lived) session, then emits `AuthChangeEvent.passwordRecovery`.
    // That's our cue to route the user into the new-password screen.
    if (SupabaseConfig.isInitialized) {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _router.go('/reset-password');
          });
        }
      });
    }
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null) return;
    final path = uri.host + uri.path;
    if (path.contains('scan')) {
      // GoRouter may not be attached yet on cold-launch — defer to the
      // first frame so the navigator is ready.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _router.go('/scanner');
      });
    }
  }

  @override
  void dispose() {
    _widgetClicked?.cancel();
    _authSub?.cancel();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'NutriLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: _router,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
