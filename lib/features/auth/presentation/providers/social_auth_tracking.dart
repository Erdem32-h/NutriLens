import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the social provider whose sign-in is currently in flight.
///
/// `signInWithOAuth` only launches a browser and returns; the session lands
/// later, through a deep link, on whichever auth screen the visitor left
/// from. Nothing in that returning event says which button started it, so
/// the method is parked here at tap time and read back when the session
/// arrives.
///
/// Email sign-in never touches this — it reports its own outcome inline,
/// where the result is already in hand.
class PendingSocialAuth extends Notifier<String?> {
  @override
  String? build() => null;

  void start(String method) => state = method;

  /// Returns the in-flight method and clears it, or null when there is
  /// none.
  ///
  /// Clearing is the point: the deep link can bring the app back to either
  /// auth screen and both ask, so a second answer would double count the
  /// same sign-in.
  String? take() {
    final method = state;
    state = null;
    return method;
  }
}

final pendingSocialAuthProvider =
    NotifierProvider<PendingSocialAuth, String?>(PendingSocialAuth.new);

/// Values for the `method` prop shared by every event in the auth funnel.
abstract final class AuthMethod {
  static const email = 'email';
  static const google = 'google';
  static const apple = 'apple';
}
