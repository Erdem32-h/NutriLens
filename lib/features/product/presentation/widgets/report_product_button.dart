import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../data/datasources/community_product_source.dart';

/// App-bar flag button: asks for confirmation, runs [onReport], then tells
/// the user what happened. [canProceed] runs first (sign-in gate); returning
/// `false` stops silently.
class ReportProductButton extends StatelessWidget {
  final Future<bool> Function() canProceed;
  final Future<ReportOutcome> Function() onReport;

  const ReportProductButton({
    super.key,
    required this.canProceed,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IconButton(
      tooltip: l10n.reportProduct,
      icon: const Icon(Icons.flag_outlined),
      onPressed: () => runReportFlow(
        context: context,
        canProceed: canProceed,
        onReport: onReport,
      ),
    );
  }

  static Future<void> runReportFlow({
    required BuildContext context,
    required Future<bool> Function() canProceed,
    required Future<ReportOutcome> Function() onReport,
  }) async {
    if (!await canProceed()) return;
    if (!context.mounted) return;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.reportProductTitle),
        content: Text(l10n.reportProductBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.reportProductConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      message = switch (await onReport()) {
        ReportOutcome.reported => l10n.reportProductThanks,
        ReportOutcome.alreadyReported => l10n.reportProductAlready,
        ReportOutcome.notFound => l10n.reportProductUnavailable,
      };
    } catch (e, st) {
      unawaited(Sentry.captureException(e, stackTrace: st));
      message = l10n.reportProductFailed;
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
