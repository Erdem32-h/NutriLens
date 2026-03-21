import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class NovaBadge extends StatelessWidget {
  final int novaGroup;
  final double size;

  const NovaBadge({
    super.key,
    required this.novaGroup,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.novaColor(novaGroup),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$novaGroup',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.45,
          ),
        ),
      ),
    );
  }
}
