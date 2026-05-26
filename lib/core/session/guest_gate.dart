import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/widgets/guest_register_sheet.dart';
import 'app_session.dart';

/// Cloud-only features (favorites, blacklist, premium, community
/// submit) all need the same flow: if the current user is a guest,
/// show a register sheet and short-circuit the action.
///
/// Usage in any onPressed:
/// ```
/// if (!await ref.requireAuthOr(context, feature: 'Favoriler')) return;
/// // ... real action
/// ```
extension GuestGateExtension on WidgetRef {
  /// Returns `true` when the caller can proceed (authenticated user),
  /// `false` when the guest sheet was shown. Routes to /register if
  /// the user tapped the CTA — the caller's screen is left as-is on
  /// "Şu an değil".
  Future<bool> requireAuthOr(
    BuildContext context, {
    required String feature,
  }) async {
    if (!read(isGuestProvider)) return true;
    if (!context.mounted) return false;
    final wantsRegister = await GuestRegisterSheet.showFeatureLocked(
      context,
      feature: feature,
    );
    if (wantsRegister && context.mounted) {
      context.go('/register');
    }
    return false;
  }
}
