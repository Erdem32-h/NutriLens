import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/store_links.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/providers/monetization_provider.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/cozy_header.dart';
import '../../../../core/widgets/cozy_tile.dart';
import '../../domain/package_pricing.dart';

/// What an existing subscriber sees — deliberately not the paywall.
///
/// The paywall's job is to sell to someone who has not bought. Pointing a
/// paying customer at it produced two visible faults on a real device: it
/// offered them the exact plan they were already paying for, and it had no
/// way to cancel anywhere on the screen. Cancelling is not optional — Apple
/// requires a route to subscription management, and a customer who cannot
/// find one in the app goes looking for the refund button instead.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  List<Package> _packages = const [];
  bool _changingPlan = false;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  /// Offerings are only needed to name the current plan and to price the
  /// upgrade. If they fail to load the screen still works — the renewal date
  /// and the manage button come from the entitlement, not from the store
  /// catalogue — so there is no error state here.
  Future<void> _loadOfferings() async {
    final packages = await ref.read(subscriptionServiceProvider).getOfferings();
    if (mounted) setState(() => _packages = packages);
  }

  Future<void> _openManagement(SubscriptionStatus status) async {
    final url =
        status.managementUrl ??
        StoreLinks.subscriptionsFor(Theme.of(context).platform);
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.subscriptionManageFailed)));
  }

  Future<void> _switchTo(Package package, SubscriptionStatus status) async {
    if (_changingPlan) return;
    setState(() => _changingPlan = true);
    try {
      final result = await ref
          .read(subscriptionServiceProvider)
          .purchase(package, replacingProductId: status.productId);
      if (!mounted) return;
      setState(() => _changingPlan = false);
      switch (result) {
        case SubscriptionPurchaseResult.success:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.premiumActivated)),
          );
        case SubscriptionPurchaseResult.cancelled:
          break;
        case SubscriptionPurchaseResult.failed:
          _showError(context.l10n.premiumPurchaseFailed);
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _changingPlan = false);
      final code = PurchasesErrorHelper.getErrorCode(e);
      _showError(
        code == PurchasesErrorCode.networkError
            ? context.l10n.premiumErrorNetwork
            : context.l10n.premiumPurchaseFailed,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _changingPlan = false);
      _showError(context.l10n.premiumPurchaseUnexpectedError);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final statusAsync = ref.watch(subscriptionStatusProvider);
    final status = statusAsync.value ?? SubscriptionStatus.free;
    // Premium can also come from a Supabase comp grant, which produces no
    // RevenueCat entitlement at all. Those users have real access and nothing
    // to cancel, and telling them otherwise would send them hunting through
    // Play for a subscription that does not exist.
    final hasStoreSubscription = status.isPremium;
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: statusAsync.isLoading && !isPremium
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CozyHeader(
                    title: l10n.subscriptionMineTitle,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasStoreSubscription)
                          ..._storeSubscriptionSections(colors, status)
                        else if (isPremium)
                          _grantCard(colors)
                        else
                          _noSubscriptionCard(colors),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _storeSubscriptionSections(
    AppColorsExtension colors,
    SubscriptionStatus status,
  ) {
    final l10n = context.l10n;
    final current = _packages
        .where((p) => packageMatchesProduct(p, status.productId))
        .firstOrNull;
    final upgrade = _upgradeOffer(status, current);

    return [
      _currentPlanCard(colors, status, current),
      const SizedBox(height: 20),
      if (upgrade != null) ...[
        _sectionLabel(l10n.subscriptionUpgradeSection),
        const SizedBox(height: 8),
        _upgradeCard(colors, upgrade, status),
        const SizedBox(height: 20),
      ],
      AppButton(
        label: l10n.subscriptionManage,
        variant: AppButtonVariant.secondary,
        icon: Icons.open_in_new_rounded,
        onPressed: () => _openManagement(status),
      ),
      const SizedBox(height: 10),
      Text(
        l10n.subscriptionManageNote,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colors.cozy.bodyOnTint),
      ),
    ];
  }

  /// The plan worth moving to, or null when there is nothing to offer.
  ///
  /// Only ever the annual plan, and only for someone on the monthly one. A
  /// yearly subscriber has no upgrade, and offering a downgrade to the plan
  /// they already rejected is a revenue own-goal — they can still do it from
  /// the store page if they want to.
  Package? _upgradeOffer(SubscriptionStatus status, Package? current) {
    if (current?.packageType != PackageType.monthly) return null;
    final annual = firstOfType(_packages, PackageType.annual);
    if (annual == null) return null;
    return packageMatchesProduct(annual, status.productId) ? null : annual;
  }

  Widget _currentPlanCard(
    AppColorsExtension colors,
    SubscriptionStatus status,
    Package? current,
  ) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final tint = colors.cozy.lilac;
    final planName = switch (current?.packageType) {
      PackageType.annual => l10n.premiumPlanAnnual,
      PackageType.monthly => l10n.premiumPlanMonthly,
      // Offerings unavailable, or a plan shape we do not sell any more. The
      // entitlement is still real, so say that rather than showing nothing.
      _ => l10n.premiumActive,
    };

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: tint.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CozyIconChip(icon: Icons.star_rounded, tint: tint),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.subscriptionCurrentPlan,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.cozy.bodyOnTint,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      planName,
                      style: textTheme.titleLarge?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (!status.willRenew)
                CozyValuePill(l10n.subscriptionCancelledBadge, tint: tint),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _renewalLine(status),
            style: textTheme.bodyMedium?.copyWith(
              color: colors.cozy.bodyOnTint,
            ),
          ),
        ],
      ),
    );
  }

  /// "Renews on the 12th" and "ends on the 12th" are the same date and
  /// opposite news. [SubscriptionStatus.willRenew] is what separates them.
  String _renewalLine(SubscriptionStatus status) {
    final l10n = context.l10n;
    final expiry = status.expiresAt;
    if (expiry == null) return l10n.subscriptionLifetime;
    final formatted = DateFormat(
      'd MMMM yyyy',
      Localizations.localeOf(context).toString(),
    ).format(expiry.toLocal());
    return status.willRenew
        ? l10n.subscriptionRenewsOn(formatted)
        : l10n.subscriptionEndsOn(formatted);
  }

  Widget _upgradeCard(
    AppColorsExtension colors,
    Package annual,
    SubscriptionStatus status,
  ) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final savings = annualSavingsPercent(_packages);
    final perMonth =
        annual.storeProduct.pricePerMonthString ??
        annual.storeProduct.priceString;

    return Container(
      width: double.infinity,
      decoration: cozyCardDecoration(context),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                l10n.premiumPlanAnnual,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (savings != null)
                _SavingsPill(
                  text: l10n.premiumSaveBadge(savings),
                  color: colors.success,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.premiumPerMonth(perMonth),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.premiumBilledAnnually(annual.storeProduct.priceString),
            style: textTheme.bodySmall?.copyWith(color: colors.cozy.bodyOnTint),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: l10n.subscriptionUpgradeCta,
            isLoading: _changingPlan,
            onPressed: () => _switchTo(annual, status),
          ),
        ],
      ),
    );
  }

  /// Premium granted on the account rather than bought in a store.
  Widget _grantCard(AppColorsExtension colors) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final tint = colors.cozy.mint;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: tint.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CozyIconChip(icon: Icons.star_rounded, tint: tint),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.premiumActive,
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.subscriptionGrantNote,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.cozy.bodyOnTint,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Reachable if the entitlement lapses while the screen is open.
  Widget _noSubscriptionCard(AppColorsExtension colors) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.premiumNoActiveSubscription,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: colors.cozy.bodyOnTint),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: l10n.premiumContinueCta,
          onPressed: () => context.push('/paywall'),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      color: context.colors.textPrimary,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _SavingsPill extends StatelessWidget {
  final String text;
  final Color color;

  const _SavingsPill({required this.text, required this.color});

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
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
