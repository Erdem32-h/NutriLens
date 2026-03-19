import 'package:flutter/material.dart';

class OilFilterScreen extends StatelessWidget {
  const OilFilterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yag Filtreleri')),
      body: const Center(
        child: Text('Yag filtreleri Phase 4\'te eklenecek'),
      ),
    );
  }
}
