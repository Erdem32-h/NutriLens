import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../domain/entities/product_entity.dart';
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
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(l10n.productDetail),
        backgroundColor: Colors.transparent,
      ),
      body: productAsync.when(
        loading: () => _buildShimmer(context),
        error: (error, _) => _buildError(context, error),
        data: (product) {
          // Product not found anywhere -> redirect to edit (creation mode)
          if (product == null) {
            _redirectToEdit();
            return _buildShimmer(context);
          }

          // Product found but missing essential data -> redirect to edit (completion mode)
          if (!product.hasEssentialData) {
            _redirectToEdit();
            return _buildShimmer(context);
          }

          // Product is complete -> add to history and show detail
          WidgetsBinding.instance.addPostFrameCallback((_) {
            addScanToHistory(
              ref,
              barcode: product.barcode,
              hpScore: product.hpScore,
            );
          });

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
          PillTabBar(
            selectedIndex: _selectedTab,
            onTabChanged: (i) => setState(() => _selectedTab = i),
          ),
          const SizedBox(height: 16),
          if (_selectedTab == 0) ..._buildHealthTab(product),
          if (_selectedTab == 1) ..._buildNutritionTab(product),
          if (_selectedTab == 2) ..._buildAlternativeTab(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<Widget> _buildHealthTab(ProductEntity product) {
    return [
      HealthScoreBar(hpScore: product.hpScore),
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
      BentoNutritionGrid(nutriments: product.nutriments),
      const SizedBox(height: 16),
      EditorialNutrientTable(nutriments: product.nutriments),
    ];
  }

  List<Widget> _buildAlternativeTab() {
    return [
      const AlternativePlaceholder(),
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

  Widget _buildError(BuildContext context, Object error) {
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: context.colors.surfaceCard,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 44,
                color: context.colors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.productLoadFailed,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: TextStyle(
                fontSize: 14,
                color: context.colors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => ref.invalidate(
                productByBarcodeProvider(widget.barcode),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: context.colors.primaryGradient,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      color: Colors.black,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.retry,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
