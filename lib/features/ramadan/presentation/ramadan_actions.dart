import '../../../l10n/generated/app_localizations.dart';

/// Notification text, resolved by the caller from `context.l10n`.
typedef RamadanCopy = ({
  String sahurTitle,
  String sahurBody,
  String iftarTitle,
  String iftarBody,
});

RamadanCopy ramadanCopy(AppLocalizations l10n, int offsetMin) => (
  sahurTitle: l10n.ramadanSahurTitle,
  sahurBody: l10n.ramadanSahurBody(offsetMin),
  iftarTitle: l10n.ramadanIftarTitle,
  iftarBody: l10n.ramadanIftarBody,
);
