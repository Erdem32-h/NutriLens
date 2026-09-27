import 'package:intl/intl.dart';

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
