import 'package:flutter/material.dart';

import '../../../../core/extensions/l10n_extension.dart';

class AllergenSelectionScreen extends StatelessWidget {
  const AllergenSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.allergens)),
      body: Center(
        child: Text(l10n.allergenSelectionPhase),
      ),
    );
  }
}
