import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/score_constants.dart';
import '../../domain/entities/product_entity.dart';
import '../models/product_dto.dart';
import 'product_source.dart';

class CommunityProductSource implements ProductSource {
  final SupabaseClient _client;
  final _logger = Logger();

  CommunityProductSource(this._client);

  @override
  String get name => 'community';

  @override
  int get priority => 0;

  @override
  Duration get timeout => const Duration(seconds: 5);

  @override
  Future<ProductEntity?> resolve(String barcode) async {
    try {
      final response = await _client
          .from('community_products')
          .select()
          .eq('barcode', barcode)
          .maybeSingle();

      if (response == null) return null;

      return ProductDto.fromCommunityRow(response);
    } catch (e) {
      _logger.w('CommunityProductSource error: $e');
      return null;
    }
  }

  /// Add a new product to the community database.
  Future<void> addProduct({
    required ProductEntity product,
    String? ingredientsPhotoUrl,
    required String userId,
    String source = 'community',
  }) async {
    await _client.from('community_products').upsert(
      {
        'barcode': product.barcode,
        'product_name': product.productName,
        'brand': product.brands,
        'image_url': product.imageUrl,
        'ingredients_text': product.ingredientsText,
        'additives_tags': product.additivesTags,
        'nutriments': {
          'energy_kcal': product.nutriments.energyKcal,
          'fat': product.nutriments.fat,
          'saturated_fat': product.nutriments.saturatedFat,
          'trans_fat': product.nutriments.transFat,
          'carbohydrates': product.nutriments.carbohydrates,
          'sugars': product.nutriments.sugars,
          'salt': product.nutriments.salt,
          'fiber': product.nutriments.fiber,
          'proteins': product.nutriments.proteins,
        },
        'nova_group': product.novaGroup,
        'nutriscore_grade': product.nutriscoreGrade,
        'hp_score': product.hpScore,
        'hp_chemical_load': product.hpChemicalLoad,
        'hp_risk_factor': product.hpRiskFactor,
        'hp_nutri_factor': product.hpNutriFactor,
        'hp_score_version': ScoreConstants.hpScoreAlgorithmVersion,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'source': source,
        'ingredients_photo_url': ingredientsPhotoUrl,
        'added_by': userId,
      },
      onConflict: 'barcode',
    );
  }

  /// Report or verify a community product.
  Future<void> reportProduct({
    required String productId,
    required String userId,
    required String action,
    Map<String, dynamic>? details,
  }) async {
    await _client.from('product_reports').insert({
      'product_id': productId,
      'user_id': userId,
      'action': action,
      'details': details,
    });

    // Increment verify/report count
    if (action == 'verify') {
      await _client.rpc('increment_verified_count', params: {
        'product_id_param': productId,
      });
    } else if (action == 'report_wrong') {
      await _client.rpc('increment_reported_count', params: {
        'product_id_param': productId,
      });
    }
  }
}
