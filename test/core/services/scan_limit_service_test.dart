import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nutrilens/core/services/scan_limit_service.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

/// Puts a signed-in user behind the client so the RPC is actually attempted.
void _authenticate(MockGoTrueClient auth) {
  final user = MockUser();
  when(() => auth.currentUser).thenReturn(user);
  when(() => user.id).thenReturn('user-123');
}

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
      test(
        'returns unlimited immediately when local premium is already known',
        () async {
          final result = await service.checkAndIncrement(localPremium: true);

          expect(result.allowed, isTrue);
          expect(result.remaining, -1);
          expect(result.isPremium, isTrue);
          verifyNever(() => mockClient.auth);
          verifyNever(
            () => mockClient.rpc(any(), params: any(named: 'params')),
          );
        },
      );

      test(
        'returns denied immediately when user is not authenticated',
        () async {
          when(() => mockAuth.currentUser).thenReturn(null);

          final result = await service.checkAndIncrement();

          expect(result.allowed, isFalse);
          expect(result.remaining, 0);
          expect(result.isPremium, isFalse);
          verifyNever(
            () => mockClient.rpc(any(), params: any(named: 'params')),
          );
        },
      );

      test('returns networkBlocked fallback when RPC throws', () async {
        _authenticate(mockAuth);
        when(
          () => mockClient.rpc(
            'check_and_increment_scan',
            params: any(named: 'params'),
          ),
        ).thenThrow(Exception('network error'));

        final result = await service.checkAndIncrement();

        expect(result.allowed, isFalse);
        expect(result.isPremium, isFalse);
        expect(result.remaining, 0);
        expect(result.reason, 'network_error');
      });

      test('a transport failure is not retried and reports its own cause',
          () async {
        _authenticate(mockAuth);
        when(
          () => mockClient.rpc(
            'check_and_increment_scan',
            params: any(named: 'params'),
          ),
        ).thenThrow(const SocketException('Failed host lookup'));

        final result = await service.checkAndIncrement();

        expect(result.reason, 'network_error');
        // `detail` is what separates a real outage from the auth rollover
        // that used to wear the same "check your internet" message.
        expect(result.detail, 'network');
        verifyNever(() => mockAuth.refreshSession());
        verify(
          () => mockClient.rpc(
            'check_and_increment_scan',
            params: any(named: 'params'),
          ),
        ).called(1);
      });

      test('an expired JWT refreshes the session and retries once', () async {
        _authenticate(mockAuth);
        when(() => mockAuth.refreshSession()).thenAnswer(
          (_) async => AuthResponse(),
        );
        // Both attempts throw so the assertion can stay on the observable
        // behaviour: `rpc` returns a PostgrestFilterBuilder, which cannot be
        // faked convincingly enough to return a success payload.
        when(
          () => mockClient.rpc(
            'check_and_increment_scan',
            params: any(named: 'params'),
          ),
        ).thenThrow(
          PostgrestException(message: 'JWT expired', code: 'PGRST301'),
        );

        final result = await service.checkAndIncrement();

        verify(() => mockAuth.refreshSession()).called(1);
        verify(
          () => mockClient.rpc(
            'check_and_increment_scan',
            params: any(named: 'params'),
          ),
        ).called(2);
        // Still fails closed after the retry — a scan must never slip through
        // just because the limit check could not be verified.
        expect(result.allowed, isFalse);
        expect(result.reason, 'network_error');
      });

      test('an AuthException is treated as recoverable too', () async {
        _authenticate(mockAuth);
        when(
          () => mockAuth.refreshSession(),
        ).thenThrow(const AuthException('refresh failed'));
        when(
          () => mockClient.rpc(
            'check_and_increment_scan',
            params: any(named: 'params'),
          ),
        ).thenThrow(const AuthException('Invalid JWT'));

        final result = await service.checkAndIncrement();

        verify(() => mockAuth.refreshSession()).called(1);
        expect(result.allowed, isFalse);
        expect(result.reason, 'network_error');
      });

      test('a non-auth PostgrestException is not retried', () async {
        _authenticate(mockAuth);
        when(
          () => mockClient.rpc(
            'check_and_increment_scan',
            params: any(named: 'params'),
          ),
        ).thenThrow(
          PostgrestException(message: 'permission denied', code: '42501'),
        );

        final result = await service.checkAndIncrement();

        verifyNever(() => mockAuth.refreshSession());
        expect(result.reason, 'network_error');
        expect(result.detail, 'postgrest_exception');
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
        when(
          () =>
              mockClient.rpc('grant_bonus_scan', params: any(named: 'params')),
        ).thenThrow(Exception('network error'));

        final result = await service.grantBonusScan();

        expect(result.granted, isFalse);
        expect(result.reason, 'network_error');
      });
    });
  });
}
