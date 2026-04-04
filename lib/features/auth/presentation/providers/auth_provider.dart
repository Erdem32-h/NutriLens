import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/monetization_provider.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(Supabase.instance.client);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider));
});

final authStateProvider = StreamProvider<UserEntity?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentUserProvider = Provider<UserEntity?>((ref) {
  return ref.watch(authRepositoryProvider).currentUser;
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
    final result = await ref.read(authRepositoryProvider).signInWithEmail(
          email: email,
          password: password,
        );
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
    final result = await ref.read(authRepositoryProvider).signUpWithEmail(
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
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).signInWithGoogle();
    state = result.fold(
      (failure) => AsyncError(failure.message, StackTrace.current),
      (user) => AsyncData(user),
    );
    if (state.value != null) {
      final subscriptionService = ref.read(subscriptionServiceProvider);
      await subscriptionService.logIn(state.value!.id);
    }
  }

  Future<void> signInWithApple() async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).signInWithApple();
    state = result.fold(
      (failure) => AsyncError(failure.message, StackTrace.current),
      (user) => AsyncData(user),
    );
    if (state.value != null) {
      final subscriptionService = ref.read(subscriptionServiceProvider);
      await subscriptionService.logIn(state.value!.id);
    }
  }

  Future<void> signOut() async {
    final subscriptionService = ref.read(subscriptionServiceProvider);
    await subscriptionService.logOut();
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, UserEntity?>(AuthNotifier.new);
