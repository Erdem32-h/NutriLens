import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../product/domain/entities/product_entity.dart';
import '../../../product/presentation/providers/product_provider.dart';

/// Resolves both products for the compare screen by reusing the existing
/// `productByBarcodeProvider` (community → OFF → barcode lookup + HP enrich).
/// Throws when either product can't be resolved so the screen shows an error.
final comparisonProvider = FutureProvider.family<
    ({ProductEntity a, ProductEntity b}),
    ({String barcodeA, String barcodeB})>((ref, args) async {
  final a = await ref.watch(productByBarcodeProvider(args.barcodeA).future);
  final b = await ref.watch(productByBarcodeProvider(args.barcodeB).future);
  if (a == null || b == null) {
    throw Exception('comparison: product not resolved');
  }
  return (a: a, b: b);
});
