import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/l10n_extension.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'providers/water_provider.dart';

WaterReminderCopy waterReminderCopy(AppLocalizations l10n) =>
    (title: l10n.waterReminderTitle, body: l10n.waterReminderBody);

Future<void> addWaterGlass(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  await ref.read(waterControllerProvider).addGlass(waterReminderCopy(l10n));

  // One-shot discovery: the switch lives on the water screen, which most
  // users never open before the habit forms.
  final store = ref.read(waterSettingsStoreProvider);
  if (ref.read(waterSettingsProvider).reminderEnabled || store.promptShown) {
    return;
  }
  if (!context.mounted) return;
  await store.markPromptShown();
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.waterReminderPrompt),
      action: SnackBarAction(
        label: l10n.waterReminderEnable,
        onPressed: () => setWaterReminder(context, ref, true),
      ),
    ),
  );
}

Future<void> removeWaterGlass(BuildContext context, WidgetRef ref) async {
  await ref
      .read(waterControllerProvider)
      .removeGlass(waterReminderCopy(context.l10n));
}

Future<void> setWaterReminder(
  BuildContext context,
  WidgetRef ref,
  bool enabled,
) async {
  if (!context.mounted) return;
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final ok = await ref
      .read(waterControllerProvider)
      .setReminderEnabled(enabled, waterReminderCopy(l10n));
  if (!ok) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.waterPermissionDenied)));
  }
}
