import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/extensions/l10n_extension.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Notification text, resolved by the caller from `context.l10n`. [sahurBody]
/// takes that day's imsak instant rather than a fixed string: an inexact
/// alarm can fire up to an hour late, so the body must state the absolute
/// imsak time (never a countdown) to stay true after a late delivery — see
/// D2 in `device-fix-findings.md`.
typedef RamadanCopy = ({
  String sahurTitle,
  String Function(DateTime imsak) sahurBody,
  String iftarTitle,
  String iftarBody,
});

RamadanCopy ramadanCopy(AppLocalizations l10n) => (
  sahurTitle: l10n.ramadanSahurTitle,
  sahurBody: (imsak) => l10n.ramadanSahurBody(DateFormat('HH:mm').format(imsak)),
  iftarTitle: l10n.ramadanIftarTitle,
  iftarBody: l10n.ramadanIftarBody,
);

/// Explains why Android 14+ jumps to the system "Alarms & reminders" settings
/// screen before [NotificationService.requestExactAlarms] is invoked. Returns
/// `false` on non-Android platforms or when the user skips.
Future<bool> showExactAlarmExplanationDialog(BuildContext context) async {
  if (kIsWeb || !Platform.isAndroid || !context.mounted) return false;
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.exactAlarmTitle),
      content: Text(l10n.exactAlarmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.continueText),
        ),
      ],
    ),
  );
  return confirmed == true;
}
