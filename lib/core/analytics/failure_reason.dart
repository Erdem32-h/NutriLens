import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Collapses an auth failure into a short, bounded machine code suitable for
/// an analytics prop.
///
/// Raw error strings are never sent: they are unbounded, locale-dependent
/// (so they'd fragment every group-by), and Supabase occasionally embeds the
/// submitted email in the message — which would put user PII in a table that
/// is otherwise entirely anonymous.
String authFailureReason(Object? error) {
  if (error == null) return 'unknown';
  if (error is AuthApiException) {
    final code = error.code;
    // Supabase's own codes are already short and stable; prefer them.
    if (code != null && code.isNotEmpty) return _sanitize(code);
    return 'auth_${error.statusCode ?? 'error'}';
  }
  if (error is AuthRetryableFetchException) return 'network_retryable';
  if (error is SocketException) return 'network';
  if (error is TimeoutException) return 'timeout';

  final text = error.toString().toLowerCase();
  if (text.contains('failed host lookup') ||
      text.contains('socketexception') ||
      text.contains('no address associated')) {
    return 'network';
  }
  if (text.contains('timeout')) return 'timeout';

  // Fall back to the type name. Bounded, locale-independent, and specific
  // enough to separate an AlreadyRegisteredFailure from a ServerFailure —
  // which is exactly the distinction that tells a UX problem from an outage.
  return _sanitize(_snakeCase(error.runtimeType.toString()));
}

String _snakeCase(String input) => input
    .replaceAllMapped(RegExp(r'(?<=[a-z0-9])([A-Z])'), (m) => '_${m[1]}')
    .toLowerCase();

/// Keeps the value inside the server's expectations: lowercase, bounded,
/// no separators that would break a group-by.
String _sanitize(String raw) {
  final cleaned = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  return cleaned.length <= 48 ? cleaned : cleaned.substring(0, 48);
}
