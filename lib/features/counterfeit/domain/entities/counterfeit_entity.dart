import 'package:equatable/equatable.dart';

class CounterfeitEntity extends Equatable {
  final String id;
  final String brandName;
  final String productName;
  final String? category;
  final String violationType;
  final String? violationDetail;
  final String? province;
  final DateTime? detectionDate;
  final String? barcode;
  final String? sourceUrl;

  const CounterfeitEntity({
    required this.id,
    required this.brandName,
    required this.productName,
    this.category,
    required this.violationType,
    this.violationDetail,
    this.province,
    this.detectionDate,
    this.barcode,
    this.sourceUrl,
  });

  @override
  List<Object?> get props => [
        id,
        brandName,
        productName,
        violationType,
        barcode,
      ];
}
