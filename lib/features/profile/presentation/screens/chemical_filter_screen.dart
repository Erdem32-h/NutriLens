import 'package:flutter/material.dart';

class ChemicalFilterScreen extends StatelessWidget {
  const ChemicalFilterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kimyasal Filtreleri')),
      body: const Center(
        child: Text('Kimyasal filtreleri Phase 4\'te eklenecek'),
      ),
    );
  }
}
