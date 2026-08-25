import 'package:purchases_flutter/purchases_flutter.dart';

/// Pricing facts derived from a store offering.
///
/// Lives outside the paywall because the subscription screen asks the same
/// questions of the same packages — what a plan really saves, whether it
/// carries a trial — and a second copy of this arithmetic is how the two
/// screens end up quoting different discounts for the same product.

/// Free-trial length (whole days) for a package, or null when there is no
/// free trial. Covers both the cross-platform `introductoryPrice` (a zero
/// price is a free trial) and the Google Play `defaultOption.freePhase`,
/// so the paywall lights up automatically once a trial is configured in
/// Play Console + RevenueCat — no app release required.
int? freeTrialDays(Package pkg) {
  final product = pkg.storeProduct;

  final intro = product.introductoryPrice;
  if (intro != null && intro.price == 0) {
    return _periodToDays(intro.periodUnit, intro.periodNumberOfUnits);
  }

  final freePeriod = product.defaultOption?.freePhase?.billingPeriod;
  if (freePeriod != null) {
    return _periodToDays(freePeriod.unit, freePeriod.value);
  }

  return null;
}

int _periodToDays(PeriodUnit unit, int value) {
  switch (unit) {
    case PeriodUnit.day:
      return value;
    case PeriodUnit.week:
      return value * 7;
    case PeriodUnit.month:
      return value * 30;
    case PeriodUnit.year:
      return value * 365;
    case PeriodUnit.unknown:
      return value;
  }
}

/// Real annual savings vs paying the monthly plan for a year, rounded to a
/// whole percent. Null when either plan is missing or there's no saving —
/// so we never show a fabricated discount.
int? annualSavingsPercent(List<Package> packages) {
  final monthly = firstOfType(packages, PackageType.monthly);
  final annual = firstOfType(packages, PackageType.annual);
  if (monthly == null || annual == null) return null;

  final monthlyForYear = monthly.storeProduct.price * 12;
  if (monthlyForYear <= 0) return null;

  final percent = ((1 - annual.storeProduct.price / monthlyForYear) * 100)
      .round();
  return percent > 0 ? percent : null;
}

Package? firstOfType(List<Package> packages, PackageType type) {
  final i = packages.indexWhere((p) => p.packageType == type);
  return i >= 0 ? packages[i] : null;
}

/// Whether [pkg] is the product currently backing the user's entitlement.
///
/// Compared on the part before `:` because Google Play reports a subscription
/// as `productId:basePlanId` in some SDK paths and as a bare `productId` in
/// others. Matching the raw strings would silently fail on Play and offer the
/// user the plan they are already paying for.
bool packageMatchesProduct(Package pkg, String? productId) {
  if (productId == null) return false;
  String base(String id) => id.split(':').first;
  return base(pkg.storeProduct.identifier) == base(productId);
}
