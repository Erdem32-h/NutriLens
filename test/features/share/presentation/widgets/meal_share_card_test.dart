import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/share/presentation/widgets/meal_share_card.dart';

void main() {
  testWidgets('renders food name, calories, macros and portion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MealShareCard(
              image: MemoryImage(Uint8List.fromList(const [0, 1, 2, 3])),
              foodName: 'Mercimek Çorbası',
              calories: 240,
              protein: 12,
              carbs: 30,
              fat: 6,
              portionGrams: 320,
              footer: 'NutriLens ile hesaplandı',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Mercimek Çorbası'), findsOneWidget);
    expect(find.text('240'), findsOneWidget);
    expect(find.text('12g'), findsOneWidget);
    expect(find.text('30g'), findsOneWidget);
    expect(find.text('6g'), findsOneWidget);
    expect(find.text('320 g'), findsOneWidget);
    expect(find.text('NutriLens ile hesaplandı'), findsOneWidget);
  });
}
