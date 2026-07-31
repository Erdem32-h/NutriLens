import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/compare_hint_provider.dart';

/// Tek seferlik keşfedilebilirlik şeridi: kıyaslama özelliğinin varlığını
/// ve yerini (ALTERNATİF sekmesi) söyler. X'e basılınca cihazda kalıcı
/// olarak kapanır; otomatik kaybolmaz (spec 2.1).
class CompareHintStrip extends ConsumerWidget {
  const CompareHintStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(compareHintDismissedProvider);
    if (dismissed) return const SizedBox.shrink();

    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.compare_arrows_rounded,
            size: 18,
            color: colors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.compareHintStrip,
              style: TextStyle(fontSize: 12.5, color: colors.textMuted),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: colors.textMuted,
            tooltip: context.l10n.compareHintDismiss,
            visualDensity: VisualDensity.compact,
            onPressed: () => dismissCompareHint(ref),
          ),
        ],
      ),
    );
  }
}
