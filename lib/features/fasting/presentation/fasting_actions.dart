import '../../../l10n/generated/app_localizations.dart';

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
