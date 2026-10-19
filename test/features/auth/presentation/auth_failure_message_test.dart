import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/error/failures.dart';
import 'package:nutrilens/features/auth/presentation/auth_failure_message.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  String message(Object? error) => authFailureMessage(l10n, error);

  group('authFailureMessage', () {
    test('a breached password says so instead of a generic error', () {
      expect(
        message(
          const AuthFailure(
            'Password is known to be weak and easy to guess',
            code: 'weak_password',
            reasons: ['pwned'],
          ),
        ),
        l10n.authErrorPasswordPwned,
      );
    });

    test('any other weak password names the rule', () {
      expect(
        message(
          const AuthFailure('weak', code: 'weak_password', reasons: ['length']),
        ),
        l10n.authErrorPasswordWeak,
      );
    });

    test('maps Supabase codes to localized text', () {
      expect(
        message(const AuthFailure('x', code: 'invalid_credentials')),
        l10n.authErrorInvalidCredentials,
      );
      expect(
        message(const AuthFailure('x', code: 'email_not_confirmed')),
        l10n.authErrorEmailNotConfirmed,
      );
      expect(
        message(const AuthFailure('x', code: 'over_email_send_rate_limit')),
        l10n.authErrorRateLimited,
      );
      expect(
        message(const AuthFailure('x', code: 'same_password')),
        l10n.authErrorSamePassword,
      );
      expect(
        message(const AuthFailure('x', code: 'user_already_exists')),
        l10n.emailAlreadyRegistered,
      );
    });

    test('reads raw Supabase exceptions too', () {
      expect(
        message(AuthApiException('x', code: 'invalid_credentials')),
        l10n.authErrorInvalidCredentials,
      );
      expect(
        message(
          AuthWeakPasswordException(
            message: 'weak',
            statusCode: '422',
            reasons: ['pwned'],
          ),
        ),
        l10n.authErrorPasswordPwned,
      );
    });

    test('connection problems get the connection message', () {
      expect(message(const NetworkFailure()), l10n.authErrorNetwork);
      expect(
        message(const ServerFailure('SocketException: Failed host lookup')),
        l10n.authErrorNetwork,
      );
      expect(
        message(const SocketException('Failed host lookup')),
        l10n.authErrorNetwork,
      );
    });

    test('a failing Apple sheet points at the device setting', () {
      expect(
        message(const NativeSignInFailure('unknown')),
        l10n.authErrorAppleSignIn,
      );
    });

    test('never shows the raw server text', () {
      const raw = 'Database error saving new user';
      final shown = message(const ServerFailure(raw));
      expect(shown, l10n.authErrorGeneric);
      expect(shown, isNot(contains(raw)));
    });
  });

  group('isWeakPasswordFailure', () {
    test('recognises the weak password code only', () {
      expect(
        isWeakPasswordFailure(const AuthFailure('x', code: 'weak_password')),
        isTrue,
      );
      expect(
        isWeakPasswordFailure(
          const AuthFailure('x', code: 'invalid_credentials'),
        ),
        isFalse,
      );
      expect(isWeakPasswordFailure(null), isFalse);
    });
  });
}
