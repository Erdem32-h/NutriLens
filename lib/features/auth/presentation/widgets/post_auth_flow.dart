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
  final summary = await migration.inspectPending();

  if (!context.mounted) return;

  if (!summary.isEmpty) {
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

  await ref.read(appSessionControllerProvider).exitGuestMode();

  if (!context.mounted) return;
  context.go('/meals');
}
