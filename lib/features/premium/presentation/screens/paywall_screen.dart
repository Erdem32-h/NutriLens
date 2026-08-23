import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/legal_links.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/providers/monetization_provider.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/cozy_tokens.dart';
import '../../../../core/widgets/cozy_header.dart';
import '../../../../core/widgets/cozy_tile.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  List<Package> _packages = [];
  bool _loading = true;
  bool _purchasing = false;
  String? _loadError;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final service = ref.read(subscriptionServiceProvider);
    final packages = await service.getOfferings();
    if (mounted) {
      setState(() {
        _packages = packages;
        _loading = false;
        if (packages.isEmpty) {
          _loadError = context.l10n.premiumPackagesLoadError;
        }
        // Default to annual if available — the higher-LTV, higher-margin plan.
        final annualIdx = packages.indexWhere(
          (p) => p.packageType == PackageType.annual,
        );
        if (annualIdx >= 0) _selectedIndex = annualIdx;
      });
    }
  }

  Future<void> _purchase() async {
    if (_packages.isEmpty) {
      // Retry loading if packages didn't load
      await _loadOfferings();
      return;
    }
    if (_purchasing) return;
    setState(() => _purchasing = true);

    try {
      final service = ref.read(subscriptionServiceProvider);
      final result = await service.purchase(_packages[_selectedIndex]);

      if (!mounted) return;
      setState(() => _purchasing = false);

      switch (result) {
        case SubscriptionPurchaseResult.success:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.premiumActivated)),
          );
          Navigator.of(context).pop();
        case SubscriptionPurchaseResult.cancelled:
          // User cancelled — stay silent, they know what they did.
          break;
        case SubscriptionPurchaseResult.failed:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.premiumPurchaseFailed),
              backgroundColor: Colors.red,
            ),
          );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _purchasing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(context, e)),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _purchasing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.premiumPurchaseUnexpectedError),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Maps RevenueCat/Play Billing errors to user-friendly localized messages.
  String _friendlyError(BuildContext context, PlatformException e) {
    final l10n = context.l10n;
    final code = PurchasesErrorHelper.getErrorCode(e);
    return switch (code) {
      PurchasesErrorCode.networkError => l10n.premiumErrorNetwork,
      PurchasesErrorCode.paymentPendingError => l10n.premiumErrorPaymentPending,
      PurchasesErrorCode.productNotAvailableForPurchaseError =>
        l10n.premiumErrorProductUnavailable,
      PurchasesErrorCode.productAlreadyPurchasedError =>
        l10n.premiumErrorAlreadyPurchased,
      PurchasesErrorCode.storeProblemError => l10n.premiumErrorStoreProblem,
      _ => l10n.premiumPurchaseFailed,
    };
  }

  Future<void> _restore() async {
    final service = ref.read(subscriptionServiceProvider);
    final success = await service.restorePurchases();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? context.l10n.premiumRestored
                : context.l10n.premiumNoActiveSubscription,
          ),
        ),
      );
      if (success) Navigator.of(context).pop();
    }
  }

  Package? get _selectedPackage =>
      (_selectedIndex >= 0 && _selectedIndex < _packages.length)
      ? _packages[_selectedIndex]
      : null;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final selectedTrialDays = _selectedPackage == null
        ? null
        : _freeTrialDays(_selectedPackage!);

    final showPackages = !_loading && !(_loadError != null && _packages.isEmpty);

    return Scaffold(
      backgroundColor: colors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null && _packages.isEmpty
          ? _buildErrorState(colors)
          : SingleChildScrollView(
              child: Column(
                children: [
                  CozyHeader(
                    title: l10n.premiumTitle,
                    onBack: () => Navigator.of(context).pop(),
                    // Restore stays a labelled button rather than becoming an
                    // icon chip: both stores require a visible, self-evident
                    // way to restore a purchase, and a glyph the user has to
                    // long-press to identify is not one.
                    action: TextButton(
                      onPressed: _restore,
                      child: Text(l10n.premiumRestore),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    child: Column(
                      children: [
                        _buildFeatureCard(colors),
                        const SizedBox(height: 24),

                        // Package cards
                        RadioGroup<int>(
                          groupValue: _selectedIndex,
                          onChanged: (v) => setState(() => _selectedIndex = v!),
                          child: Column(
                            children: _packages.asMap().entries.map((entry) {
                              return _buildPackageCard(
                                colors,
                                entry.key,
                                entry.value,
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Trust strip — honest, no fabricated metrics.
                        _buildTrustStrip(colors),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      // The CTA is pinned, not scrolled to.
      //
      // It used to be the ninth item of a single scroll column, under a hero,
      // seven feature rows and the plan cards — roughly 900px down. On a
      // 640dp phone the buy button was simply not on screen when the paywall
      // opened, and nothing indicated it existed. On the revenue screen that
      // is the whole funnel. The purchase decision now travels with the user
      // no matter where they are in the page.
      bottomNavigationBar: showPackages
          ? _buildPurchaseBar(colors, selectedTrialDays)
          : null,
    );
  }

  /// The CTA, the renewal disclosure and the store links, pinned to the
  /// bottom of the screen.
  Widget _buildPurchaseBar(AppColorsExtension colors, int? selectedTrialDays) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: colors.cozy.floating,
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _purchasing ? null : _purchase,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: _purchasing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          selectedTrialDays != null
                              ? l10n.premiumTrialCta(selectedTrialDays)
                              : l10n.premiumContinueCta,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),

              // Legal / renewal note. Stays with the button on purpose — the
              // disclosure has to be where the commitment is made.
              Text(
                selectedTrialDays != null
                    ? l10n.premiumTrialAutoRenewNote
                    : l10n.premiumAutoRenewNote,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.cozy.bodyOnTint),
                textAlign: TextAlign.center,
              ),
              _buildLegalLinks(),
            ],
          ),
        ),
      ),
    );
  }

  /// All seven benefits in one cozy card.
  ///
  /// They were seven full-width rows with 12px of padding each. Grouping them
  /// into a single card with a tighter rhythm is not only the cozy skin — it
  /// is most of the vertical budget the plan cards needed.
  Widget _buildFeatureCard(AppColorsExtension colors) {
    final l10n = context.l10n;
    final features = <(IconData, String)>[
      (Icons.all_inclusive, l10n.premiumFeatureUnlimitedScans),
      (Icons.block, l10n.premiumFeatureNoAds),
      (Icons.smart_toy, l10n.premiumFeatureUnlimitedAi),
      (Icons.support_agent, l10n.premiumFeaturePrioritySupport),
      (Icons.cloud_sync_rounded, l10n.premiumFeatureCloudSync),
      (Icons.compare_arrows_rounded, l10n.premiumFeatureComparison),
      (Icons.table_chart_rounded, l10n.premiumFeatureDetailedNutrition),
    ];

    return Container(
      width: double.infinity,
      decoration: cozyCardDecoration(context),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Column(
        children: [
          for (final (index, feature) in features.indexed)
            _FeatureRow(
              icon: feature.$1,
              text: feature.$2,
              // Rotating tints, so the list reads as a set of distinct
              // benefits rather than one block of green.
              tint: colors.cozy.byIndex(index),
            ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(AppColorsExtension colors, int i, Package pkg) {
    final l10n = context.l10n;
    final isSelected = i == _selectedIndex;
    final isAnnual = pkg.packageType == PackageType.annual;
    final savings = isAnnual ? _annualSavingsPercent(_packages) : null;
    final trialDays = _freeTrialDays(pkg);
    final perMonth =
        pkg.storeProduct.pricePerMonthString ?? pkg.storeProduct.priceString;

    // Selection is carried by the tinted fill, not by a hairline that
    // thickens from 1px to 2px — a difference nobody sees on a phone.
    final tint = colors.cozy.mint;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = i),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: isSelected
            ? BoxDecoration(
                color: tint.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: tint.ink, width: 2),
              )
            : cozyCardDecoration(context),
        child: Row(
          children: [
            Radio<int>(value: i),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wrap, not Row: the annual plan carries two pills beside
                  // its name, and on a 360dp phone that trio overflowed the
                  // card by 160px. The pills drop to a second line instead.
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Text(
                        isAnnual
                            ? l10n.premiumPlanAnnual
                            : l10n.premiumPlanMonthly,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (isAnnual)
                        _Pill(
                          text: l10n.premiumMostPopular,
                          color: colors.primary,
                        ),
                      if (savings != null)
                        _Pill(
                          text: l10n.premiumSaveBadge(savings),
                          color: colors.success,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Prominent per-month price for easy comparison.
                  Text(
                    l10n.premiumPerMonth(perMonth),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (isAnnual) ...[
                    const SizedBox(height: 2),
                    Text(
                      l10n.premiumBilledAnnually(pkg.storeProduct.priceString),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.cozy.bodyOnTint,
                      ),
                    ),
                  ],
                  if (trialDays != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.card_giftcard_rounded,
                          size: 14,
                          color: colors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.premiumTrialBadge(trialDays),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: colors.success,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustStrip(AppColorsExtension colors) {
    final l10n = context.l10n;
    final items = <(IconData, String)>[
      (Icons.lock_open_rounded, l10n.premiumTrustCancelAnytime),
      (Icons.verified_user_rounded, l10n.premiumTrustSecurePayment),
      (Icons.bolt_rounded, l10n.premiumTrustInstantAccess),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: items.map((it) {
        return Flexible(
          child: Column(
            children: [
              Icon(it.$1, size: 18, color: colors.cozy.bodyOnTint),
              const SizedBox(height: 4),
              Text(
                it.$2,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colors.cozy.bodyOnTint),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Shown when RevenueCat returns nothing. Carries its own header: this
  /// replaces the whole body, and without one the screen would have no way
  /// back — the AppBar that used to supply the back arrow is gone.
  Widget _buildErrorState(AppColorsExtension colors) {
    return Column(
      children: [
        CozyHeader(
          title: context.l10n.premiumTitle,
          onBack: () => Navigator.of(context).pop(),
          action: TextButton(
            onPressed: _restore,
            child: Text(context.l10n.premiumRestore),
          ),
        ),
        Expanded(child: _buildErrorBody(colors)),
      ],
    );
  }

  Widget _buildErrorBody(AppColorsExtension colors) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: cozyCircleDecoration(context),
              alignment: Alignment.center,
              child: Icon(
                Icons.cloud_off_rounded,
                size: 52,
                color: colors.cozy.sky.ink,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _loadError ?? context.l10n.premiumPackagesUnavailable,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: colors.cozy.bodyOnTint),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loading ? null : _loadOfferings,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.tryAgain),
            ),
            const SizedBox(height: 16),
            _buildLegalLinks(),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalLinks() {
    final l10n = context.l10n;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        TextButton(
          onPressed: () => _openLegalLink(LegalLinks.privacyPolicy),
          child: Text(l10n.premiumPrivacyPolicy),
        ),
        TextButton(
          onPressed: () => _openLegalLink(LegalLinks.termsOfUse),
          child: Text(l10n.premiumTermsOfUse),
        ),
      ],
    );
  }

  Future<void> _openLegalLink(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }
}

/// Free-trial length (whole days) for a package, or null when there is no
/// free trial. Covers both the cross-platform `introductoryPrice` (a zero
/// price is a free trial) and the Google Play `defaultOption.freePhase`,
/// so the paywall lights up automatically once a trial is configured in
/// Play Console + RevenueCat — no app release required.
int? _freeTrialDays(Package pkg) {
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
int? _annualSavingsPercent(List<Package> packages) {
  final monthly = _firstOfType(packages, PackageType.monthly);
  final annual = _firstOfType(packages, PackageType.annual);
  if (monthly == null || annual == null) return null;

  final monthlyForYear = monthly.storeProduct.price * 12;
  if (monthlyForYear <= 0) return null;

  final percent = ((1 - annual.storeProduct.price / monthlyForYear) * 100)
      .round();
  return percent > 0 ? percent : null;
}

Package? _firstOfType(List<Package> packages, PackageType type) {
  final i = packages.indexWhere((p) => p.packageType == type);
  return i >= 0 ? packages[i] : null;
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;

  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// One benefit line inside the feature card.
///
/// The icon sits on its own tinted rounded square rather than being a bare
/// primary-green glyph — the same chip language as [CozyIconChip], scaled
/// down to a size that lets seven of them stack without pushing the plans off
/// the screen.
class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final CozyTint tint;

  const _FeatureRow({
    required this.icon,
    required this.text,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tint.ink, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
