import '../../../../config/drift/app_database.dart';
import '../../domain/entities/counterfeit_entity.dart';

/// Maps between Drift rows and [CounterfeitEntity].
abstract final class CounterfeitDto {
  static CounterfeitEntity fromRow(CounterfeitProduct row) {
    return CounterfeitEntity(
      id: row.id,
      brandName: row.brandName,
      productName: row.productName,
      category: row.category,
      violationType: row.violationType,
      violationDetail: row.violationDetail,
      province: row.province,
      detectionDate: row.detectionDate,
      barcode: row.barcode,
      sourceUrl: row.sourceUrl,
    );
  }

  static CounterfeitEntity fromSupabase(Map<String, dynamic> map) {
    return CounterfeitEntity(
      id: map['id'] as String,
      brandName: map['brand_name'] as String,
      productName: map['product_name'] as String,
      category: map['category'] as String?,
      violationType: map['violation_type'] as String,
      violationDetail: map['violation_detail'] as String?,
      province: map['province'] as String?,
      detectionDate: map['detection_date'] != null
          ? DateTime.tryParse(map['detection_date'] as String)
          : null,
      barcode: map['barcode'] as String?,
      sourceUrl: map['source_url'] as String?,
    );
  }
}
