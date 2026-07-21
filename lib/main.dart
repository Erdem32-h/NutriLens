import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_skill/flutter_skill.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'bootstrap.dart';
import 'config/router/app_router.dart';
import 'config/supabase/supabase_config.dart';
import 'core/analytics/analytics_event.dart';
import 'core/analytics/analytics_provider.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/monetization_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/session/app_session.dart';
import 'core/theme/app_theme.dart';
import 'features/product/presentation/providers/product_provider.dart';

Future<void> main() async {
  // Sentry — Crash + error reporting. DSN is injected at build time via
  // `--dart-define=SENTRY_DSN=...` (see codemagic.yaml). In local debug
  // builds where the dart-define is absent we skip init entirely so
  // local runs never report noise to the production Sentry project.
  const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  if (sentryDsn.isEmpty) {
    _bootApp();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn;
      // Performance sampling — 10% in prod is enough to spot regressions
      // without blowing through the free tier (5K events/month).
      options.tracesSampleRate = 0.1;
      options.environment = kReleaseMode ? 'production' : 'debug';
      // Don't ship PII (email, IP) by default. We tag user id manually
      // post-login (see auth listener) without exposing email.
      options.sendDefaultPii = false;
      options.attachStacktrace = true;

      // Session Replay — records every tap/scroll/screen change so we
      // can play back exactly what a user did before a crash or stuck
      // state. While we're still in beta the on-error sample rate is
      // 1.0 (every error attaches a replay) and the session rate is
      // 1.0 (every session is recorded). Lower the session rate to
      // ~0.1 after public launch to stay inside the free quota; the
      // on-error rate stays at 1.0 because those are the most
      // valuable recordings.
      options.replay.sessionSampleRate = 1.0;
      options.replay.onErrorSampleRate = 1.0;
      // Default-on aggressive privacy: every text field and image is
      // masked in the replay (these are default-true in 9.20+, set
      // explicitly so future SDK changes can't silently flip them).
      // Profile email, allergens, scan history would otherwise be
      // visible to Sentry viewers.
      options.privacy.maskAllText = true;
      options.privacy.maskAllImages = true;

      // Drop known-benign noise so real bugs don't get buried.
      options.beforeSend = (event, hint) {
        final ex = event.throwable;
        // Supabase fires AuthApiException on cold launch when no
        // saved session exists or the refresh token has rotated.
        // The app already handles this gracefully (falls through to
        // the login screen) — no developer action is ever needed.
        if (ex is AuthApiException) {
          final code = ex.code;
          if (code == 'refresh_token_not_found' ||
              code == 'session_not_found' ||
              code == 'invalid_refresh_token' ||
              code == 'refresh_token_already_used') {
            return null;
          }
        }
        return event;
      };
    },
    appRunner: _bootApp,
  );
}

