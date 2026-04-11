import 'package:flutter_test/flutter_test.dart';

import 'package:nutrilens/core/services/subscription_service.dart';

void main() {
  group('SubscriptionStatus', () {
    group('free constant', () {
      test('is free tier', () {
        expect(SubscriptionStatus.free.tier, SubscriptionTier.free);
      });

      test('isPremium returns false', () {
        expect(SubscriptionStatus.free.isPremium, isFalse);
      });

      test('has no expiry or management URL', () {
        expect(SubscriptionStatus.free.expiresAt, isNull);
        expect(SubscriptionStatus.free.managementUrl, isNull);
      });
    });

    group('premium status', () {
      final expiresAt = DateTime(2027, 1, 1);

      test('isPremium returns true', () {
        final status = SubscriptionStatus(
          tier: SubscriptionTier.premium,
          expiresAt: expiresAt,
          managementUrl: 'https://example.com/manage',
        );
        expect(status.isPremium, isTrue);
      });

      test('stores expiry and management URL', () {
        final status = SubscriptionStatus(
          tier: SubscriptionTier.premium,
          expiresAt: expiresAt,
          managementUrl: 'https://example.com/manage',
        );
        expect(status.expiresAt, expiresAt);
        expect(status.managementUrl, 'https://example.com/manage');
      });

      test('can be created without optional fields', () {
        const status = SubscriptionStatus(tier: SubscriptionTier.premium);
        expect(status.isPremium, isTrue);
        expect(status.expiresAt, isNull);
        expect(status.managementUrl, isNull);
      });
    });

    group('SubscriptionTier', () {
      test('free and premium are distinct values', () {
        expect(SubscriptionTier.free, isNot(SubscriptionTier.premium));
      });

      test('enum has exactly two values', () {
        expect(SubscriptionTier.values.length, 2);
      });
    });
  });
}
