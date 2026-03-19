import 'package:flutter/material.dart';

class AllergenSelectionScreen extends StatelessWidget {
  const AllergenSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerjenler')),
      body: const Center(
        child: Text('Alerjen secimi Phase 4\'te eklenecek'),
      ),
    );
  }
}
