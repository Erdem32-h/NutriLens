import 'package:flutter/material.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';

class DietFilterScreen extends StatelessWidget {
  const DietFilterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(l10n.dietFilters),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Text(
          l10n.dietFilterPhase,
          style: TextStyle(color: context.colors.textMuted),
        ),
      ),
    );
  }
}