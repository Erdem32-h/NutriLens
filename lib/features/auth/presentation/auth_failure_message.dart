import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthWeakPasswordException;

import '../../../core/analytics/failure_reason.dart';
import '../../../core/error/failures.dart';
import '../../../l10n/generated/app_localizations.dart';

/// The one place an auth error becomes text a person reads.
///
/// Accepts a [Failure] or a raw Supabase exception. Classification reuses
/// [authFailureReason], so the message a user sees and the reason the funnel
/// records can never disagree. Supabase's own English sentence is never shown:
/// it is untranslated and, for some errors, quotes back the submitted email.
String authFailureMessage(AppLocalizations l10n, Object? error) {
  if (isWeakPasswordFailure(error)) {
    return _weakPasswordReasons(error).contains('pwned')
        ? l10n.authErrorPasswordPwned
        : l10n.authErrorPasswordWeak;
  }
  return switch (authFailureReason(error)) {
    'invalid_credentials' => l10n.authErrorInvalidCredentials,
    'email_not_confirmed' => l10n.authErrorEmailNotConfirmed,
    'email_address_invalid' => l10n.validEmail,
    'user_already_exists' ||
    'email_exists' ||
    'already_registered_failure' => l10n.emailAlreadyRegistered,
    'same_password' => l10n.authErrorSamePassword,
    'over_email_send_rate_limit' ||
    'over_request_rate_limit' ||
    'rate_limit_failure' => l10n.authErrorRateLimited,
    'network' ||
    'network_retryable' ||
    'network_failure' ||
    'timeout' => l10n.authErrorNetwork,
    'native_sign_in_failure' => l10n.authErrorAppleSignIn,
    _ => l10n.authErrorGeneric,
  };
}

/// Whether Supabase rejected the password itself — the form shows these on
/// the password field rather than in a snackbar that is gone in seconds.
bool isWeakPasswordFailure(Object? error) =>
    authFailureReason(error) == 'weak_password';

List<String> _weakPasswordReasons(Object? error) => switch (error) {
  AuthFailure(:final reasons) => reasons,
  AuthWeakPasswordException(:final reasons) => reasons,
  _ => const [],
};
