import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

final class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure(String message, {this.statusCode}) : super(message);

  @override
  List<Object?> get props => [message, statusCode];
}

final class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

final class NetworkFailure extends Failure {
  const NetworkFailure([
    String message = 'No internet connection. Please check your network.',
  ]) : super(message);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure([
    String message = 'Product not found. Try scanning again.',
  ]) : super(message);
}

final class RateLimitFailure extends Failure {
  const RateLimitFailure([
    String message = 'Too many requests. Please wait a moment.',
  ]) : super(message);
}

/// [message] is Supabase's English text — for logs only. UI layers map
/// [code] (e.g. `weak_password`, `invalid_credentials`) to localized text.
final class AuthFailure extends Failure {
  final String? code;

  /// Why a `weak_password` was rejected: `length`, `characters`, `pwned`.
  final List<String> reasons;

  const AuthFailure(super.message, {this.code, this.reasons = const []});

  @override
  List<Object?> get props => [message, code, reasons];
}

/// Signup attempted with an email that already has a confirmed account.
/// Message here is an English fallback — UI layers should map this type
/// to a localized string instead of rendering [message] directly.
final class AlreadyRegisteredFailure extends Failure {
  const AlreadyRegisteredFailure([
    String message =
        "This email is already registered — try signing in or 'Forgot password'.",
  ]) : super(message);
}

/// A native sign-in sheet failed before reaching our server. [code] is the
/// platform's error code; analytics reports it as the event's `detail`.
final class NativeSignInFailure extends Failure {
  final String code;

  const NativeSignInFailure(this.code) : super('Sign-in failed ($code).');

  @override
  List<Object?> get props => [message, code];
}

/// The user closed a native sign-in sheet without finishing. Nothing to show
/// them; it exists so analytics reports `sign_in_cancelled_failure` instead of
/// lumping it in with real failures.
final class SignInCancelledFailure extends Failure {
  const SignInCancelledFailure([super.message = 'Sign-in cancelled.']);
}
