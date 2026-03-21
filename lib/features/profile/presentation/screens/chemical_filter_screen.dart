import 'package:flutter/material.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';

class ChemicalFilterScreen extends StatelessWidget {
  const ChemicalFilterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.chemicalFilters),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Text(
          l10n.chemicalFilterPhase,
          style: const TextStyle(color: AppColors.textMuted),
        ),
      ),
    );
  }
}
