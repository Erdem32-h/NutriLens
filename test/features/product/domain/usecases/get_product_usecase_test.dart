import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/core/error/failures.dart';
import 'package:nutrilens/features/product/domain/entities/product_entity.dart';
import 'package:nutrilens/features/product/domain/repositories/product_repository.dart';
import 'package:nutrilens/features/product/domain/usecases/get_product_usecase.dart';

class MockProductRepository extends Mock implements ProductRepository {}

void main() {
  late GetProductUseCase useCase;
  late MockProductRepository mockRepository;

  setUp(() {
    mockRepository = MockProductRepository();
    useCase = GetProductUseCase(mockRepository);
  });

  const product = ProductEntity(
    barcode: '8690000000001',
    productName: 'Test Product',
  );

  group('GetProductUseCase', () {
    test('returns ValidationFailure when barcode is empty', () async {
      final result = await useCase('');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(failure.message, 'Barcode cannot be empty');
        },
        (_) => fail('Expected Left'),
      );
      verifyNever(() => mockRepository.getProduct(any()));
    });

    test('delegates to repository when barcode is valid', () async {
      when(() => mockRepository.getProduct('8690000000001'))
          .thenAnswer((_) async => const Right(product));

      final result = await useCase('8690000000001');

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (entity) => expect(entity, product),
      );
      verify(() => mockRepository.getProduct('8690000000001')).called(1);
    });

    test('returns failure from repository on error', () async {
      when(() => mockRepository.getProduct('unknown'))
          .thenAnswer((_) async => const Left(NotFoundFailure()));

      final result = await useCase('unknown');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<NotFoundFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test('returns NetworkFailure from repository', () async {
      when(() => mockRepository.getProduct('123'))
          .thenAnswer((_) async => const Left(NetworkFailure()));

      final result = await useCase('123');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test('returns ServerFailure from repository', () async {
      when(() => mockRepository.getProduct('123')).thenAnswer(
        (_) async => const Left(ServerFailure('Internal error', statusCode: 500)),
      );

      final result = await useCase('123');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect((failure as ServerFailure).statusCode, 500);
        },
        (_) => fail('Expected Left'),
      );
    });
  });
}
