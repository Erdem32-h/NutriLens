import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/core/analytics/analytics_event.dart';
import 'package:nutrilens/core/analytics/analytics_provider.dart';
import 'package:nutrilens/core/analytics/analytics_service.dart';
import 'package:nutrilens/core/theme/app_colors.dart';
import 'package:nutrilens/core/widgets/app_button.dart';
import 'package:nutrilens/features/auth/domain/entities/user_entity.dart';
import 'package:nutrilens/features/auth/domain/repositories/auth_repository.dart';
import 'package:nutrilens/features/auth/presentation/providers/auth_provider.dart';
import 'package:nutrilens/features/auth/presentation/screens/login_screen.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _RecordingAnalytics extends AnalyticsService {
  _RecordingAnalytics()
    : super(
        client: null,
        deviceId: null,
        prefs: null,
        enabled: false,
        flushInterval: Duration.zero,
      );

  final calls = <(String, Map<String, Object?>)>[];

  @override
  void track(String name, {Map<String, Object?> props = const {}}) {
    calls.add((name, props));
  }

  List<Map<String, Object?>> propsFor(String name) =>
      calls.where((c) => c.$1 == name).map((c) => c.$2).toList();
}

void main() {
  late _MockAuthRepository repository;
  late _RecordingAnalytics analytics;

  setUp(() {
    repository = _MockAuthRepository();
    analytics = _RecordingAnalytics();
    when(() => repository.currentUser).thenReturn(null);
    when(
      () => repository.authStateChanges(),
    ).thenAnswer((_) => const Stream<UserEntity?>.empty());
  });

  Widget subject() => ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(analytics),
      authRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(extensions: const [AppColorsExtension.light]),
      home: const LoginScreen(),
    ),
  );

  /// Matched by label rather than position: unlike the register screen, the
  /// sign-in button is not the first [AppButton] in the tree — the social
  /// buttons and the guest CTA sit above the email form.
  Finder submitButton(WidgetTester tester) {
    final l10n = AppLocalizations.of(tester.element(find.byType(LoginScreen)))!;
    return find.byWidgetPredicate(
      (w) => w is AppButton && w.label == l10n.signIn,
    );
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    final submit = submitButton(tester);
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
  }

  testWidgets('an empty-form submit is recorded even though validation '
      'stops it', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pump();

    await tapSubmit(tester);

    // The whole point of the event: `login_started` fires only after
    // `validate()` passes, so someone who taps and bounces off a red field
    // produced nothing at all — indistinguishable server-side from someone
    // who never found the button.
    expect(analytics.propsFor(FunnelEvents.loginSubmitTapped), hasLength(1));
    expect(analytics.propsFor(FunnelEvents.loginStarted), isEmpty);
  });

  testWidgets('the email path carries its method so social sign-ins are '
      'distinguishable', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pump();

    await tapSubmit(tester);

    final tapped = analytics.propsFor(FunnelEvents.loginSubmitTapped);
    expect(tapped.single['method'], 'email');
  });
}
