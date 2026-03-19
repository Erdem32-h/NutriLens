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
