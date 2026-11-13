import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/product/data/datasources/community_product_source.dart';

Map<String, dynamic> row(Object? reportedCount) => {
      'barcode': '8690000000001',
      'product_name': 'Test Bisküvi',
      'reported_count': reportedCount,
    };

void main() {
  group('isHiddenByReports', () {
    test('eşiğin altı görünür, eşik ve üstü gizli', () {
      expect(isHiddenByReports(row(0)), isFalse);
      expect(isHiddenByReports(row(kCommunityReportHideThreshold - 1)), isFalse);
      expect(isHiddenByReports(row(kCommunityReportHideThreshold)), isTrue);
      expect(isHiddenByReports(row(kCommunityReportHideThreshold + 5)), isTrue);
    });

    test('eksik, null veya bozuk sayaç gizlemez', () {
      expect(isHiddenByReports({'barcode': '1'}), isFalse);
      expect(isHiddenByReports(row(null)), isFalse);
      expect(isHiddenByReports(row('abc')), isFalse);
    });

    test('string sayaç da okunur', () {
      expect(isHiddenByReports(row('$kCommunityReportHideThreshold')), isTrue);
    });
  });

  group('visibleCommunityProduct', () {
    test('satır yoksa null', () {
      expect(visibleCommunityProduct(null), isNull);
    });

    test('gizlenen satır null döner, böylece diğer kaynaklara düşer', () {
      expect(visibleCommunityProduct(row(kCommunityReportHideThreshold)), isNull);
    });

    test('görünür satır entity olur', () {
      final product = visibleCommunityProduct(row(1));
      expect(product, isNotNull);
      expect(product!.barcode, '8690000000001');
      expect(product.productName, 'Test Bisküvi');
    });
  });
}
