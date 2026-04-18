import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';

abstract interface class AuthRepository {
  Future<Either<Failure, UserEntity>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Either<Failure, UserEntity>> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  Future<Either<Failure, void>> signInWithGoogle();

  Future<Either<Failure, void>> signInWithApple();

  Future<Either<Failure, void>> signOut();

  Stream<UserEntity?> authStateChanges();

  UserEntity? get currentUser;
}
