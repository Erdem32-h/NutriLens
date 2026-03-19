import 'package:flutter/material.dart';

class DietFilterScreen extends StatelessWidget {
  const DietFilterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diyet Filtreleri')),
      body: const Center(
        child: Text('Diyet filtreleri Phase 4\'te eklenecek'),
      ),
    );
  }
}
