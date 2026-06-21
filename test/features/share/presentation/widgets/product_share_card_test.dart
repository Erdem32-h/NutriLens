import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/share/presentation/widgets/product_share_card.dart';

void main() {
  testWidgets('renders name, brand, score and chips', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ProductShareCard(
              image: null,
              name: 'Sütaş Süt',
              brand: 'Sütaş',
              hpScore: 82,
              chips: ['Şeker: 5g', 'Katkı: 0', 'NOVA 1'],
              footer: 'NutriLens ile tarandı',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sütaş Süt'), findsOneWidget);
    expect(find.text('Sütaş'), findsOneWidget);
    expect(find.text('82'), findsOneWidget);
    expect(find.text('Şeker: 5g'), findsOneWidget);
    expect(find.text('Katkı: 0'), findsOneWidget);
    expect(find.text('NOVA 1'), findsOneWidget);
    expect(find.text('NutriLens ile tarandı'), findsOneWidget);
  });

  testWidgets('hides score badge when hpScore is null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ProductShareCard(
              image: null,
              name: 'X',
              brand: '',
              hpScore: null,
              chips: [],
              footer: 'f',
            ),
          ),
        ),
      ),
    );
    // No "HP" label rendered when score missing.
    expect(find.text('HP'), findsNothing);
  });
}
