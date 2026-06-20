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
    await _client.from('community_products').upsert({
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
      'category': product.category,
      'ingredients_photo_url': ingredientsPhotoUrl,
      'added_by': userId,
    }, onConflict: 'barcode');
  }

  /// Same-category products with a strictly better HP score than
  /// [currentHpScore], best first. Empty list when [category] is null or on
  /// any error.
  Future<List<ProductEntity>> getAlternatives({
    required String? category,
    required String selfBarcode,
    required double currentHpScore,
    int limit = 5,
  }) async {
    if (category == null) return const [];
    try {
      final rows = await _client
          .from('community_products')
          .select()
          .eq('category', category)
          .neq('barcode', selfBarcode)
          .gt('hp_score', currentHpScore)
          .order('hp_score', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) => ProductDto.fromCommunityRow(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.w('getAlternatives failed for $selfBarcode/$category: $e');
      return const [];
    }
  }

  /// Best-effort write of an API-resolved product into community_products
  /// so the TR corpus grows passively and future scans (plus the upcoming
  /// alternatives/comparison feature) don't depend on external APIs.
  ///
  /// `ignoreDuplicates: true` is the critical safeguard — if a barcode is
  /// already in community_products (e.g. a user previously corrected the
  /// product name / ingredients), this is a no-op. We never overwrite
  /// curated entries with raw API data.
  ///
  /// Caller is expected to skip this when `product.hasEssentialData` is
  /// false; missing-metadata barcodes should go through the user edit flow
  /// instead so the community DB doesn't accumulate junk rows.
  ///
  /// Returns `true` only when a new row was actually inserted.
  Future<bool> autoImportFromApi({
    required ProductEntity product,
    required String userId,
    String source = 'api_import',
  }) async {
    try {
      final inserted = await _client
          .from('community_products')
          .upsert(
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
              'source': source,
              'category': product.category,
              'added_by': userId,
            },
            onConflict: 'barcode',
            ignoreDuplicates: true,
          )
          .select();
      return inserted.isNotEmpty;
    } catch (e) {
      _logger.w('autoImportFromApi failed for ${product.barcode}: $e');
      return false;
    }
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
      await _client.rpc(
        'increment_verified_count',
        params: {'product_id_param': productId},
      );
    } else if (action == 'report_wrong') {
      await _client.rpc(
        'increment_reported_count',
        params: {'product_id_param': productId},
      );
    }
  }
}
