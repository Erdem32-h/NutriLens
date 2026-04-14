import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/services/content_analysis_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../counterfeit/presentation/widgets/counterfeit_warning_banner.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../../profile/presentation/providers/health_filters_provider.dart';
import '../../domain/entities/product_entity.dart';
import '../../../../core/constants/score_constants.dart';
import '../providers/product_provider.dart';
import '../widgets/alternative_placeholder.dart';
import '../widgets/bento_nutrition_grid.dart';
import '../widgets/content_analysis_section.dart';
import '../widgets/editorial_header.dart';
import '../widgets/editorial_nutrient_table.dart';
import '../widgets/health_score_bar.dart';
import '../widgets/pill_tab_bar.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String barcode;

  const ProductDetailScreen({super.key, required this.barcode});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _selectedTab = 0;
  bool _hasRedirected = false;
  bool _historyAdded = false;

  void _redirectToEdit() {
    if (_hasRedirected) return;
    _hasRedirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.pushReplacement('/product/${widget.barcode}/edit');
    });
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productByBarcodeProvider(widget.barcode));
    final isFavoriteAsync = ref.watch(isFavoriteProvider(widget.barcode));
    final isBlacklistedAsync = ref.watch(isBlacklistedProvider(widget.barcode));
    final l10n = context.l10n;

    final productLoaded =
        productAsync.hasValue && productAsync.value != null;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(l10n.productDetail),
        backgroundColor: Colors.transparent,
        actions: productLoaded
            ? [
                // Favorite toggle
                isFavoriteAsync.when(
                  loading: () => const SizedBox(
                    width: 48,
                    child: Center(
                        child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))),
                  ),
                  error: (e, s) => const SizedBox.shrink(),
                  data: (isFav) => IconButton(
                    tooltip: isFav ? l10n.removeFromFavorites : l10n.addToFavorites,
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? Colors.redAccent : null,
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      if (isFav) {
                        await removeFavoriteByBarcode(ref,
                            barcode: widget.barcode);
                        if (mounted) {
                          messenger.showSnackBar(SnackBar(
                              content: Text(l10n.removedFromFavorites)));
                        }
                      } else {
                        await addToFavorites(ref, barcode: widget.barcode);
                        if (mounted) {
                          messenger.showSnackBar(
                              SnackBar(content: Text(l10n.addedToFavorites)));
                        }
                      }
                    },
                  ),
                ),
                // Blacklist toggle
                isBlacklistedAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, s) => const SizedBox.shrink(),
                  data: (isBlocked) => IconButton(
                    tooltip: isBlocked
                        ? l10n.removeFromBlacklist
                        : l10n.addToBlacklist,
                    icon: Icon(
                      isBlocked ? Icons.block : Icons.block_outlined,
                      color: isBlocked ? Colors.orange : null,
                    ),
                    onPressed: () async {
                      if (isBlocked) {
                        await removeBlacklistByBarcode(ref,
                            barcode: widget.barcode);
                      } else {
                        await addToBlacklist(ref, barcode: widget.barcode);
                      }
                    },
                  ),
                ),
              ]
            : null,
      ),
      body: productAsync.when(
        loading: () {
          debugPrint('[ProductDetail] barcode=${widget.barcode} → loading');
          return _buildShimmer(context);
        },
        error: (error, stack) {
          debugPrint('[ProductDetail] barcode=${widget.barcode} → ERROR: $error');
          debugPrint('[ProductDetail] stack: $stack');
          // On error, redirect to edit screen so user can enter data manually
          _redirectToEdit();
          return _buildShimmer(context);
        },
        data: (product) {
          // Product not found anywhere -> redirect to edit (creation mode)
          if (product == null) {
            debugPrint('[ProductDetail] barcode=${widget.barcode} → null, redirect to edit');
            _redirectToEdit();
            return _buildShimmer(context);
          }

          debugPrint('[ProductDetail] barcode=${widget.barcode} → found: '
              'name=${product.productName}, brands=${product.brands}, '
              'ingredients=${product.ingredientsText != null}, '
              'energyKcal=${product.nutriments.energyKcal}, '
              'hasEssentialData=${product.hasEssentialData}');

          // Product missing essential data -> redirect to edit to fill gaps
          if (!product.hasEssentialData) {
            debugPrint('[ProductDetail] → missing essential data, redirect to edit');
            _redirectToEdit();
            return _buildShimmer(context);
          }

          // Product found with complete data -> add to history and show
          if (!_historyAdded) {
            _historyAdded = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              addScanToHistory(
                ref,
                barcode: product.barcode,
                hpScore: product.calculatedHpScore,
              );
            });
          }

          debugPrint('[ProductDetail] → rendering product detail');
          return _buildProductDetail(product);
        },
      ),
    );
  }

  Widget _buildProductDetail(ProductEntity product) {
    return SingleChildScrollView(
      child: Column(
        children: [
          EditorialHeader(
            product: product,
            onEditPressed: () {
              context.push('/product/${widget.barcode}/edit');
            },
          ),
          // Tarım Bakanlığı counterfeit warning (highest priority)
          CounterfeitWarningBanner(
            barcode: widget.barcode,
            brand: product.brands,
          ),
          _buildBlacklistedBanner(),
          _buildFilterWarningBanner(product),
          PillTabBar(
            selectedIndex: _selectedTab,
            onTabChanged: (i) => setState(() => _selectedTab = i),
          ),
          const SizedBox(height: 16),
          if (_selectedTab == 0) ..._buildHealthTab(product),
          if (_selectedTab == 1) ..._buildNutritionTab(product),
          if (_selectedTab == 2) ..._buildAlternativeTab(product),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Shows a banner when this product is in the user's blacklist.
  Widget _buildBlacklistedBanner() {
    final isBlacklistedAsync = ref.watch(isBlacklistedProvider(widget.barcode));

    return isBlacklistedAsync.maybeWhen(
      data: (isBlocked) {
        if (!isBlocked) return const SizedBox.shrink();
        final l10n = context.l10n;
        final colors = context.colors;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.block, color: Colors.orange, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.blacklistedWarning,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  /// Shows a prominent banner when the product triggers the user's personal
  /// health filters (allergens, diets, oils, chemicals).
  Widget _buildFilterWarningBanner(ProductEntity product) {
    final filters = ref.watch(healthFiltersProvider);
    final hasAnyFilter = filters.allergens.isNotEmpty ||
        filters.diets.isNotEmpty ||
        filters.oils.isNotEmpty ||
        filters.chemicals.isNotEmpty;

    if (!hasAnyFilter) return const SizedBox.shrink();

    final warnings = ContentAnalysisService.analyzeIngredients(
      product: product,
      activeAllergens: filters.allergens,
      activeDiets: filters.diets,
      activeOils: filters.oils,
      activeChemicals: filters.chemicals,
    );

    // Only show personal filter warnings (containsFilteredItem), not general ones
    final filterWarnings = warnings
        .where((w) => w.messageKey == 'containsFilteredItem')
        .toList();

    if (filterWarnings.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.error.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: colors.error,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.personalFilterWarning,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.error,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    filterWarnings
                        .map((w) => _resolveFilterName(l10n, w))
                        .join(', '),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.error.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveFilterName(dynamic l10n, ContentWarning warning) {
    if (warning.placeholderKey == null) return '';
    return switch (warning.placeholderKey) {
      'filterGluten' => l10n.filterGluten,
      'filterLactose' => l10n.filterLactose,
      'filterPeanut' => l10n.filterPeanut,
      'filterSoy' => l10n.filterSoy,
      'filterEgg' => l10n.filterEgg,
      'filterFish' => l10n.filterFish,
      'filterVegan' => l10n.filterVegan,
      'filterVegetarian' => l10n.filterVegetarian,
      'filterHalal' => l10n.filterHalal,
      'filterPalmOil' => l10n.filterPalmOil,
      'filterTransFat' => l10n.filterTransFat,
      'filterCanola' => l10n.filterCanola,
      'filterMsg' => l10n.filterMsg,
      'filterAspartame' => l10n.filterAspartame,
      'filterHfcs' => l10n.filterHfcs,
      'filterNitrite' => l10n.filterNitrite,
      'filterColorant' => l10n.filterColorant,
      _ => warning.placeholderKey!,
    };
  }

  List<Widget> _buildHealthTab(ProductEntity product) {
    return [
      HealthScoreBar(hpScore: product.calculatedHpScore),
      const SizedBox(height: 8),
      ContentAnalysisSection(product: product),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${context.l10n.barcode}: ${product.barcode}',
            style: TextStyle(
              fontSize: 12,
              color: context.colors.textMuted,
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildNutritionTab(ProductEntity product) {
    return [
      if (product.ingredientsText != null && product.ingredientsText!.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.ingredientsTextLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.ingredientsText!,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
      BentoNutritionGrid(nutriments: product.nutriments),
      const SizedBox(height: 16),
      EditorialNutrientTable(nutriments: product.nutriments),
    ];
  }

  List<Widget> _buildAlternativeTab(ProductEntity product) {
    final hpScore = product.calculatedHpScore ?? 0.0;
    final altAsync = ref.watch(
      alternativesProvider((barcode: product.barcode, hpScore: hpScore)),
    );

    return [
      // "Did you know?" tip card — always visible
      const AlternativePlaceholder(),
      // Actual alternatives from local cache
      altAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, s) => const SizedBox.shrink(),
        data: (alts) {
          if (alts.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  context.l10n.alternatives,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 160,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(right: 24),
                    itemCount: alts.length,
                    separatorBuilder: (context, i) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _AlternativeCard(product: alts[i]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ];
  }

  Widget _buildShimmer(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.colors.surfaceCard,
      highlightColor: context.colors.surfaceCard2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image placeholder
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: context.colors.surfaceCard,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 20, color: context.colors.surfaceCard),
            const SizedBox(height: 8),
            Container(
              height: 14,
              width: 120,
              color: context.colors.surfaceCard,
            ),
            const SizedBox(height: 24),
            // Tab bar placeholder
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: context.colors.surfaceCard,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < 3; i++) ...[
              Container(
                height: 80,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: context.colors.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small card showing an alternative product in the horizontal list.
class _AlternativeCard extends StatelessWidget {
  final ProductEntity product;

  const _AlternativeCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gauge = ScoreConstants.hpToGauge(product.calculatedHpScore);
    final gaugeColor = colors.gaugeColor(gauge);

    return GestureDetector(
      onTap: () => context.push('/product/${product.barcode}'),
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: product.imageUrl != null
                  ? Image.network(
                      product.imageUrl!,
                      height: 72,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, e, s) => _placeholder(colors),
                    )
                  : _placeholder(colors),
            ),
            const SizedBox(height: 8),
            // HP gauge badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: gaugeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$gauge',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: gaugeColor,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Product name
            Text(
              product.productName ?? product.barcode,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(AppColorsExtension colors) {
    return Container(
      height: 72,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceCard2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.image_outlined, size: 28, color: colors.textMuted),
    );
  }
}
