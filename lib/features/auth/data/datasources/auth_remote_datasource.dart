import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/user_entity.dart';

/// Whether [e] is the iOS in-app browser reporting that its first page
/// "failed to load" — which is what an OAuth hand-off looks like there.
///
/// `url_launcher_ios` only settles `launchUrl` once SFSafariViewController
/// finishes its initial load. On the OAuth path that load ends at our
/// `nutrilens://` redirect, which Safari cannot render, so the call throws
/// after the user has already signed in at the provider. Treating that as
/// a failed launch reported every iOS social sign-in as `login_failed`
/// (2026-10: Apple 24 of 31, ~12 s after the tap) while the deep link went
/// on to sign the user in. The browser was on screen either way, so the
/// hand-off did happen.
///
/// The code and message are pinned by url_launcher_ios for compatibility.
bool isInAppBrowserLoadFailure(PlatformException e) =>
    e.code == 'Error' && (e.message?.startsWith('Error while launching') ?? false);

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

  Future<void> sendPasswordResetEmail(String email);

  Future<void> updatePassword(String newPassword);

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
      // Without this the confirmation link falls back to the project's
      // Site URL, so the user confirms in a browser and has to find
      // their way back to the app by hand. The resend path already
      // passes this; the first (and for most users, only) email did
      // not, which is the one that matters.
      emailRedirectTo: 'nutrilens://auth/callback',
    );
    final user = response.user!;
    // Email-enumeration protection: signing up with an already-confirmed
    // email returns 200 + an obfuscated user whose identities list is
    // EMPTY (no confirmation mail is sent — `user_repeated_signup` in
    // auth logs). A genuinely new user always has exactly one identity.
    final identities = user.identities;
    if (identities != null && identities.isEmpty) {
      throw const EmailAlreadyRegisteredException();
    }
    return _mapUser(user);
  }

  @override
  Future<void> signInWithGoogle() => _signInWithOAuth(OAuthProvider.google);

  /// Native Sign in with Apple: the system sheet hands back an identity
  /// token that Supabase verifies directly. The button is only offered on
  /// Apple platforms, where this sheet exists.
  ///
  /// Replaces the browser round trip, which on iOS reported every sign-in
  /// as failed and left Safari open over the app (see
  /// [isInAppBrowserLoadFailure]). Needs the bundle id among the Apple
  /// provider's client IDs in Supabase.
  @override
  Future<void> signInWithApple() async {
    final rawNonce = _client.auth.generateRawNonce();
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        // Apple signs the hash; Supabase is given the raw value to compare.
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const SignInCancelledException();
      }
      rethrow;
    }

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple returned no identity token.');
    }
    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    // Apple shares the name once, on the first authorisation, and never in
    // the token — keep it now or never.
    final name = [credential.givenName, credential.familyName]
        .whereType<String>()
        .join(' ')
        .trim();
    if (name.isEmpty) return;
    try {
      await _client.auth.updateUser(
        UserAttributes(data: {'display_name': name}),
      );
    } on AuthException catch (e) {
      // The user is signed in; a missing name must not undo that.
      debugPrint('[auth] Apple display name not saved: ${e.message}');
    }
  }

  Future<void> _signInWithOAuth(OAuthProvider provider) async {
    try {
      await _client.auth.signInWithOAuth(
        provider,
        redirectTo: 'nutrilens://auth/callback',
      );
    } on PlatformException catch (e) {
      if (!isInAppBrowserLoadFailure(e)) rethrow;
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'nutrilens://auth/reset',
    );
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
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
