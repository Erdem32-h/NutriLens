import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../product/domain/entities/product_entity.dart';
import '../../../product/presentation/providers/product_provider.dart';

/// Resolves both products for the compare screen by reusing the existing
/// `productByBarcodeProvider` (community → OFF → barcode lookup + HP enrich).
/// Throws when either product can't be resolved so the screen shows an error.
final comparisonProvider = FutureProvider.family<
    ({ProductEntity a, ProductEntity b}),
    ({String barcodeA, String barcodeB})>((ref, args) async {
  // One-shot snapshot: read (not watch) both lookups so this comparison
  // doesn't churn-rebuild as each product provider transitions loading→data.
  // Both futures are kicked off before awaiting so they resolve concurrently.
  final aFuture = ref.read(productByBarcodeProvider(args.barcodeA).future);
  final bFuture = ref.read(productByBarcodeProvider(args.barcodeB).future);
  final a = await aFuture;
  final b = await bFuture;
  if (a == null || b == null) {
    throw Exception('comparison: product not resolved');
  }
  return (a: a, b: b);
});
