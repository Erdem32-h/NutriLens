class ServerException implements Exception {
  final String message;
  final int? statusCode;

  const ServerException(this.message, {this.statusCode});

  @override
  String toString() => 'ServerException: $message (status: $statusCode)';
}

class CacheException implements Exception {
  final String message;

  const CacheException(this.message);

  @override
  String toString() => 'CacheException: $message';
}

class NetworkException implements Exception {
  final String message;

  const NetworkException([this.message = 'No internet connection']);

  @override
  String toString() => 'NetworkException: $message';
}

class NotFoundException implements Exception {
  final String message;

  const NotFoundException([this.message = 'Resource not found']);

  @override
  String toString() => 'NotFoundException: $message';
}

/// Thrown when a signup targets an email that already has a confirmed
/// account. Supabase's email-enumeration protection returns 200 with an
/// obfuscated user (`identities == []`) instead of an error, so this has
/// to be detected client-side and surfaced explicitly.
class EmailAlreadyRegisteredException implements Exception {
  final String message;

  const EmailAlreadyRegisteredException([
    this.message = 'This email is already registered',
  ]);

  @override
  String toString() => 'EmailAlreadyRegisteredException: $message';
}

class RateLimitException implements Exception {
  final String message;

  const RateLimitException([this.message = 'Rate limit exceeded']);

  @override
  String toString() => 'RateLimitException: $message';
}
