import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/comparison/domain/product_comparison.dart';
import 'package:nutrilens/features/share/presentation/widgets/comparison_share_card.dart';

void main() {
  testWidgets('renders both products, scores and the healthier chip', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ComparisonShareCard(
              imageA: null,
              imageB: null,
              nameA: 'Süt A',
              nameB: 'Süt B',
              hpA: 82,
              hpB: 40,
              better: BetterSide.a,
              healthierLabel: 'Daha sağlıklı',
              footer: 'NutriLens ile karşılaştırıldı',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Süt A'), findsOneWidget);
    expect(find.text('Süt B'), findsOneWidget);
    expect(find.text('82'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('VS'), findsOneWidget);
    // Winner chip shown once (for side A).
    expect(find.text('Daha sağlıklı'), findsOneWidget);
    expect(find.text('NutriLens ile karşılaştırıldı'), findsOneWidget);
  });

  testWidgets('no healthier chip when neither side wins', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ComparisonShareCard(
              imageA: null,
              imageB: null,
              nameA: 'A',
              nameB: 'B',
              hpA: 50,
              hpB: 50,
              better: BetterSide.none,
              healthierLabel: 'Daha sağlıklı',
              footer: 'f',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Daha sağlıklı'), findsNothing);
  });
}
