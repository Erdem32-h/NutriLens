import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/error/failures.dart';

void main() {
  group('ServerFailure', () {
    test('stores message and statusCode', () {
      const failure = ServerFailure('Server error', statusCode: 500);

      expect(failure.message, 'Server error');
      expect(failure.statusCode, 500);
    });

    test('statusCode defaults to null', () {
      const failure = ServerFailure('Server error');

      expect(failure.statusCode, isNull);
    });

    test('two instances with same props are equal', () {
      const a = ServerFailure('err', statusCode: 404);
      const b = ServerFailure('err', statusCode: 404);

      expect(a, equals(b));
    });

    test('two instances with different props are not equal', () {
      const a = ServerFailure('err', statusCode: 404);
      const b = ServerFailure('err', statusCode: 500);

      expect(a, isNot(equals(b)));
    });

    test('props include message and statusCode', () {
      const failure = ServerFailure('msg', statusCode: 403);

      expect(failure.props, ['msg', 403]);
    });
  });

  group('CacheFailure', () {
    test('stores message', () {
      const failure = CacheFailure('Cache miss');

      expect(failure.message, 'Cache miss');
    });

    test('equality works', () {
      const a = CacheFailure('err');
      const b = CacheFailure('err');

      expect(a, equals(b));
    });
  });

  group('NetworkFailure', () {
    test('has default message', () {
      const failure = NetworkFailure();

      expect(failure.message, 'No internet connection. Please check your network.');
    });

    test('accepts custom message', () {
      const failure = NetworkFailure('Custom network error');

      expect(failure.message, 'Custom network error');
    });
  });

  group('ValidationFailure', () {
    test('stores message', () {
      const failure = ValidationFailure('Invalid input');

      expect(failure.message, 'Invalid input');
    });
  });

  group('NotFoundFailure', () {
    test('has default message', () {
      const failure = NotFoundFailure();

      expect(failure.message, 'Product not found. Try scanning again.');
    });

    test('accepts custom message', () {
      const failure = NotFoundFailure('Custom not found');

      expect(failure.message, 'Custom not found');
    });
  });

  group('RateLimitFailure', () {
    test('has default message', () {
      const failure = RateLimitFailure();

      expect(failure.message, 'Too many requests. Please wait a moment.');
    });

    test('accepts custom message', () {
      const failure = RateLimitFailure('Slow down');

      expect(failure.message, 'Slow down');
    });
  });

  group('AuthFailure', () {
    test('stores message', () {
      const failure = AuthFailure('Invalid credentials');

      expect(failure.message, 'Invalid credentials');
    });
  });

  group('Failure sealed class hierarchy', () {
    test('all subclasses are Failure instances', () {
      const failures = <Failure>[
        ServerFailure('a'),
        CacheFailure('b'),
        NetworkFailure(),
        ValidationFailure('c'),
        NotFoundFailure(),
        RateLimitFailure(),
        AuthFailure('d'),
      ];

      for (final f in failures) {
        expect(f, isA<Failure>());
      }
    });

    test('different types with same message are not equal', () {
      const cache = CacheFailure('error');
      const validation = ValidationFailure('error');

      expect(cache, isNot(equals(validation)));
    });
  });
}
