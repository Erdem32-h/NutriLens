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

final class AuthFailure extends Failure {
  const AuthFailure(super.message);
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

/// The user closed a native sign-in sheet without finishing. Nothing to show
/// them; it exists so analytics reports `sign_in_cancelled_failure` instead of
/// lumping it in with real failures.
final class SignInCancelledFailure extends Failure {
  const SignInCancelledFailure([super.message = 'Sign-in cancelled.']);
}