void _bootApp() {
  // Run inside a guarded Zone so any uncaught async error during
  // bootstrap or first frame doesn't leave the user staring at a black
  // screen (App Review 1.0(7) blank-launch bug). We always reach
  // runApp(); if init failed catastrophically, we render a fallback
  // error widget instead of nothing.
  // Tracks whether runApp() has been reached. Once the UI is mounted, a
  // stray *async* error that escapes into the zone (most commonly a
  // background Supabase token refresh failing on a flaky network / DNS
  // lookup — `AuthRetryableFetchException`) must NOT tear down the
  // already-running app. The fatal fallback screen is only appropriate
  // for catastrophic *pre-launch* failures.
  var appStarted = false;

  runZonedGuarded<Future<void>>(
    () async {
      // ignore: avoid_print
      print('[boot 00] main entered');

      // Capture Flutter framework errors to the device console. Sentry's
      // FlutterError.onError chain still fires because SentryFlutter
      // installs its hook before this main() runs and our override
      // calls FlutterError.presentError() which forwards to it.
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        // ignore: avoid_print
        print('[flutter-error] ${details.exceptionAsString()}');
        Sentry.captureException(details.exception, stackTrace: details.stack);
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
      // SentryWidget is the host that Session Replay attaches its
      // capture overlay to. Wrapping at the ProviderScope's child
      // keeps Riverpod working unchanged while making the entire app
      // recordable. It's a no-op when Sentry isn't initialised.
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
          child: SentryWidget(child: const NutriLensApp()),
        ),
      );
      // From here on the UI owns the screen; later async errors are
      // non-fatal (see appStarted guard below).
      appStarted = true;
    },
    (error, stack) {
      // ignore: avoid_print
      print('[boot FATAL] $error\n$stack');
      Sentry.captureException(error, stackTrace: stack);

      // If the app already launched, a stray async error (e.g. a
      // background token refresh failing because the network/DNS is
      // momentarily unreachable) is benign — supabase_flutter retries on
      // its own and the app's offline/guest flow keeps working. Report
      // it and leave the running UI untouched. Replacing it with the
      // fatal screen here was bricking cold launches on flaky networks.
      if (appStarted) return;

      // Transient network / retryable-auth errors are never fatal even
      // pre-launch: the Supabase session refresh fires fire-and-forget
      // during bootstrap and can land before runApp() on a slow DNS.
      // bootstrap() itself degrades gracefully (lands on login/guest),
      // so swallow these and let the normal launch continue.
      if (_isTransientNetworkError(error)) return;

      // Pre-launch catastrophe: show *something* instead of a black
      // screen so the user (and App Review) sees the app tried to start.
      runApp(_BootFailureApp(error: error));
    },
  );
}

/// True for errors caused by a momentarily unreachable network (DNS
/// lookup failure, dropped socket) or a Supabase auth refresh that is
/// retryable by design. These must never blank-screen the app — they
/// resolve on their own once connectivity returns.
bool _isTransientNetworkError(Object error) {
  if (error is AuthRetryableFetchException) return true;
  if (error is SocketException) return true;
  // Nested cases: the thrown object's message often embeds the socket
  // failure even when the concrete type isn't one of the above.
  final text = error.toString();
  return text.contains('Failed host lookup') ||
      text.contains('SocketException') ||
      text.contains('No address associated with hostname');
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
                // Deliberately bilingual rather than localized: this screen
                // is the fallback for a bootstrap that never reached runApp,
                // so AppLocalizations was never loaded and l10n lookups are
                // unavailable here by definition.
                const Text(
                  'NutriLens başlatılırken bir sorun oluştu.\n'
                  'Lütfen uygulamayı kapatıp tekrar açın.\n\n'
                  'NutriLens failed to start.\n'
                  'Please close the app and open it again.',
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
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    _router = createRouter(ref);

    // Top of the activation funnel. Every later step is read as a fraction
    // of this, so it has to fire before anything can redirect or fail.
    final analytics = ref.read(analyticsServiceProvider);
    analytics.track(
      FunnelEvents.appOpened,
      props: {
        'first_launch': !ref.read(hasSeenOnboardingProvider),
        'session_state': ref.read(appSessionProvider).name,
      },
    );

    // Backgrounding is the most common way a session ends, and it's the last
    // moment we can ship the queue while the process is still alive. Without
    // this, a user who never reopens the app only shows up after the next
    // launch replays the persisted queue — and users who churn never do.
    _lifecycle = AppLifecycleListener(
      onPause: () => unawaited(analytics.flush()),
      onDetach: () => unawaited(analytics.flush()),
    );

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
    //
    // We also use this listener to tag Sentry events with the current
    // user id (no email/PII) so crash reports can be grouped per-user
    // without leaking personal data.
    if (SupabaseConfig.isInitialized) {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _router.go('/reset-password');
          });
        }
        final userId = data.session?.user.id;
        Sentry.configureScope((scope) {
          scope.setUser(userId == null ? null : SentryUser(id: userId));
        });
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
    _lifecycle?.dispose();
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
