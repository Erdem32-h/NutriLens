import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/monetization_provider.dart';
import '../../../product/presentation/providers/product_provider.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider));
});

final authStateProvider = StreamProvider<UserEntity?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentUserProvider = Provider<UserEntity?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    data: (user) => user,
    orElse: () => ref.watch(authRepositoryProvider).currentUser,
  );
});

class AuthNotifier extends AsyncNotifier<UserEntity?> {
  @override
  Future<UserEntity?> build() async {
    return ref.watch(authRepositoryProvider).currentUser;
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .signInWithEmail(email: email, password: password);
    state = result.fold(
      (failure) => AsyncError(failure.message, StackTrace.current),
      (user) => AsyncData(user),
    );
    if (state.value != null) {
      final subscriptionService = ref.read(subscriptionServiceProvider);
      await subscriptionService.logIn(state.value!.id);
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .signUpWithEmail(
          email: email,
          password: password,
          displayName: displayName,
        );
    state = result.fold(
      (failure) => AsyncError(failure.message, StackTrace.current),
      (user) => AsyncData(user),
    );
  }

  Future<void> signInWithGoogle() async {
    final result = await ref.read(authRepositoryProvider).signInWithGoogle();
    result.fold(
      (failure) => state = AsyncError(failure.message, StackTrace.current),
      (_) {
        // UI will listen to authStateProvider for successful login
      },
    );
  }

  Future<void> signInWithApple() async {
    final result = await ref.read(authRepositoryProvider).signInWithApple();
    result.fold(
      (failure) => state = AsyncError(failure.message, StackTrace.current),
      (_) {
        // UI will listen to authStateProvider for successful login
      },
    );
  }

  /// Returns `null` on success, or an error message on failure.
  /// Does NOT touch `state` — the UI handles its own loading flag for
  /// this transient action (we don't want to flip the global auth state
  /// to loading/error just because the user typed a wrong email).
  Future<String?> sendPasswordResetEmail(String email) async {
    final result = await ref
        .read(authRepositoryProvider)
        .sendPasswordResetEmail(email);
    return result.fold((failure) => failure.message, (_) => null);
  }

  /// Returns `null` on success, or an error message on failure.
  Future<String?> updatePassword(String newPassword) async {
    final result = await ref
        .read(authRepositoryProvider)
        .updatePassword(newPassword);
    return result.fold((failure) => failure.message, (_) => null);
  }

  Future<void> signOut() async {
    final subscriptionService = ref.read(subscriptionServiceProvider);
    await subscriptionService.logOut();
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, UserEntity?>(
  AuthNotifier.new,
);
