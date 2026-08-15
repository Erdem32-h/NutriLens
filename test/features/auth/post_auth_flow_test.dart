import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/core/services/calorie_target_calculator.dart';
import 'package:nutrilens/core/services/guest_scan_counter.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/core/session/guest_migration_service.dart';
import 'package:nutrilens/features/auth/presentation/widgets/post_auth_flow.dart';
import 'package:nutrilens/features/history/data/datasources/scan_history_local_datasource.dart';
import 'package:nutrilens/features/meals/data/datasources/meal_local_datasource.dart';
import 'package:nutrilens/features/profile/data/datasources/user_metrics_local_datasource.dart';
import 'package:nutrilens/features/profile/domain/entities/user_metrics_entity.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

/// Holds `inspectPending` open so a test can dispose the caller mid-flight —
/// the window in which the real crash happened (the migration sheet stays up
/// while `migrate()` syncs over the network).
class _GatedMigration implements GuestMigrationService {
  _GatedMigration(this._summary);

  final GuestDataSummary _summary;
  final gate = Completer<void>();
  bool reached = false;

  @override
  Future<GuestDataSummary> inspectPending() async {
    reached = true;
    await gate.future;
    return _summary;
  }

  @override
  Future<void> migrate({required String newUserId}) async {}

  @override
  Future<void> discard() async {}
}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGuestScanCounter extends Mock implements GuestScanCounter {}

class _RecordingSession implements AppSessionController {
  int exitCalls = 0;

  @override
  Future<void> exitGuestMode() async => exitCalls++;

  @override
  Future<void> enterGuestMode() async {}

  @override
  Future<void> completeOnboarding() async {}
}

/// Minimal host that kicks off the flow from its own BuildContext, the way
/// the login and register screens do.
class _Host extends ConsumerStatefulWidget {
  const _Host();

  @override
  ConsumerState<_Host> createState() => _HostState();
}

class _HostState extends ConsumerState<_Host> {
  Object? caught;

  @override
  void initState() {
    super.initState();
    // Errors are captured rather than rethrown so the assertion can be about
    // what the flow did, not about how flutter_test surfaces a zone error.
    runPostAuthFlow(
      ref,
      context,
      userId: 'user-123',
    ).catchError((Object e) => caught = e);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

Future<void> _drain(WidgetTester tester, bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!done() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  late _GatedMigration migration;
  late _RecordingSession session;

  Widget subject() => ProviderScope(
    overrides: [
      guestMigrationServiceProvider.overrideWithValue(migration),
      appSessionControllerProvider.overrideWithValue(session),
    ],
    child: const MaterialApp(home: _Host()),
  );

  setUp(() {
    session = _RecordingSession();
  });

  group('runPostAuthFlow', () {
    testWidgets('REGRESSION: leaves guest mode even when the caller is '
        'disposed mid-flow', (tester) async {
      migration = _GatedMigration(
        const GuestDataSummary(
          scanCount: 0,
          mealCount: 0,
          hasMetrics: false,
        ),
      );

      await tester.pumpWidget(subject());
      await _drain(tester, () => migration.reached);

      // The screen goes away while the flow is still awaiting. Before the fix
      // the controller was read from `ref` AFTER this point, which threw
      // StateError ("Using \"ref\" when a widget ... has been unmounted") —
      // Sentry NUTRILENS-6.
      await tester.pumpWidget(const SizedBox());
      migration.gate.complete();
      await _drain(tester, () => session.exitCalls > 0);

      // Both halves matter. No crash, AND the guest flag still gets cleared:
      // guarding the call away instead would leave someone who just signed in
      // flagged as a guest on every later launch.
      expect(session.exitCalls, 1);
    });

    testWidgets('does not crash the caller when disposed mid-flow', (
      tester,
    ) async {
      migration = _GatedMigration(
        const GuestDataSummary(
          scanCount: 0,
          mealCount: 0,
          hasMetrics: false,
        ),
      );

      await tester.pumpWidget(subject());
      await _drain(tester, () => migration.reached);
      final host = tester.state<_HostState>(find.byType(_Host));

      await tester.pumpWidget(const SizedBox());
      migration.gate.complete();
      await _drain(tester, () => session.exitCalls > 0);

      expect(host.caught, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('still exits guest mode on the normal path', (tester) async {
      migration = _GatedMigration(
        const GuestDataSummary(
          scanCount: 0,
          mealCount: 0,
          hasMetrics: false,
        ),
      );

      await tester.pumpWidget(subject());
      await _drain(tester, () => migration.reached);
      migration.gate.complete();
      await _drain(tester, () => session.exitCalls > 0);

      expect(session.exitCalls, 1);
    });
  });

  group('guest metrics orphaning (GuestDataSummary.isEmpty)', () {
    testWidgets(
      'guest with metrics only (zero scans, zero meals) is still offered '
      'the migration prompt, and ends up with metrics on the new account '
      'and no leftover guest row',
      (tester) async {
        // Real service + real in-memory Drift DB — this exercises the
        // actual `inspectPending()` → `isEmpty` gate in post_auth_flow.dart
        // and `GuestMigrationPromptSheet.show`'s own `isEmpty` guard, not a
        // fake that could paper over the bug. A guest who only completed
        // the metrics wizard (no scans, no meals saved) is exactly the
        // scenario `GuestDataSummary.isEmpty` used to get wrong.
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final metricsDs = UserMetricsLocalDataSourceImpl(db);
        await metricsDs.save(
          UserMetricsEntity(
            userId: kGuestUserId,
            sex: BiologicalSex.female,
            birthYear: 1990,
            heightCm: 165,
            weightKg: 60,
            activity: ActivityLevel.moderate,
            updatedAt: DateTime(2026, 8, 14),
          ),
        );

        final counter = _MockGuestScanCounter();
        when(() => counter.reset()).thenAnswer((_) async {});
        final realMigration = GuestMigrationService(
          scanDs: ScanHistoryLocalDataSourceImpl(db),
          mealDs: MealLocalDataSourceImpl(db),
          metricsDs: metricsDs,
          supabase: _MockSupabaseClient(),
          counter: counter,
        );

        session = _RecordingSession();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              guestMigrationServiceProvider.overrideWithValue(realMigration),
              appSessionControllerProvider.overrideWithValue(session),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('tr'),
              home: const _Host(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Prompt sheet must have appeared even though scanCount == 0 and
        // mealCount == 0 — the whole point of the fix.
        expect(
          find.text('Evet, hesabıma yükle'),
          findsOneWidget,
          reason:
              'guest metrics-only olsa bile misafir devri prompt\'u '
              'gosterilmeli',
        );

        await tester.tap(find.text('Evet, hesabıma yükle'));
        await tester.pumpAndSettle();

        expect(await metricsDs.get('user-123'), isNotNull);
        expect(
          await metricsDs.get(kGuestUserId),
          isNull,
          reason:
              'guest satiri silinmezse bir sonraki misafir bu kullanicinin '
              'boy/kilo/yasini devralir',
        );
        expect(session.exitCalls, 1);
      },
    );
  });
}
