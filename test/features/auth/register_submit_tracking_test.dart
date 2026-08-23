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
import 'package:nutrilens/features/auth/presentation/screens/register_screen.dart';
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
      home: const RegisterScreen(),
    ),
  );

  testWidgets('an empty-form submit is recorded even though validation '
      'stops it', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pump();

    // The screen's own primary action is the first AppButton in the tree;
    // the social buttons sit below the divider.
    final submit = find.byType(AppButton).first;
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    // This is the whole point of the event. `register_started` fires only
    // after `validate()` passes, so a visitor who taps and bounces off a
    // red field produced nothing at all — indistinguishable in every
    // server-side table from one who never found the button.
    expect(analytics.propsFor(FunnelEvents.registerSubmitTapped), hasLength(1));
    expect(analytics.propsFor(FunnelEvents.registerStarted), isEmpty);
  });

  testWidgets('the email path carries its method so social sign-ups are '
      'distinguishable', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pump();

    final submit = find.byType(AppButton).first;
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    final tapped = analytics.propsFor(FunnelEvents.registerSubmitTapped);
    expect(tapped.single['method'], 'email');
  });
}
