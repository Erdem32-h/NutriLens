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

  /// Sends a password reset email. The email contains a deep-link back
  /// into the app at `nutrilens://auth/reset?...` which the router
  /// converts to `/reset-password` after Supabase consumes the token.
  Future<Either<Failure, void>> sendPasswordResetEmail(String email);

  /// Sets a new password for the currently-authenticated user (the
  /// password-reset deep-link signs the user in implicitly, so this
  /// only requires the new password).
  Future<Either<Failure, void>> updatePassword(String newPassword);

  Future<Either<Failure, void>> signOut();

  Stream<UserEntity?> authStateChanges();

  UserEntity? get currentUser;
}
