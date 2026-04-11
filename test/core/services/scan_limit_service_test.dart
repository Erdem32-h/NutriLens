import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nutrilens/core/services/scan_limit_service.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

void main() {
  group('ScanCheckResult', () {
    group('fromJson', () {
      test('parses allowed free scan', () {
        final result = ScanCheckResult.fromJson({
          'allowed': true,
          'remaining': 1,
          'is_premium': false,
        });
        expect(result.allowed, isTrue);
        expect(result.remaining, 1);
        expect(result.isPremium, isFalse);
      });

      test('parses denied scan', () {
        final result = ScanCheckResult.fromJson({
          'allowed': false,
          'remaining': 0,
          'is_premium': false,
        });
        expect(result.allowed, isFalse);
        expect(result.remaining, 0);
        expect(result.isPremium, isFalse);
      });

      test('parses premium scan (unlimited)', () {
        final result = ScanCheckResult.fromJson({
          'allowed': true,
          'remaining': -1,
          'is_premium': true,
        });
        expect(result.allowed, isTrue);
        expect(result.remaining, -1);
        expect(result.isPremium, isTrue);
      });

      test('uses defaults for missing fields', () {
        final result = ScanCheckResult.fromJson({});
        expect(result.allowed, isFalse);
        expect(result.remaining, 0);
        expect(result.isPremium, isFalse);
      });
    });

    test('unlimited sentinel is always allowed and premium', () {
      expect(ScanCheckResult.unlimited.allowed, isTrue);
      expect(ScanCheckResult.unlimited.remaining, -1);
      expect(ScanCheckResult.unlimited.isPremium, isTrue);
    });
  });

  group('BonusScanResult', () {
    group('fromJson', () {
      test('parses granted bonus', () {
        final result = BonusScanResult.fromJson({
          'granted': true,
          'bonus_remaining': 2,
        });
        expect(result.granted, isTrue);
        expect(result.bonusRemaining, 2);
        expect(result.reason, isNull);
      });

      test('parses max_bonus_reached denial', () {
        final result = BonusScanResult.fromJson({
          'granted': false,
          'bonus_remaining': 0,
          'reason': 'max_bonus_reached',
        });
        expect(result.granted, isFalse);
        expect(result.reason, 'max_bonus_reached');
      });

      test('uses defaults for missing fields', () {
        final result = BonusScanResult.fromJson({});
        expect(result.granted, isFalse);
        expect(result.bonusRemaining, 0);
        expect(result.reason, isNull);
      });
    });
  });

  group('ScanLimitService', () {
    late MockSupabaseClient mockClient;
    late MockGoTrueClient mockAuth;
    late ScanLimitService service;

    setUp(() {
      mockClient = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      when(() => mockClient.auth).thenReturn(mockAuth);
      service = ScanLimitService(mockClient);
    });

    group('checkAndIncrement', () {
      test('returns denied immediately when user is not authenticated', () async {
        when(() => mockAuth.currentUser).thenReturn(null);

        final result = await service.checkAndIncrement();

        expect(result.allowed, isFalse);
        expect(result.remaining, 0);
        expect(result.isPremium, isFalse);
        verifyNever(() => mockClient.rpc(any(), params: any(named: 'params')));
      });

      test('returns unlimited fallback when RPC throws', () async {
        final mockUser = MockUser();
        when(() => mockAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.id).thenReturn('user-123');
        when(() => mockClient.rpc(
              'check_and_increment_scan',
              params: any(named: 'params'),
            )).thenThrow(Exception('network error'));

        final result = await service.checkAndIncrement();

        expect(result.allowed, isTrue);
        expect(result.isPremium, isTrue);
        expect(result.remaining, -1);
      });
    });

    group('grantBonusScan', () {
      test('returns not_authenticated when user is not logged in', () async {
        when(() => mockAuth.currentUser).thenReturn(null);

        final result = await service.grantBonusScan();

        expect(result.granted, isFalse);
        expect(result.reason, 'not_authenticated');
        verifyNever(() => mockClient.rpc(any(), params: any(named: 'params')));
      });

      test('returns network_error when RPC throws', () async {
        final mockUser = MockUser();
        when(() => mockAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.id).thenReturn('user-123');
        when(() => mockClient.rpc(
              'grant_bonus_scan',
              params: any(named: 'params'),
            )).thenThrow(Exception('network error'));

        final result = await service.grantBonusScan();

        expect(result.granted, isFalse);
        expect(result.reason, 'network_error');
      });
    });
  });
}
