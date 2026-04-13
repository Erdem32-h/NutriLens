import '../../domain/entities/additive_entity.dart';
import '../../domain/entities/allergen_entity.dart';

/// Parses one entry from additives_database.json into an [AdditiveEntity].
class AdditiveJsonModel {
  static AdditiveEntity fromJson(Map<String, dynamic> json) {
    return AdditiveEntity(
      id: json['id'] as String,
      eNumber: json['e_number'] as String,
      nameEn: json['name_en'] as String,
      nameTr: json['name_tr'] as String?,
      category: json['category'] as String?,
      riskLevel: (json['risk_level'] as num).toInt(),
      riskLabel: json['risk_label'] as String?,
      descriptionEn: json['description_en'] as String?,
      descriptionTr: json['description_tr'] as String?,
      efsaStatus: json['efsa_status'] as String?,
      turkishCodexStatus: json['turkish_codex_status'] as String?,
      isVegan: json['is_vegan'] as bool? ?? true,
      isVegetarian: json['is_vegetarian'] as bool? ?? true,
      isHalal: json['is_halal'] as bool? ?? true,
    );
  }
}

/// Parses one entry from allergens_seed into an [AllergenEntity].
class AllergenJsonModel {
  static AllergenEntity fromJson(Map<String, dynamic> json) {
    return AllergenEntity(
      id: json['id'] as String,
      nameEn: json['name_en'] as String,
      nameTr: json['name_tr'] as String,
      category: json['category'] as String? ?? '',
      iconName: json['icon_name'] as String? ?? 'warning',
      severityNote: json['severity_note'] as String?,
    );
  }
}
