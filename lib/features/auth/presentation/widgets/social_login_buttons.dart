import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/analytics/failure_reason.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/auth_provider.dart';
import '../providers/social_auth_tracking.dart';

class SocialLoginButtons extends ConsumerWidget {
  const SocialLoginButtons({super.key});

  /// Reports the attempt, hands off to the browser, and reports back only
  /// if the hand-off itself failed.
  ///
  /// A launch that succeeds stays deliberately open: the sign-in is not
  /// finished yet, and whichever auth screen the deep link returns to
  /// closes it out by taking [pendingSocialAuthProvider]. Nothing reported
  /// these buttons before, which is why the funnel showed no registrations
  /// while Google was quietly producing most of the accounts.
  Future<void> _start(
    WidgetRef ref,
    String method,
    Future<Object?> Function() launch,
  ) async {
    final analytics = ref.read(analyticsServiceProvider);
    analytics.track(FunnelEvents.loginStarted, props: {'method': method});
    ref.read(pendingSocialAuthProvider.notifier).start(method);

    final failure = await launch();
    if (failure == null) return;

    // Clear before reporting: a launch that never reached the browser must
    // not leave a method parked, or the next successful sign-in would be
    // attributed to this abandoned one.
    ref.read(pendingSocialAuthProvider.notifier).take();
    analytics.track(
      FunnelEvents.loginFailed,
      props: {'method': method, 'reason': authFailureReason(failure)},
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Sign in with Apple has no native Android implementation here — the
    // OAuth call opens a browser flow that Android users can't complete,
    // so the button was a dead end that cost us the tap. Apple only
    // requires the option on its own platform.
    final showApple = Platform.isIOS || Platform.isMacOS;
    final auth = ref.read(authNotifierProvider.notifier);

    return Column(
      children: [
        AppButton(
          label: l10n.continueWithGoogle,
          variant: AppButtonVariant.secondary,
          icon: Icons.g_mobiledata,
          onPressed: () =>
              _start(ref, AuthMethod.google, auth.signInWithGoogle),
        ),
        if (showApple) ...[
          const SizedBox(height: 12),
          AppButton(
            label: l10n.continueWithApple,
            variant: AppButtonVariant.secondary,
            icon: Icons.apple,
            onPressed: () =>
                _start(ref, AuthMethod.apple, auth.signInWithApple),
          ),
        ],
      ],
    );
  }
}
