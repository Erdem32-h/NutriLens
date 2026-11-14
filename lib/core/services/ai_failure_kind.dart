import 'package:nutrilens/l10n/generated/app_localizations.dart';

import 'gemini_ai_service.dart' show GeminiServiceException;

/// Why a call to the AI proxy failed, as far as the user is concerned.
enum AiFailureKind {
  /// HTTP 429: the proxy's quota, or the provider out of credit / rate limited.
  quota,

  /// No HTTP status at all: the request never got a reply (offline, DNS,
  /// dropped socket). The service is not what failed.
  network,

  /// Any other status: the proxy or the model failed.
  service;

  factory AiFailureKind.of(GeminiServiceException e) => switch (e.statusCode) {
    429 => AiFailureKind.quota,
    null => AiFailureKind.network,
    _ => AiFailureKind.service,
  };

  /// The message to show the user for this failure.
  String message(AppLocalizations l10n) => switch (this) {
    AiFailureKind.quota => l10n.aiQuotaExhausted,
    AiFailureKind.network => l10n.aiNetworkError,
    AiFailureKind.service => l10n.aiServiceUnavailableNoFallback,
  };
}
