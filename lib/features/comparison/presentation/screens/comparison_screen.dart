import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/score_constants.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../product/domain/entities/product_entity.dart';
import '../../../../core/constants/app_links.dart';
import '../../../../core/services/share_service.dart';
import '../../../share/domain/share_caption.dart';
import '../../../share/presentation/widgets/comparison_share_card.dart';
import '../../domain/product_comparison.dart';
import '../providers/comparison_provider.dart';

class ComparisonScreen extends ConsumerWidget {
  final String barcodeA;
  final String barcodeB;

  const ComparisonScreen({
    super.key,
    required this.barcodeA,
    required this.barcodeB,
  });

  BetterSide _hpWinner(int? a, int? b) {
    if (a == null || b == null || a == b) return BetterSide.none;
    return a > b ? BetterSide.a : BetterSide.b;
  }

  Future<void> _share(
    BuildContext context,
    WidgetRef ref,
    ({ProductEntity a, ProductEntity b}) pair,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final imageA = pair.a.imageUrl != null
          ? NetworkImage(pair.a.imageUrl!)
          : null;
      final imageB = pair.b.imageUrl != null
          ? NetworkImage(pair.b.imageUrl!)
          : null;
      // Preload network images so the off-screen capture paints them.
      if (imageA != null) await precacheImage(imageA, context);
      if (context.mounted && imageB != null) {
        await precacheImage(imageB, context);
      }
      if (!context.mounted) return;

      final hpA = pair.a.calculatedHpScore?.round();
      final hpB = pair.b.calculatedHpScore?.round();
      final better = _hpWinner(hpA, hpB);
      final nameA = pair.a.productName ?? pair.a.barcode;
      final nameB = pair.b.productName ?? pair.b.barcode;
      final winnerName = switch (better) {
        BetterSide.a => nameA,
        BetterSide.b => nameB,
        BetterSide.none => null,
      };

      final card = ComparisonShareCard(
        imageA: imageA,
        imageB: imageB,
        nameA: nameA,
        nameB: nameB,
        hpA: hpA,
        hpB: hpB,
        better: better,
        healthierLabel: l10n.shareHealthier,
        footer: l10n.shareCompared,
      );
      final caption = ShareCaption.forComparison(
        nameA: nameA,
        nameB: nameB,
        healthierName: winnerName,
        healthierLabel: l10n.shareHealthier,
        comparedLabel: l10n.shareCompared,
        storeUrl: AppLinks.shareStoreUrl,
      );

      await ref.read(shareServiceProvider).captureAndShare(
        context: context,
        card: card,
        logicalSize: const Size(360, 360),
        pixelRatio: 3.0,
        fileName: 'nutrilens_compare_${pair.a.barcode}_${pair.b.barcode}.png',
        caption: caption,
      );
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(
      comparisonProvider((barcodeA: barcodeA, barcodeB: barcodeB)),
    );

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(l10n.compare),
        backgroundColor: Colors.transparent,
        actions: [
          if (async.asData?.value != null)
            IconButton(
              tooltip: l10n.share,
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () => _share(context, ref, async.asData!.value),
            ),
        ],
      ),
      body: async.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.colors.primary),
        ),
        error: (e, s) {
          debugPrint('[Comparison] load error: $e');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.compareLoadError,
                style: TextStyle(color: context.colors.textMuted),
              ),
            ),
          );
        },
        data: (pair) {
          final rows = comparisonMetrics(pair.a, pair.b);
          return CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _CompareHeaderDelegate(a: pair.a, b: pair.b),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _ComparisonRowTile(row: rows[i]),
                  childCount: rows.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }
}

// ── Sticky two-product header ────────────────────────────────────────────────

class _CompareHeaderDelegate extends SliverPersistentHeaderDelegate {
  final ProductEntity a;
  final ProductEntity b;

  _CompareHeaderDelegate({required this.a, required this.b});

  static const double _height = 184;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colors = context.colors;
    return Container(
      height: _height,
      color: colors.background,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(child: _HeaderCard(product: a)),
          const SizedBox(width: 12),
          Expanded(child: _HeaderCard(product: b)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CompareHeaderDelegate oldDelegate) {
    return oldDelegate.a.barcode != a.barcode ||
        oldDelegate.b.barcode != b.barcode;
  }
}

class _HeaderCard extends StatelessWidget {
  final ProductEntity product;

  const _HeaderCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gauge = ScoreConstants.hpToGauge(product.calculatedHpScore);
    final gaugeColor = colors.gaugeColor(gauge);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: product.imageUrl != null
                ? Image.network(
                    product.imageUrl!,
                    height: 56,
                    width: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, e, s) => _imgPlaceholder(colors),
                  )
                : _imgPlaceholder(colors),
          ),
          const SizedBox(height: 6),
          Text(
            product.productName ?? product.barcode,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
              height: 1.2,
            ),
          ),
          if (product.brands != null && product.brands!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              product.brands!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: colors.textMuted),
            ),
          ],
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: gaugeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$gauge/5',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: gaugeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder(AppColorsExtension colors) {
    return Container(
      height: 56,
      width: 56,
      decoration: BoxDecoration(
        color: colors.surfaceCard2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.image_outlined, size: 24, color: colors.textMuted),
    );
  }
}

// ── One metric row ───────────────────────────────────────────────────────────

class _ComparisonRowTile extends StatelessWidget {
  final ComparisonRow row;

  const _ComparisonRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unit = _unit(row.metric);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _valueCell(
              context,
              display: row.displayA,
              unit: unit,
              isBetter: row.betterSide == BetterSide.a,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              _label(context, row.metric),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: _valueCell(
              context,
              display: row.displayB,
              unit: unit,
              isBetter: row.betterSide == BetterSide.b,
            ),
          ),
        ],
      ),
    );
  }

  Widget _valueCell(
    BuildContext context, {
    required String display,
    required String unit,
    required bool isBetter,
  }) {
    final colors = context.colors;
    // Gauge 1 == best == green; reuse the theme's green for "better".
    final betterColor = colors.gaugeColor(1);
    final text = display == '—' ? display : '$display$unit';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isBetter
            ? betterColor.withValues(alpha: 0.12)
            : colors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isBetter) ...[
            Icon(Icons.check_circle, size: 14, color: betterColor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBetter ? FontWeight.w800 : FontWeight.w600,
                color: isBetter ? betterColor : colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _label(BuildContext c, ComparisonMetric m) {
    final l10n = c.l10n;
    return switch (m) {
      ComparisonMetric.hpScore => l10n.hpScoreLabel,
      ComparisonMetric.energy => l10n.energyValue,
      ComparisonMetric.fat => l10n.fatLabel,
      ComparisonMetric.saturatedFat => l10n.saturatedFatLabel,
      ComparisonMetric.sugar => l10n.sugarLabel,
      ComparisonMetric.salt => l10n.saltLabel,
      ComparisonMetric.protein => l10n.proteinLabel,
      ComparisonMetric.fiber => l10n.fiberLabel,
      ComparisonMetric.nova => l10n.novaGroup,
      ComparisonMetric.additives => l10n.additives,
      ComparisonMetric.nutriScore => l10n.nutriScoreLabel,
    };
  }

  String _unit(ComparisonMetric m) {
    return switch (m) {
      ComparisonMetric.energy => ' kcal',
      ComparisonMetric.fat ||
      ComparisonMetric.saturatedFat ||
      ComparisonMetric.sugar ||
      ComparisonMetric.salt ||
      ComparisonMetric.protein ||
      ComparisonMetric.fiber => ' g',
      _ => '',
    };
  }
}
