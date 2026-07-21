import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/auth_provider.dart';

class SocialLoginButtons extends ConsumerWidget {
  const SocialLoginButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Sign in with Apple has no native Android implementation here — the
    // OAuth call opens a browser flow that Android users can't complete,
    // so the button was a dead end that cost us the tap. Apple only
    // requires the option on its own platform.
    final showApple = Platform.isIOS || Platform.isMacOS;

    return Column(
      children: [
        AppButton(
          label: l10n.continueWithGoogle,
          variant: AppButtonVariant.secondary,
          icon: Icons.g_mobiledata,
          onPressed: () =>
              ref.read(authNotifierProvider.notifier).signInWithGoogle(),
        ),
        if (showApple) ...[
          const SizedBox(height: 12),
          AppButton(
            label: l10n.continueWithApple,
            variant: AppButtonVariant.secondary,
            icon: Icons.apple,
            onPressed: () =>
                ref.read(authNotifierProvider.notifier).signInWithApple(),
          ),
        ],
      ],
    );
  }
}
