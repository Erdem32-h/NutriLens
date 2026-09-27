import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/profile/presentation/screens/profile_screen.dart';

void main() {
  group('ramadanRowVisible', () {
    test('teklif penceresi acilmadan once gizli', () {
      expect(ramadanRowVisible(DateTime(2027, 2, 4)), isFalse);
    });

    test('teklif penceresinin ilk gununden (5 Subat) itibaren gorunur', () {
      expect(ramadanRowVisible(DateTime(2027, 2, 5)), isTrue);
      expect(ramadanRowVisible(DateTime(2027, 2, 7, 23, 59)), isTrue);
    });

    test('Ramazan gunlerinde gorunur', () {
      expect(ramadanRowVisible(DateTime(2027, 2, 10)), isTrue);
    });

    test('Bayramdan sonra da gorunur kalir (tabloda sonraki donem yok)', () {
      expect(ramadanRowVisible(DateTime(2027, 3, 15)), isTrue);
    });
  });
}
