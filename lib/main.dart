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
import 'core/providers/locale_provider.dart';
import 'core/providers/monetization_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/product/presentation/providers/product_provider.dart';

void main() async {
  // Sadece debug modda aktif olması güvenli bir yaklaşımdır
  if (kDebugMode) FlutterSkillBinding.ensureInitialized();

  await bootstrap();

  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        supabaseClientProvider.overrideWithValue(Supabase.instance.client),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        subscriptionServiceProvider.overrideWithValue(subscriptionService),
      ],
      child: const NutriLensApp(),
    ),
  );
}

class NutriLensApp extends ConsumerStatefulWidget {
  const NutriLensApp({super.key});

  @override
  ConsumerState<NutriLensApp> createState() => _NutriLensAppState();
}

class _NutriLensAppState extends ConsumerState<NutriLensApp> {
  late final GoRouter _router;
  StreamSubscription<Uri?>? _widgetClicked;

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
