import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/analytics/failure_reason.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _AlreadyRegisteredFailure implements Exception {}

void main() {
  group('authFailureReason', () {
    test('prefers the Supabase error code', () {
      final reason = authFailureReason(
        AuthApiException(
          'Invalid login credentials',
          code: 'invalid_credentials',
        ),
      );
      expect(reason, 'invalid_credentials');
    });

    test('collapses network failures to one bucket', () {
      expect(
        authFailureReason(const SocketException('Failed host lookup')),
        'network',
      );
      expect(
        authFailureReason(AuthRetryableFetchException(message: 'boom')),
        'network_retryable',
      );
    });

    test('maps timeouts', () {
      expect(authFailureReason(TimeoutException('slow')), 'timeout');
    });

    test('falls back to a snake_cased type name', () {
      expect(
        authFailureReason(_AlreadyRegisteredFailure()),
        '_already_registered_failure',
      );
    });

    test('handles a missing error', () {
      expect(authFailureReason(null), 'unknown');
    });

    test('never leaks the raw message', () {
      // Supabase sometimes embeds the submitted address in the message; the
      // funnel table is otherwise entirely free of PII and must stay that way.
      final reason = authFailureReason(
        AuthApiException('User user@example.com already registered'),
      );
      expect(reason, isNot(contains('@')));
      expect(reason, isNot(contains('example')));
    });

    test('bounds the length of whatever it returns', () {
      final reason = authFailureReason(AuthApiException('x', code: 'a' * 200));
      expect(reason.length, lessThanOrEqualTo(48));
    });
  });
}
