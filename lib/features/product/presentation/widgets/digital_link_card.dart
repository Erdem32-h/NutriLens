import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/gs1_digital_link.dart';

/// Lot / expiry / producer-page card for products opened from a GS1 Digital
/// Link QR. The host is shown under the button so the user sees where the
/// link leads before leaving the app.
class DigitalLinkCard extends StatelessWidget {
  final Gs1DigitalLink link;

  /// Injectable clock for tests.
  final DateTime Function()? now;

  const DigitalLinkCard({super.key, required this.link, this.now});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final lot = link.lot;
    final expiry = link.expiry;
    final today = (now ?? DateTime.now)();
    // Expiry is a whole day: still valid until the end of that date.
    final expired = expiry != null &&
        DateTime(today.year, today.month, today.day).isAfter(expiry);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lot != null)
              Text(l10n.digitalLinkLot(lot),
                  style: TextStyle(color: colors.textPrimary)),
            if (expiry != null)
              Row(
                children: [
                  Text(
                    l10n.digitalLinkExpiry(_formatDate(expiry)),
                    style: TextStyle(
                      color: expired ? Colors.red : colors.textPrimary,
                    ),
                  ),
                  if (expired) ...[
                    const SizedBox(width: 8),
                    Text(
                      l10n.digitalLinkExpired,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            TextButton.icon(
              onPressed: () => _open(context),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(l10n.digitalLinkProducerPage),
            ),
            Text(
              link.uri.host,
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.digitalLinkOpenFailed;
    var opened = false;
    try {
      opened =
          await launchUrl(link.uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[DigitalLinkCard] launch failed: $e');
    }
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }
}
