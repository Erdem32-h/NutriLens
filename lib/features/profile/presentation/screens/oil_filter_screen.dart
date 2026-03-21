import 'package:flutter/material.dart';

import '../../../../core/extensions/l10n_extension.dart';

class OilFilterScreen extends StatelessWidget {
  const OilFilterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.oilFilters)),
      body: Center(
        child: Text(l10n.oilFilterPhase),
      ),
    );
  }
}
