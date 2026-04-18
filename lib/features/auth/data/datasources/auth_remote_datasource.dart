import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/user_entity.dart';

abstract interface class AuthRemoteDataSource {
  Future<UserEntity> signInWithEmail({
    required String email,
    required String password,
  });

  Future<UserEntity> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  Future<void> signInWithGoogle();

  Future<void> signInWithApple();

  Future<void> signOut();

  Stream<UserEntity?> authStateChanges();

  UserEntity? get currentUser;
}

final class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient _client;

  const AuthRemoteDataSourceImpl(this._client);

  @override
  Future<UserEntity> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return _mapUser(response.user!);
  }

  @override
  Future<UserEntity> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: displayName != null ? {'display_name': displayName} : null,
    );
    return _mapUser(response.user!);
  }

  @override
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.nutrilens.nutrilens://callback',
    );
  }

  @override
  Future<void> signInWithApple() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'com.nutrilens.nutrilens://callback',
    );
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Stream<UserEntity?> authStateChanges() {
    return _client.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      return user != null ? _mapUser(user) : null;
    });
  }

  @override
  UserEntity? get currentUser {
    final user = _client.auth.currentUser;
    return user != null ? _mapUser(user) : null;
  }

  UserEntity _mapUser(User user) {
    return UserEntity(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'] as String?,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
    );
  }
}
