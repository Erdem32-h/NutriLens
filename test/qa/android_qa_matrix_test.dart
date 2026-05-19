import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android QA matrix', () {
    late Map<String, dynamic> matrix;

    setUpAll(() {
      final file = File('tools/qa/android_qa_matrix.json');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Android emulator QA needs a machine-readable test matrix.',
      );

      matrix = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    });

    test('covers release-blocking monetization scenarios', () {
      final scenarios = (matrix['scenarios'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final ids = scenarios.map((scenario) => scenario['id']).toSet();

      expect(
        ids,
        containsAll(<String>{
          'free_user_daily_scan_limit',
          'rewarded_ad_bonus_scan',
          'purchase_unlocks_premium',
          'restore_purchase',
          'revenuecat_webhook_delay',
          'offline_premium_fallback',
        }),
      );
    });

    test(
      'defines focused emulator, boundary, security, and performance suites',
      () {
        final suites = (matrix['suites'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        final suiteIds = suites.map((suite) => suite['id']).toSet();

        expect(
          suiteIds,
          containsAll(<String>{
            'emulator_smoke',
            'boundary_regression',
            'security_release',
            'performance_smoke',
          }),
        );
      },
    );

    test('has runnable adb automation entrypoint', () {
      final script = File('scripts/android_qa_smoke.ps1');
      expect(script.existsSync(), isTrue);

      final content = script.readAsStringSync();
      expect(content, contains('adb devices'));
      expect(content, contains('flutter build apk'));
      expect(content, contains('dumpsys gfxinfo'));
      expect(content, contains('logcat'));
      expect(content, contains('NavigateTabs'));
      expect(content, contains('uiautomator dump'));
      expect(content, contains('android.permission.CAMERA'));
      expect(content, contains('qa-summary.json'));
      expect(content, contains('FATAL EXCEPTION'));
    });
  });
}
