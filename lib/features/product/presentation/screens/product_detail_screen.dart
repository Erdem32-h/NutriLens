import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../domain/entities/product_entity.dart';
import '../providers/product_provider.dart';
import '../widgets/additive_classification.dart';
import '../widgets/chemical_load_gauge.dart';
import '../widgets/community_badge.dart';
import '../widgets/ingredient_list.dart';
import '../widgets/nova_card.dart';
import '../widgets/nutriment_table.dart';
import '../widgets/product_header.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String barcode;

  const ProductDetailScreen({super.key, required this.barcode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productByBarcodeProvider(barcode));
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(l10n.productDetail),
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          labelColor: context.colors.primary,
          unselectedLabelColor: context.colors.textMuted,
          indicatorColor: context.colors.primary,
          tabs: [
            Tab(text: l10n.tabHealth),
            Tab(text: l10n.tabNutrient),
            Tab(text: l10n.tabAlternative),
          ],
        ),
      ),
      body: productAsync.when(
        loading: () => _buildShimmer(context),
        error: (error, _) => _buildError(context, ref, error),
        data: (product) {
          if (product == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/product/$barcode/not-found');
            });
            return _buildShimmer(context);
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            addScanToHistory(
              ref,
              barcode: product.barcode,
              hpScore: product.hpScore,
            );
          });

          return Column(
            children: [
              ProductHeader(product: product),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildHealthTab(context, product),
                    _buildNutrientTab(context, product),
                    _buildAlternativeTab(context),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHealthTab(BuildContext context, ProductEntity product) {
    final l10n = context.l10n;
    final isPartial =
        product.hpRiskFactor == null &&
        product.hpNutriFactor == null &&
        product.hpChemicalLoad != null;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (isPartial) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: CommunityBadge(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ChemicalLoadGauge(
              chemicalLoad: product.hpChemicalLoad!,
              isPartial: true,
            ),
          ),
        ] else if (product.hpChemicalLoad != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ChemicalLoadGauge(
              chemicalLoad: product.hpChemicalLoad!,
              isPartial: false,
            ),
          ),
        ],
        NovaCard(novaGroup: product.novaGroup),
        AdditiveClassification(product: product),
        IngredientList(ingredientsText: product.ingredientsText),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            '${l10n.barcode}: ${product.barcode}',
            style: TextStyle(fontSize: 12, color: context.colors.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _buildNutrientTab(BuildContext context, ProductEntity product) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [NutrimentTable(nutriments: product.nutriments)],
    );
  }

  Widget _buildAlternativeTab(BuildContext context) {
    final l10n = context.l10n;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: context.colors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                size: 48,
                color: context.colors.textMuted,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.alternatives,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Daha sağlıklı alternatifler yakında eklenecek',
                style: TextStyle(fontSize: 14, color: context.colors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
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
            Row(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 20, color: context.colors.surfaceCard),
                      const SizedBox(height: 8),
                      Container(
                        height: 14,
                        width: 120,
                        color: context.colors.surfaceCard,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 28,
                        width: 100,
                        color: context.colors.surfaceCard,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < 3; i++) ...[
              Container(
                height: 80,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: context.colors.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
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
                border: Border.all(color: context.colors.border),
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
              style: TextStyle(fontSize: 14, color: context.colors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => ref.invalidate(productByBarcodeProvider(barcode)),
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
