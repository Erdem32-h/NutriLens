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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.premiumTitle),
        actions: [
          TextButton(onPressed: _restore, child: Text(l10n.premiumRestore)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null && _packages.isEmpty
          ? _buildErrorState(colors)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Hero
                  Icon(Icons.star, size: 64, color: colors.warning),
                  const SizedBox(height: 16),
                  Text(
                    l10n.premiumTitle,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Features
                  _FeatureTile(
                    icon: Icons.all_inclusive,
                    text: l10n.premiumFeatureUnlimitedScans,
                  ),
                  _FeatureTile(
                    icon: Icons.block,
                    text: l10n.premiumFeatureNoAds,
                  ),
                  _FeatureTile(
                    icon: Icons.smart_toy,
                    text: l10n.premiumFeatureUnlimitedAi,
                  ),
                  _FeatureTile(
                    icon: Icons.support_agent,
                    text: l10n.premiumFeaturePrioritySupport,
                  ),
                  const SizedBox(height: 32),

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
                  const SizedBox(height: 24),

                  // Purchase button — trial-aware CTA.
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _purchasing ? null : _purchase,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                  const SizedBox(height: 12),

                  // Trust strip — honest, no fabricated metrics.
                  _buildTrustStrip(colors),
                  const SizedBox(height: 12),

                  // Legal / renewal note
                  Text(
                    selectedTrialDays != null
                        ? l10n.premiumTrialAutoRenewNote
                        : l10n.premiumAutoRenewNote,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  _buildLegalLinks(),
                ],
              ),
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

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = i),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? colors.primary
                : colors.textSecondary.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? colors.primary.withValues(alpha: 0.04)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Radio<int>(value: i),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isAnnual
                            ? l10n.premiumPlanAnnual
                            : l10n.premiumPlanMonthly,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isAnnual) ...[
                        const SizedBox(width: 8),
                        _Pill(
                          text: l10n.premiumMostPopular,
                          color: colors.primary,
                        ),
                      ],
                      if (savings != null) ...[
                        const SizedBox(width: 6),
                        _Pill(
                          text: l10n.premiumSaveBadge(savings),
                          color: colors.success,
                        ),
                      ],
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
                        color: colors.textSecondary,
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
              Icon(it.$1, size: 18, color: colors.textSecondary),
              const SizedBox(height: 4),
              Text(
                it.$2,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildErrorState(AppColorsExtension colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: colors.textMuted),
            const SizedBox(height: 16),
            Text(
              _loadError ?? context.l10n.premiumPackagesUnavailable,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 15),
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

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureTile({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          const SizedBox(width: 12),
          Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
