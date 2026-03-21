import 'package:flutter/material.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';

class OilFilterScreen extends StatelessWidget {
  const OilFilterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.oilFilters),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Text(
          l10n.oilFilterPhase,
          style: const TextStyle(color: AppColors.textMuted),
        ),
      ),
    );
  }
}
