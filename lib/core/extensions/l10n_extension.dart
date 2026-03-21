import 'package:flutter/material.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

extension L10nExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
