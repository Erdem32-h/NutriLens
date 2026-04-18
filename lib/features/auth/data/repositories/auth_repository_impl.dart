import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../../core/error/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

final class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  const AuthRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, UserEntity>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _handleAuth(
      () => _remoteDataSource.signInWithEmail(
        email: email,
        password: password,
      ),
    );
  }

  @override
  Future<Either<Failure, UserEntity>> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    return _handleAuth(
      () => _remoteDataSource.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> signInWithGoogle() async {
    return _handleAuthVoid(() => _remoteDataSource.signInWithGoogle());
  }

  @override
  Future<Either<Failure, void>> signInWithApple() async {
    return _handleAuthVoid(() => _remoteDataSource.signInWithApple());
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _remoteDataSource.signOut();
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<UserEntity?> authStateChanges() {
    return _remoteDataSource.authStateChanges();
  }

  @override
  UserEntity? get currentUser => _remoteDataSource.currentUser;

  Future<Either<Failure, UserEntity>> _handleAuth(
    Future<UserEntity> Function() action,
  ) async {
    try {
      final user = await action();
      return Right(user);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> _handleAuthVoid(
    Future<void> Function() action,
  ) async {
    try {
      await action();
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
