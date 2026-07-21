import 'package:nutrilens/l10n/generated/app_localizations.dart';

/// Localized label for a product category id.
///
/// Category ids are stable database values (see [ProductCategories]); this is
/// the only place they turn into words a user reads. Unknown ids fall back to
/// "Other" rather than leaking the raw id into the UI.
///
/// Mirrors `meal_display.dart`, which does the same job for meal names.
String categoryLabel(AppLocalizations l10n, String id) => switch (id) {
  'sut' => l10n.catMilk,
  'yogurt' => l10n.catYogurt,
  'peynir' => l10n.catCheese,
  'yag' => l10n.catButterMargarine,
  'biskuvi' => l10n.catBiscuitCracker,
  'cikolata' => l10n.catChocolate,
  'sekerleme' => l10n.catCandy,
  'cips' => l10n.catChipsSnack,
  'kuruyemis' => l10n.catNuts,
  'gazli_icecek' => l10n.catSoda,
  'meyve_suyu' => l10n.catJuice,
  'su' => l10n.catWater,
  'kahve_cay' => l10n.catCoffeeTea,
  'ekmek' => l10n.catBread,
  'gevrek' => l10n.catCereal,
  'makarna' => l10n.catPastaLegumes,
  'hazir_yemek' => l10n.catReadyMeal,
  'sos' => l10n.catSauce,
  'recel_bal' => l10n.catJamHoney,
  'et_sarkuteri' => l10n.catMeatDeli,
  'dondurma' => l10n.catIceCream,
  _ => l10n.catOther,
};
