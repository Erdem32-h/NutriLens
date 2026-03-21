import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/error/exceptions.dart';

void main() {
  group('ServerException', () {
    test('stores message and statusCode', () {
      const exception = ServerException('Server error', statusCode: 500);

      expect(exception.message, 'Server error');
      expect(exception.statusCode, 500);
    });

    test('statusCode defaults to null', () {
      const exception = ServerException('Server error');

      expect(exception.statusCode, isNull);
    });

    test('toString includes message and statusCode', () {
      const exception = ServerException('fail', statusCode: 503);

      expect(exception.toString(), 'ServerException: fail (status: 503)');
    });

    test('toString with null statusCode', () {
      const exception = ServerException('fail');

      expect(exception.toString(), 'ServerException: fail (status: null)');
    });
  });

  group('CacheException', () {
    test('stores message', () {
      const exception = CacheException('Cache error');

      expect(exception.message, 'Cache error');
    });

    test('toString includes message', () {
      const exception = CacheException('read failed');

      expect(exception.toString(), 'CacheException: read failed');
    });
  });

  group('NetworkException', () {
    test('has default message', () {
      const exception = NetworkException();

      expect(exception.message, 'No internet connection');
    });

    test('accepts custom message', () {
      const exception = NetworkException('Timeout');

      expect(exception.message, 'Timeout');
    });

    test('toString includes message', () {
      const exception = NetworkException('Timeout');

      expect(exception.toString(), 'NetworkException: Timeout');
    });
  });

  group('NotFoundException', () {
    test('has default message', () {
      const exception = NotFoundException();

      expect(exception.message, 'Resource not found');
    });

    test('accepts custom message', () {
      const exception = NotFoundException('Product missing');

      expect(exception.message, 'Product missing');
    });

    test('toString includes message', () {
      const exception = NotFoundException();

      expect(exception.toString(), 'NotFoundException: Resource not found');
    });
  });

  group('RateLimitException', () {
    test('has default message', () {
      const exception = RateLimitException();

      expect(exception.message, 'Rate limit exceeded');
    });

    test('accepts custom message', () {
      const exception = RateLimitException('Too fast');

      expect(exception.message, 'Too fast');
    });

    test('toString includes message', () {
      const exception = RateLimitException();

      expect(exception.toString(), 'RateLimitException: Rate limit exceeded');
    });
  });

  group('All exceptions implement Exception', () {
    test('every custom exception is an Exception', () {
      const exceptions = <Exception>[
        ServerException('a'),
        CacheException('b'),
        NetworkException(),
        NotFoundException(),
        RateLimitException(),
      ];

      for (final e in exceptions) {
        expect(e, isA<Exception>());
      }
    });
  });
}
