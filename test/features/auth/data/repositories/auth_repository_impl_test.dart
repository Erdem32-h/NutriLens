import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/core/error/failures.dart';
import 'package:nutrilens/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:nutrilens/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:nutrilens/features/auth/domain/entities/user_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

void main() {
  late AuthRepositoryImpl repository;
  late MockAuthRemoteDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockAuthRemoteDataSource();
    repository = AuthRepositoryImpl(mockDataSource);
  });

  const user = UserEntity(
    id: 'user-123',
    email: 'test@example.com',
    displayName: 'Test',
  );

  group('signInWithEmail', () {
    test('returns UserEntity on success', () async {
      when(() => mockDataSource.signInWithEmail(
            email: 'test@example.com',
            password: 'password123',
          )).thenAnswer((_) async => user);

      final result = await repository.signInWithEmail(
        email: 'test@example.com',
        password: 'password123',
      );

      expect(result, const Right(user));
      verify(() => mockDataSource.signInWithEmail(
            email: 'test@example.com',
            password: 'password123',
          )).called(1);
    });

    test('returns AuthFailure on AuthException', () async {
      when(() => mockDataSource.signInWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(AuthException('Invalid credentials'));

      final result = await repository.signInWithEmail(
        email: 'bad@example.com',
        password: 'wrong',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, 'Invalid credentials');
        },
        (_) => fail('Expected Left'),
      );
    });

    test('returns ServerFailure on unexpected exception', () async {
      when(() => mockDataSource.signInWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(Exception('Unknown error'));

      final result = await repository.signInWithEmail(
        email: 'test@example.com',
        password: 'pass',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });

  group('signUpWithEmail', () {
    test('returns UserEntity on success', () async {
      when(() => mockDataSource.signUpWithEmail(
            email: 'new@example.com',
            password: 'password123',
            displayName: 'New User',
          )).thenAnswer((_) async => user);

      final result = await repository.signUpWithEmail(
        email: 'new@example.com',
        password: 'password123',
        displayName: 'New User',
      );

      expect(result.isRight(), isTrue);
    });

    test('returns AuthFailure on AuthException', () async {
      when(() => mockDataSource.signUpWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
            displayName: any(named: 'displayName'),
          )).thenThrow(AuthException('Email already exists'));

      final result = await repository.signUpWithEmail(
        email: 'existing@example.com',
        password: 'pass',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, 'Email already exists');
        },
        (_) => fail('Expected Left'),
      );
    });
  });

  group('signInWithGoogle', () {
    test('returns UserEntity on success', () async {
      when(() => mockDataSource.signInWithGoogle())
          .thenAnswer((_) async => user);

      final result = await repository.signInWithGoogle();

      expect(result, const Right(user));
    });

    test('returns AuthFailure on AuthException', () async {
      when(() => mockDataSource.signInWithGoogle())
          .thenThrow(AuthException('Google sign-in failed'));

      final result = await repository.signInWithGoogle();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<AuthFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });

  group('signInWithApple', () {
    test('returns UserEntity on success', () async {
      when(() => mockDataSource.signInWithApple())
          .thenAnswer((_) async => user);

      final result = await repository.signInWithApple();

      expect(result, const Right(user));
    });

    test('returns AuthFailure on AuthException', () async {
      when(() => mockDataSource.signInWithApple())
          .thenThrow(AuthException('Apple sign-in failed'));

      final result = await repository.signInWithApple();

      expect(result.isLeft(), isTrue);
    });
  });

  group('signOut', () {
    test('returns Right(null) on success', () async {
      when(() => mockDataSource.signOut()).thenAnswer((_) async {});

      final result = await repository.signOut();

      expect(result, const Right(null));
      verify(() => mockDataSource.signOut()).called(1);
    });

    test('returns AuthFailure on AuthException', () async {
      when(() => mockDataSource.signOut())
          .thenThrow(AuthException('Sign out failed'));

      final result = await repository.signOut();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, 'Sign out failed');
        },
        (_) => fail('Expected Left'),
      );
    });

    test('returns ServerFailure on unexpected exception', () async {
      when(() => mockDataSource.signOut())
          .thenThrow(Exception('Network error'));

      final result = await repository.signOut();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });

  group('authStateChanges', () {
    test('delegates to data source', () {
      when(() => mockDataSource.authStateChanges())
          .thenAnswer((_) => Stream.value(user));

      final stream = repository.authStateChanges();

      expect(stream, emits(user));
    });

    test('emits null when no user', () {
      when(() => mockDataSource.authStateChanges())
          .thenAnswer((_) => Stream.value(null));

      final stream = repository.authStateChanges();

      expect(stream, emits(isNull));
    });
  });

  group('currentUser', () {
    test('returns user from data source', () {
      when(() => mockDataSource.currentUser).thenReturn(user);

      expect(repository.currentUser, user);
    });

    test('returns null when no user', () {
      when(() => mockDataSource.currentUser).thenReturn(null);

      expect(repository.currentUser, isNull);
    });
  });
}
