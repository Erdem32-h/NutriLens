import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/comparison/presentation/providers/comparison_provider.dart';
import 'package:nutrilens/features/product/domain/entities/product_entity.dart';
import 'package:nutrilens/features/product/presentation/providers/product_provider.dart';

void main() {
  ProductEntity prod(String barcode) =>
      ProductEntity(barcode: barcode, productName: barcode);

  ProviderContainer makeContainer(ProductEntity? Function(String) resolve) {
    return ProviderContainer(
      overrides: [
        productByBarcodeProvider.overrideWith(
          (ref, barcode) async => resolve(barcode),
        ),
      ],
    );
  }

  test('resolves both products when both barcodes exist', () async {
    final container = makeContainer((b) => prod(b));
    addTearDown(container.dispose);
    final provider = comparisonProvider((
      barcodeA: 'milk-a',
      barcodeB: 'milk-b',
    ));
    // Retain the provider so it isn't disposed mid-load.
    container.listen(provider, (_, __) {});

    final result = await container.read(provider.future);

    expect(result.a.barcode, 'milk-a');
    expect(result.b.barcode, 'milk-b');
  });

  test('surfaces an error when one product cannot be resolved', () async {
    final container = makeContainer((b) => b == 'known' ? prod('known') : null);
    addTearDown(container.dispose);
    final provider = comparisonProvider((
      barcodeA: 'known',
      barcodeB: 'missing',
    ));

    // Consume it the way the screen does — via the AsyncValue state.
    final states = <AsyncValue<({ProductEntity a, ProductEntity b})>>[];
    container.listen(
      provider,
      (_, next) => states.add(next),
      fireImmediately: true,
    );

    // Let the async build settle.
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(states.last.hasError, isTrue);
    expect(states.last.error.toString(), contains('not resolved'));
  });
}
