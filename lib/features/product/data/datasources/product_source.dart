import '../../domain/entities/product_entity.dart';

/// Strategy interface for product resolution sources.
/// Each source is tried in priority order (lower = first).
abstract interface class ProductSource {
  String get name;
  int get priority;
  Duration get timeout;

  /// Returns a ProductEntity if found, null if not found.
  /// Should NOT throw — catch errors internally and return null.
  Future<ProductEntity?> resolve(String barcode);
}

class ProductResolveResult {
  final ProductEntity? product;
  final String? resolvedBy;
  final bool hasIngredients;
  final List<String> triedSources;

  const ProductResolveResult({
    this.product,
    this.resolvedBy,
    this.hasIngredients = false,
    this.triedSources = const [],
  });

  bool get isFound => product != null;
}

/// Tries each ProductSource in priority order, returns first successful result.
class ProductResolver {
  final List<ProductSource> _sources;

  ProductResolver(List<ProductSource> sources)
      : _sources = List.of(sources)
          ..sort((a, b) => a.priority.compareTo(b.priority));

  Future<ProductResolveResult> resolve(String barcode) async {
    final triedSources = <String>[];

    for (final source in _sources) {
      triedSources.add(source.name);
      try {
        final product = await source.resolve(barcode).timeout(source.timeout);
        if (product != null) {
          final hasIngredients = product.ingredientsText != null &&
              product.ingredientsText!.isNotEmpty;
          return ProductResolveResult(
            product: product,
            resolvedBy: source.name,
            hasIngredients: hasIngredients,
            triedSources: triedSources,
          );
        }
      } catch (_) {
        // Timeout or error — silently move to next source
        continue;
      }
    }

    return ProductResolveResult(triedSources: triedSources);
  }
}
