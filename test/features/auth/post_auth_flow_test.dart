import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/core/session/guest_migration_service.dart';
import 'package:nutrilens/features/auth/presentation/widgets/post_auth_flow.dart';

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
        const GuestDataSummary(scanCount: 0, mealCount: 0),
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
        const GuestDataSummary(scanCount: 0, mealCount: 0),
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
        const GuestDataSummary(scanCount: 0, mealCount: 0),
      );

      await tester.pumpWidget(subject());
      await _drain(tester, () => migration.reached);
      migration.gate.complete();
      await _drain(tester, () => session.exitCalls > 0);

      expect(session.exitCalls, 1);
    });
  });
}
