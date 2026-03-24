import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/core/error/exceptions.dart';
import 'package:nutrilens/core/error/failures.dart';
import 'package:nutrilens/core/network/network_info.dart';
import 'package:nutrilens/features/product/data/datasources/product_local_datasource.dart';
import 'package:nutrilens/features/product/data/datasources/product_source.dart';
import 'package:nutrilens/features/product/data/repositories/product_repository_impl.dart';
import 'package:nutrilens/features/product/domain/entities/product_entity.dart';

class MockProductResolver extends Mock implements ProductResolver {}

class MockProductLocalDataSource extends Mock
    implements ProductLocalDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

class FakeProductEntity extends Fake implements ProductEntity {}

void main() {
  late ProductRepositoryImpl repository;
  late MockProductResolver mockResolver;
  late MockProductLocalDataSource mockLocal;
  late MockNetworkInfo mockNetwork;

  setUpAll(() {
    registerFallbackValue(FakeProductEntity());
  });

  setUp(() {
    mockResolver = MockProductResolver();
    mockLocal = MockProductLocalDataSource();
    mockNetwork = MockNetworkInfo();
    repository = ProductRepositoryImpl(
      resolver: mockResolver,
      localDataSource: mockLocal,
      networkInfo: mockNetwork,
    );
  });

  const product = ProductEntity(
    barcode: '8690000000001',
    productName: 'Test Product',
  );

  const staleProduct = ProductEntity(
    barcode: '8690000000001',
    productName: 'Stale Product',
  );

  group('getProduct', () {
    group('when fresh cache exists', () {
      test('returns cached product without remote call', () async {
        when(() => mockLocal.getProduct('8690000000001'))
            .thenAnswer((_) async => product);
        when(() => mockLocal.isStale('8690000000001'))
            .thenAnswer((_) async => false);

        final result = await repository.getProduct('8690000000001');

        expect(result, const Right(product));
        verifyNever(() => mockResolver.resolve(any()));
        verifyNever(() => mockNetwork.isConnected);
      });
    });

    group('when stale cache exists', () {
      setUp(() {
        when(() => mockLocal.getProduct('8690000000001'))
            .thenAnswer((_) async => staleProduct);
        when(() => mockLocal.isStale('8690000000001'))
            .thenAnswer((_) async => true);
      });

      test('fetches from resolver when online', () async {
        when(() => mockNetwork.isConnected).thenAnswer((_) async => true);
        when(() => mockResolver.resolve('8690000000001'))
            .thenAnswer((_) async => ProductResolveResult(
                  product: product,
                  resolvedBy: 'off',
                  triedSources: ['community', 'off'],
                ));
        when(() => mockLocal.cacheProduct(any()))
            .thenAnswer((_) async {});

        final result = await repository.getProduct('8690000000001');

        expect(result, const Right(product));
        verify(() => mockLocal.cacheProduct(product)).called(1);
      });

      test('returns stale cache when offline', () async {
        when(() => mockNetwork.isConnected).thenAnswer((_) async => false);

        final result = await repository.getProduct('8690000000001');

        expect(result, const Right(staleProduct));
        verifyNever(() => mockResolver.resolve(any()));
      });

      test('returns stale cache when resolver finds nothing', () async {
        when(() => mockNetwork.isConnected).thenAnswer((_) async => true);
        when(() => mockResolver.resolve('8690000000001'))
            .thenAnswer((_) async => ProductResolveResult(
                  product: null,
                  resolvedBy: null,
                  triedSources: ['community', 'off', 'upcitemdb'],
                ));

        final result = await repository.getProduct('8690000000001');

        expect(result, const Right(staleProduct));
      });

      test('returns stale cache on resolver exception', () async {
        when(() => mockNetwork.isConnected).thenAnswer((_) async => true);
        when(() => mockResolver.resolve('8690000000001'))
            .thenThrow(Exception('Network error'));

        final result = await repository.getProduct('8690000000001');

        expect(result, const Right(staleProduct));
      });
    });

    group('when no cache exists', () {
      setUp(() {
        when(() => mockLocal.getProduct('8690000000001'))
            .thenAnswer((_) async => null);
      });

      test('resolves from sources and caches when online', () async {
        when(() => mockNetwork.isConnected).thenAnswer((_) async => true);
        when(() => mockResolver.resolve('8690000000001'))
            .thenAnswer((_) async => ProductResolveResult(
                  product: product,
                  resolvedBy: 'off',
                  triedSources: ['community', 'off'],
                ));
        when(() => mockLocal.cacheProduct(any()))
            .thenAnswer((_) async {});

        final result = await repository.getProduct('8690000000001');

        expect(result, const Right(product));
        verify(() => mockLocal.cacheProduct(product)).called(1);
      });

      test('returns NetworkFailure when offline', () async {
        when(() => mockNetwork.isConnected).thenAnswer((_) async => false);

        final result = await repository.getProduct('8690000000001');

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<NetworkFailure>()),
          (_) => fail('Expected Left'),
        );
      });

      test('returns NotFoundFailure when resolver finds nothing', () async {
        when(() => mockNetwork.isConnected).thenAnswer((_) async => true);
        when(() => mockResolver.resolve('8690000000001'))
            .thenAnswer((_) async => ProductResolveResult(
                  product: null,
                  resolvedBy: null,
                  triedSources: ['community', 'off', 'upcitemdb'],
                ));

        final result = await repository.getProduct('8690000000001');

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<NotFoundFailure>()),
          (_) => fail('Expected Left'),
        );
      });

      test('returns ServerFailure on unexpected exception', () async {
        when(() => mockNetwork.isConnected).thenAnswer((_) async => true);
        when(() => mockResolver.resolve('8690000000001'))
            .thenThrow(Exception('Unknown'));

        final result = await repository.getProduct('8690000000001');

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) {
            expect(failure, isA<ServerFailure>());
            expect(failure.message, contains('Unexpected error'));
          },
          (_) => fail('Expected Left'),
        );
      });
    });

    group('when cache read throws CacheException', () {
      test('falls through to resolver', () async {
        when(() => mockLocal.getProduct('8690000000001'))
            .thenThrow(const CacheException('DB error'));
        when(() => mockNetwork.isConnected).thenAnswer((_) async => true);
        when(() => mockResolver.resolve('8690000000001'))
            .thenAnswer((_) async => ProductResolveResult(
                  product: product,
                  resolvedBy: 'off',
                  triedSources: ['community', 'off'],
                ));
        when(() => mockLocal.cacheProduct(any()))
            .thenAnswer((_) async {});

        final result = await repository.getProduct('8690000000001');

        expect(result, const Right(product));
      });
    });
  });

  group('cacheProduct', () {
    test('returns Right(null) on success', () async {
      when(() => mockLocal.cacheProduct(product))
          .thenAnswer((_) async {});

      final result = await repository.cacheProduct(product);

      expect(result, const Right(null));
    });

    test('returns CacheFailure on CacheException', () async {
      when(() => mockLocal.cacheProduct(product))
          .thenThrow(const CacheException('Write failed'));

      final result = await repository.cacheProduct(product);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<CacheFailure>());
          expect(failure.message, 'Write failed');
        },
        (_) => fail('Expected Left'),
      );
    });
  });

  group('getCachedProduct', () {
    test('returns product when found in cache', () async {
      when(() => mockLocal.getProduct('8690000000001'))
          .thenAnswer((_) async => product);

      final result = await repository.getCachedProduct('8690000000001');

      expect(result, const Right(product));
    });

    test('returns NotFoundFailure when not in cache', () async {
      when(() => mockLocal.getProduct('8690000000001'))
          .thenAnswer((_) async => null);

      final result = await repository.getCachedProduct('8690000000001');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<NotFoundFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test('returns CacheFailure on CacheException', () async {
      when(() => mockLocal.getProduct('8690000000001'))
          .thenThrow(const CacheException('Read error'));

      final result = await repository.getCachedProduct('8690000000001');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<CacheFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });
}
