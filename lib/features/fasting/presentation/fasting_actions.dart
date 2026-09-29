import 'package:flutter/material.dart';

import '../../../core/extensions/l10n_extension.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/fasting_session.dart';

/// Notification text for the "fast target reached" alert, resolved by the
/// caller from `context.l10n`. [body] takes the fast length in hours rather
/// than a fixed string: an inexact alarm can fire late, so the body must
/// state the target length (never a countdown) to stay true regardless of
/// delivery delay — mirrors `RamadanCopy.sahurBody`.
typedef FastingCopy = ({String title, String Function(int hours) body});

FastingCopy fastingCopy(AppLocalizations l10n) => (
  title: l10n.fastingNotificationTitle,
  body: (hours) => l10n.fastingNotificationBody(hours),
);

/// Locale-neutral duration formatting shared by the screen, the card and the
/// meal-save dialog: `'H:MM'` (e.g. `14:05`). Not a localized string — a
/// fast length reads the same regardless of language, and this keeps every
/// caller consistent rather than each rolling its own.
String formatFastDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  return '$hours:${minutes.toString().padLeft(2, '0')}';
}

/// Confirms ending [active] before its target is reached (spec's "end
/// early?" dialog); resolves immediately with `true` once the target has
/// already been reached. Shared by [FastingScreen] and [FastingCard] so
/// both End buttons behave identically.
Future<bool> confirmEndFast(
  BuildContext context,
  FastingSession active,
  DateTime now,
) async {
  if (active.reachedTarget(now)) return true;
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.fastingEndEarlyTitle),
      content: Text(
        l10n.fastingEndEarlyBody(formatFastDuration(active.remaining(now))),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.fastingEnd),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
