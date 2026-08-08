import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/session/app_session.dart';
import '../../../../core/session/guest_migration_service.dart';
import 'guest_migration_prompt_sheet.dart';

/// Single cross-cutting hook run by both login + register screens
/// after Supabase reports a successful auth. Two responsibilities:
///
/// 1. If the user accumulated data while browsing as a guest, ask
///    them whether to migrate it. The prompt is suppressed when there
///    is nothing to move (most regular logins).
/// 2. Clear the guest flag so subsequent cold launches behave like
///    a normal authenticated session.
///
/// The function navigates to /meals when it returns — callers don't
/// need to do their own context.go after invoking it.
Future<void> runPostAuthFlow(
  WidgetRef ref,
  BuildContext context, {
  required String userId,
}) async {
  final migration = ref.read(guestMigrationServiceProvider);
  // Both providers are read up front, before anything is awaited. `ref` is
  // backed by the caller's BuildContext and becomes unsafe the moment that
  // widget is disposed — which happens for real: the migration sheet below
  // stays open while `migrate()` syncs over the network, and a user who
  // backs out or gets killed mid-sync used to crash on the read at the
  // bottom (Sentry NUTRILENS-6, iOS 1.2.2+39).
  //
  // Guarding that read away instead would be worse than the crash: skipping
  // exitGuestMode() leaves someone who just signed in still flagged as a
  // guest, so the call has to happen either way. Holding the controller is
  // what Riverpod's own error message prescribes.
  final session = ref.read(appSessionControllerProvider);
  final summary = await migration.inspectPending();

  // The mounted check guards the SHEET, which needs a live context — it must
  // not gate the rest of the function. As an early `return` it also skipped
  // exitGuestMode() whenever the screen was disposed during inspectPending(),
  // leaving someone who had just signed in still flagged as a guest on every
  // later launch. Silent, and the opposite failure of the crash below.
  if (context.mounted && !summary.isEmpty) {
    final wantsMigrate = await GuestMigrationPromptSheet.show(
      context,
      summary: summary,
    );
    if (wantsMigrate == true) {
      await migration.migrate(newUserId: userId);
    } else {
      await migration.discard();
    }
  }

  // Unconditional on purpose: clearing the guest flag needs no BuildContext,
  // and it is the one step of this flow that must survive the user walking
  // away. Only the navigation below is context-dependent.
  await session.exitGuestMode();

  if (!context.mounted) return;
  context.go('/meals');
}
