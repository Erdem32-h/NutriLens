import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/services/ai_failure_kind.dart';
import 'package:nutrilens/core/services/gemini_ai_service.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

void main() {
  GeminiServiceException ex(int? status) =>
      GeminiServiceException('boom', statusCode: status);

  group('AiFailureKind.of', () {
    test('429 is quota', () {
      expect(AiFailureKind.of(ex(429)), AiFailureKind.quota);
    });

    test('no status is network', () {
      expect(AiFailureKind.of(ex(null)), AiFailureKind.network);
    });

    for (final status in [401, 408, 422, 500, 502, 503]) {
      test('$status is service', () {
        expect(AiFailureKind.of(ex(status)), AiFailureKind.service);
      });
    }
  });

  test('enum names are the analytics reason strings', () {
    // food_result_screen sends kind.name as meal_analysis_failed.reason;
    // renaming a value would silently change dashboards.
    expect(AiFailureKind.quota.name, 'quota');
    expect(AiFailureKind.network.name, 'network');
    expect(AiFailureKind.service.name, 'service');
  });

  for (final code in ['tr', 'en']) {
    test('messages ($code) map to the right strings and differ', () {
      final l10n = lookupAppLocalizations(Locale(code));
      final quota = AiFailureKind.quota.message(l10n);
      final network = AiFailureKind.network.message(l10n);
      final service = AiFailureKind.service.message(l10n);

      expect(quota, l10n.aiQuotaExhausted);
      expect(network, l10n.aiNetworkError);
      expect(service, l10n.aiServiceUnavailableNoFallback);
      expect({quota, network, service}.length, 3);
    });
  }
}
