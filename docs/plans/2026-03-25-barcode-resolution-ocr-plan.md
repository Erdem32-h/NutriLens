# Barkod Çözümleme & İçindekiler OCR — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add multi-source barcode resolution chain (Strategy Pattern) + OCR ingredients parsing + community product database to maximize barcode hit rate.

**Architecture:** Strategy Pattern with `ProductSource` interface → `ProductResolver` tries sources in priority order (Supabase Community → Open Food Facts → UPC Item DB). OCR fallback for unresolved barcodes uses Google ML Kit on-device text recognition. Community-contributed products stored in Supabase, cached locally in existing Drift `FoodProducts` table.

**Tech Stack:** Flutter, Riverpod, fpdart Either, Drift, Supabase, Google ML Kit, Dio, GoRouter

---

## Task 1: Supabase Tables — community_products & product_reports

**Files:**
- No local files — Supabase MCP SQL execution

**Step 1: Create community_products table**

Execute via Supabase MCP `execute_sql`:

```sql
CREATE TABLE community_products (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  barcode TEXT NOT NULL UNIQUE,
  product_name TEXT,
  brand TEXT,
  image_url TEXT,
  ingredients_text TEXT,
  additives_tags JSONB DEFAULT '[]'::jsonb,
  nutriments JSONB DEFAULT '{}'::jsonb,
  nova_group INTEGER,
  nutriscore_grade TEXT,
  hp_score NUMERIC,
  hp_chemical_load NUMERIC,
  hp_risk_factor NUMERIC,
  hp_nutri_factor NUMERIC,
  source TEXT NOT NULL DEFAULT 'community',
  ingredients_photo_url TEXT,
  added_by UUID REFERENCES auth.users(id),
  verified_count INTEGER DEFAULT 0,
  reported_count INTEGER DEFAULT 0,
  is_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_community_products_barcode ON community_products(barcode);
```

**Step 2: Create product_reports table**

```sql
CREATE TABLE product_reports (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id UUID REFERENCES community_products(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  action TEXT NOT NULL,
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Step 3: Apply RLS policies**

```sql
ALTER TABLE community_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "community_products_select"
  ON community_products FOR SELECT USING (true);

CREATE POLICY "community_products_insert"
  ON community_products FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "community_products_update"
  ON community_products FOR UPDATE
  USING (auth.uid() = added_by);

CREATE POLICY "product_reports_select"
  ON product_reports FOR SELECT USING (true);

CREATE POLICY "product_reports_insert"
  ON product_reports FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');
```

**Step 4: Verify tables exist**

Run `SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('community_products', 'product_reports');` — expect 2 rows.

**Step 5: Commit**

```bash
git add docs/plans/
git commit -m "docs: add barcode resolution & OCR design and implementation plan"
```

---

## Task 2: HP Score Calculator Service

**Files:**
- Create: `lib/core/services/hp_score_calculator.dart`
- Reference: `lib/core/constants/score_constants.dart` (read-only)
- Reference: `lib/config/drift/app_database.dart` (read-only)
- Reference: `lib/features/product/domain/entities/nutriments_entity.dart` (read-only)

**Step 1: Create HpScoreResult class and HpScoreCalculator**

Create `lib/core/services/hp_score_calculator.dart`:

```dart
import 'dart:math';

import '../../config/drift/app_database.dart';
import '../constants/score_constants.dart';
import '../../features/product/domain/entities/nutriments_entity.dart';

class HpScoreResult {
  final double hpScore;
  final double chemicalLoad;
  final double? riskFactor;
  final double? nutriFactor;
  final bool isPartial;
  final int gaugeLevel;

  const HpScoreResult({
    required this.hpScore,
    required this.chemicalLoad,
    this.riskFactor,
    this.nutriFactor,
    required this.isPartial,
    required this.gaugeLevel,
  });
}

class HpScoreCalculator {
  final AppDatabase _db;

  const HpScoreCalculator(this._db);

  /// Normalize E-code tags from various formats to "E471" format.
  /// Handles: "en:e471", "E471", "e471", "E 471", "E-471"
  static String normalizeECode(String tag) {
    var code = tag.trim().toLowerCase();
    // Remove "en:" prefix from OFF format
    if (code.startsWith('en:')) {
      code = code.substring(3);
    }
    // Remove spaces and hyphens
    code = code.replaceAll(' ', '').replaceAll('-', '');
    // Ensure starts with 'e' followed by digits
    final match = RegExp(r'^e(\d{3,4}[a-z]?)$').firstMatch(code);
    if (match == null) return tag; // Return original if no match
    return 'E${match.group(1)!}';
  }

  /// Full HP Score — all data available (API sources)
  Future<HpScoreResult> calculateFull({
    required List<String> additivesTags,
    required NutrimentsEntity nutriments,
    int? novaGroup,
  }) async {
    final chemicalLoad = await _calculateChemicalLoad(additivesTags);
    final riskFactor = _calculateRiskFactor(nutriments);
    final nutriFactor = _calculateNutriFactor(nutriments, novaGroup);

    final hpScore = (100 -
            (chemicalLoad * ScoreConstants.chemicalWeight) -
            (riskFactor * ScoreConstants.riskWeight) +
            (nutriFactor * ScoreConstants.nutriWeight))
        .clamp(0.0, 100.0);

    return HpScoreResult(
      hpScore: hpScore,
      chemicalLoad: chemicalLoad,
      riskFactor: riskFactor,
      nutriFactor: nutriFactor,
      isPartial: false,
      gaugeLevel: ScoreConstants.hpToGauge(hpScore),
    );
  }

  /// Partial HP Score — only chemical load (OCR-only)
  Future<HpScoreResult> calculatePartial({
    required List<String> additivesTags,
  }) async {
    final chemicalLoad = await _calculateChemicalLoad(additivesTags);

    // Partial score: only chemical load component, no risk/nutri
    final hpScore = (100 - (chemicalLoad * ScoreConstants.chemicalWeight))
        .clamp(0.0, 100.0);

    return HpScoreResult(
      hpScore: hpScore,
      chemicalLoad: chemicalLoad,
      riskFactor: null,
      nutriFactor: null,
      isPartial: true,
      gaugeLevel: ScoreConstants.hpToGauge(hpScore),
    );
  }

  Future<double> _calculateChemicalLoad(List<String> additivesTags) async {
    if (additivesTags.isEmpty) return 0.0;

    double totalPenalty = 0.0;

    for (final tag in additivesTags) {
      final eCode = normalizeECode(tag);
      final riskLevel = await _getAdditiveRiskLevel(eCode);
      totalPenalty += ScoreConstants.additivePenalties[riskLevel] ?? 12.0;
    }

    // Normalize to 0-100 scale, cap at 100
    return min(totalPenalty, 100.0);
  }

  Future<int> _getAdditiveRiskLevel(String eCode) async {
    try {
      final query = _db.select(_db.additives)
        ..where((t) => t.eNumber.equals(eCode));
      final row = await query.getSingleOrNull();
      return row?.riskLevel ?? 3; // Default moderate if not found
    } catch (_) {
      return 3; // Default moderate on error
    }
  }

  double _calculateRiskFactor(NutrimentsEntity n) {
    final sugarRatio =
        min((n.sugars ?? 0) / ScoreConstants.sugarMaxRef, 1.0) * 100;
    final saltRatio =
        min((n.salt ?? 0) / ScoreConstants.saltMaxRef, 1.0) * 100;
    final satFatRatio =
        min((n.saturatedFat ?? 0) / ScoreConstants.saturatedFatMaxRef, 1.0) *
            100;

    return (sugarRatio * ScoreConstants.sugarWeight) +
        (saltRatio * ScoreConstants.saltWeight) +
        (satFatRatio * ScoreConstants.saturatedFatWeight);
  }

  double _calculateNutriFactor(NutrimentsEntity n, int? novaGroup) {
    final fiberScore =
        min((n.fiber ?? 0) / ScoreConstants.fiberExcellent, 1.0) * 100;
    final proteinScore =
        min((n.proteins ?? 0) / ScoreConstants.proteinExcellent, 1.0) * 100;
    final naturalness =
        ScoreConstants.novaNaturalness[novaGroup] ?? 0.0;

    return (fiberScore * ScoreConstants.fiberWeight) +
        (proteinScore * ScoreConstants.proteinWeight) +
        (naturalness * ScoreConstants.naturalnessWeight);
  }
}
```

**Step 2: Verify build compiles**

Run: `flutter analyze lib/core/services/hp_score_calculator.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/core/services/hp_score_calculator.dart
git commit -m "feat: add HP Score calculator service with full and partial modes"
```

---

## Task 3: ProductSource Interface & ProductResolveResult

**Files:**
- Create: `lib/features/product/data/datasources/product_source.dart`
- Reference: `lib/features/product/domain/entities/product_entity.dart` (read-only)

**Step 1: Create ProductSource interface and ProductResolver**

Create `lib/features/product/data/datasources/product_source.dart`:

```dart
import '../../domain/entities/product_entity.dart';

/// Strategy interface for product resolution sources.
/// Each source is tried in priority order (lower = first).
abstract interface class ProductSource {
  String get name;
  int get priority;
  Duration get timeout;

  /// Returns a ProductEntity if found, null if not found.
  /// Should NOT throw — catch errors internally and return null.
  Future<ProductEntity?> resolve(String barcode);
}

class ProductResolveResult {
  final ProductEntity? product;
  final String? resolvedBy;
  final bool hasIngredients;
  final List<String> triedSources;

  const ProductResolveResult({
    this.product,
    this.resolvedBy,
    this.hasIngredients = false,
    this.triedSources = const [],
  });

  bool get isFound => product != null;
}

/// Tries each ProductSource in priority order, returns first successful result.
class ProductResolver {
  final List<ProductSource> _sources;

  ProductResolver(List<ProductSource> sources)
      : _sources = List.of(sources)..sort((a, b) => a.priority.compareTo(b.priority));

  Future<ProductResolveResult> resolve(String barcode) async {
    final triedSources = <String>[];

    for (final source in _sources) {
      triedSources.add(source.name);
      try {
        final product = await source.resolve(barcode).timeout(source.timeout);
        if (product != null) {
          final hasIngredients = product.ingredientsText != null &&
              product.ingredientsText!.isNotEmpty;
          return ProductResolveResult(
            product: product,
            resolvedBy: source.name,
            hasIngredients: hasIngredients,
            triedSources: triedSources,
          );
        }
      } catch (_) {
        // Timeout or error — silently move to next source
        continue;
      }
    }

    return ProductResolveResult(triedSources: triedSources);
  }
}
```

**Step 2: Verify build**

Run: `flutter analyze lib/features/product/data/datasources/product_source.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/product/data/datasources/product_source.dart
git commit -m "feat: add ProductSource strategy interface and ProductResolver"
```

---

## Task 4: CommunityProductSource — Supabase Community DB

**Files:**
- Create: `lib/features/product/data/datasources/community_product_source.dart`
- Modify: `lib/features/product/data/models/product_dto.dart:8-101` — add `fromCommunityRow` factory
- Reference: `lib/features/product/data/datasources/product_source.dart` (read-only)

**Step 1: Add fromCommunityRow to ProductDto**

In `lib/features/product/data/models/product_dto.dart`, add after the `fromOffProduct` method (after line 25):

```dart
  /// Maps a Supabase community_products row to [ProductEntity].
  static ProductEntity fromCommunityRow(Map<String, dynamic> row) {
    final additivesTags = (row['additives_tags'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];

    final nutrimentsMap = row['nutriments'] as Map<String, dynamic>? ?? {};

    return ProductEntity(
      barcode: row['barcode'] as String,
      productName: row['product_name'] as String?,
      brands: row['brand'] as String?,
      imageUrl: row['image_url'] as String?,
      ingredientsText: row['ingredients_text'] as String?,
      additivesTags: additivesTags,
      novaGroup: row['nova_group'] as int?,
      nutriscoreGrade: row['nutriscore_grade'] as String?,
      nutriments: NutrimentsEntity(
        energyKcal: (nutrimentsMap['energy_kcal'] as num?)?.toDouble(),
        fat: (nutrimentsMap['fat'] as num?)?.toDouble(),
        saturatedFat: (nutrimentsMap['saturated_fat'] as num?)?.toDouble(),
        sugars: (nutrimentsMap['sugars'] as num?)?.toDouble(),
        salt: (nutrimentsMap['salt'] as num?)?.toDouble(),
        fiber: (nutrimentsMap['fiber'] as num?)?.toDouble(),
        proteins: (nutrimentsMap['proteins'] as num?)?.toDouble(),
      ),
      hpScore: (row['hp_score'] as num?)?.toDouble(),
      hpChemicalLoad: (row['hp_chemical_load'] as num?)?.toDouble(),
      hpRiskFactor: (row['hp_risk_factor'] as num?)?.toDouble(),
      hpNutriFactor: (row['hp_nutri_factor'] as num?)?.toDouble(),
    );
  }
```

Add necessary import at top of `product_dto.dart`:

```dart
import '../../domain/entities/nutriments_entity.dart';
```

**Step 2: Create CommunityProductSource**

Create `lib/features/product/data/datasources/community_product_source.dart`:

```dart
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/product_entity.dart';
import '../models/product_dto.dart';
import 'product_source.dart';

final class CommunityProductSource implements ProductSource {
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
      'source': source,
      'ingredients_photo_url': ingredientsPhotoUrl,
      'added_by': userId,
    });
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
```

**Step 3: Verify build**

Run: `flutter analyze lib/features/product/data/datasources/community_product_source.dart`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/features/product/data/models/product_dto.dart
git add lib/features/product/data/datasources/community_product_source.dart
git commit -m "feat: add CommunityProductSource with Supabase integration"
```

---

## Task 5: OpenFoodFactsSource — Wrap Existing Remote DataSource

**Files:**
- Create: `lib/features/product/data/datasources/off_product_source.dart`
- Reference: `lib/features/product/data/datasources/product_remote_datasource.dart` (read-only, wraps it)
- Reference: `lib/features/product/data/datasources/product_source.dart` (read-only)

**Step 1: Create OFF wrapper source**

Create `lib/features/product/data/datasources/off_product_source.dart`:

```dart
import 'package:logger/logger.dart';

import '../../domain/entities/product_entity.dart';
import 'product_remote_datasource.dart';
import 'product_source.dart';

/// Wraps existing ProductRemoteDataSource (Open Food Facts) as a ProductSource.
final class OpenFoodFactsSource implements ProductSource {
  final ProductRemoteDataSource _remoteDataSource;
  final _logger = Logger();

  OpenFoodFactsSource(this._remoteDataSource);

  @override
  String get name => 'open_food_facts';

  @override
  int get priority => 1;

  @override
  Duration get timeout => const Duration(seconds: 5);

  @override
  Future<ProductEntity?> resolve(String barcode) async {
    try {
      return await _remoteDataSource.getProduct(barcode);
    } catch (e) {
      _logger.w('OpenFoodFactsSource error for $barcode: $e');
      return null;
    }
  }
}
```

**Step 2: Verify build**

Run: `flutter analyze lib/features/product/data/datasources/off_product_source.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/product/data/datasources/off_product_source.dart
git commit -m "feat: wrap Open Food Facts remote datasource as ProductSource"
```

---

## Task 6: BarcodeLookupSource — UPC Item DB API

**Files:**
- Create: `lib/features/product/data/datasources/barcode_lookup_source.dart`
- Modify: `lib/core/constants/api_constants.dart:1-10` — add UPC Item DB URL

**Step 1: Add API constant**

In `lib/core/constants/api_constants.dart`, add after line 8 (before `requestTimeout`):

```dart
  // UPC Item DB (free barcode lookup)
  static const String upcItemDbBaseUrl =
      'https://api.upcitemdb.com/prod/trial/lookup';
```

**Step 2: Create BarcodeLookupSource**

Create `lib/features/product/data/datasources/barcode_lookup_source.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../../../../core/constants/api_constants.dart';
import '../../domain/entities/product_entity.dart';
import 'product_source.dart';

/// UPC Item DB — free barcode lookup. Usually returns only product name and brand.
/// Ingredients/nutrition are rarely available.
final class BarcodeLookupSource implements ProductSource {
  final Dio _dio;
  final _logger = Logger();

  BarcodeLookupSource(this._dio);

  @override
  String get name => 'barcode_lookup';

  @override
  int get priority => 2;

  @override
  Duration get timeout => const Duration(seconds: 5);

  @override
  Future<ProductEntity?> resolve(String barcode) async {
    try {
      final response = await _dio.get(
        ApiConstants.upcItemDbBaseUrl,
        queryParameters: {'upc': barcode},
        options: Options(
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'NutriLens/1.0.0',
          },
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode != 200) return null;

      final data = response.data as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>?;

      if (items == null || items.isEmpty) return null;

      final item = items.first as Map<String, dynamic>;
      final title = item['title'] as String?;
      final brand = item['brand'] as String?;

      if (title == null || title.isEmpty) return null;

      return ProductEntity(
        barcode: barcode,
        productName: title,
        brands: brand,
        imageUrl: _extractImageUrl(item),
      );
    } catch (e) {
      _logger.w('BarcodeLookupSource error for $barcode: $e');
      return null;
    }
  }

  String? _extractImageUrl(Map<String, dynamic> item) {
    final images = item['images'] as List<dynamic>?;
    if (images != null && images.isNotEmpty) {
      return images.first as String?;
    }
    return null;
  }
}
```

**Step 3: Verify build**

Run: `flutter analyze lib/features/product/data/datasources/barcode_lookup_source.dart`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/core/constants/api_constants.dart
git add lib/features/product/data/datasources/barcode_lookup_source.dart
git commit -m "feat: add BarcodeLookupSource with UPC Item DB integration"
```

---

## Task 7: Update ProductRepositoryImpl — Use ProductResolver

**Files:**
- Modify: `lib/features/product/data/repositories/product_repository_impl.dart:1-117`

**Step 1: Refactor repository to use ProductResolver**

Replace the entire file content of `lib/features/product/data/repositories/product_repository_impl.dart`:

```dart
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_local_datasource.dart';
import '../datasources/product_source.dart';

final class ProductRepositoryImpl implements ProductRepository {
  final ProductResolver _resolver;
  final ProductLocalDataSource _localDataSource;
  final NetworkInfo _networkInfo;

  const ProductRepositoryImpl({
    required ProductResolver resolver,
    required ProductLocalDataSource localDataSource,
    required NetworkInfo networkInfo,
  })  : _resolver = resolver,
        _localDataSource = localDataSource,
        _networkInfo = networkInfo;

  @override
  Future<Either<Failure, ProductEntity>> getProduct(String barcode) async {
    // 1. Check local cache
    try {
      final cached = await _localDataSource.getProduct(barcode);
      if (cached != null) {
        final stale = await _localDataSource.isStale(barcode);
        if (!stale) {
          return Right(cached);
        }
        // Stale cache — try resolver, fall back to stale
        return _resolveWithFallback(barcode, staleCached: cached);
      }
    } on CacheException {
      // Cache read failed, continue to resolver
    }

    // 2. No cache — resolve from remote sources
    return _resolveFromSources(barcode);
  }

  @override
  Future<Either<Failure, void>> cacheProduct(ProductEntity product) async {
    try {
      await _localDataSource.cacheProduct(product);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, ProductEntity>> getCachedProduct(
    String barcode,
  ) async {
    try {
      final cached = await _localDataSource.getProduct(barcode);
      if (cached == null) {
        return const Left(NotFoundFailure('Product not found in cache'));
      }
      return Right(cached);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  Future<Either<Failure, ProductEntity>> _resolveWithFallback(
    String barcode, {
    required ProductEntity staleCached,
  }) async {
    final isOnline = await _networkInfo.isConnected;
    if (!isOnline) {
      return Right(staleCached);
    }

    try {
      final result = await _resolver.resolve(barcode);
      if (result.isFound) {
        await _localDataSource.cacheProduct(result.product!);
        return Right(result.product!);
      }
      // Not found in any source — return stale cache
      return Right(staleCached);
    } catch (_) {
      return Right(staleCached);
    }
  }

  Future<Either<Failure, ProductEntity>> _resolveFromSources(
    String barcode,
  ) async {
    final isOnline = await _networkInfo.isConnected;
    if (!isOnline) {
      return const Left(NetworkFailure());
    }

    try {
      final result = await _resolver.resolve(barcode);
      if (result.isFound) {
        await _localDataSource.cacheProduct(result.product!);
        return Right(result.product!);
      }
      return const Left(NotFoundFailure());
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
```

**Step 2: Verify build**

Run: `flutter analyze lib/features/product/data/repositories/product_repository_impl.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/product/data/repositories/product_repository_impl.dart
git commit -m "refactor: update ProductRepositoryImpl to use Strategy Pattern resolver"
```

---

## Task 8: Update Riverpod Providers

**Files:**
- Modify: `lib/features/product/presentation/providers/product_provider.dart:1-54`

**Step 1: Add resolver and new source providers**

Replace entire content of `lib/features/product/presentation/providers/product_provider.dart`:

```dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/drift/app_database.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/services/hp_score_calculator.dart';
import '../../data/datasources/barcode_lookup_source.dart';
import '../../data/datasources/community_product_source.dart';
import '../../data/datasources/off_product_source.dart';
import '../../data/datasources/product_local_datasource.dart';
import '../../data/datasources/product_remote_datasource.dart';
import '../../data/datasources/product_source.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/usecases/get_product_usecase.dart';

// Database provider — overridden in main.dart
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('AppDatabase must be overridden');
});

final networkInfoProvider = Provider<NetworkInfo>((ref) {
  return NetworkInfoImpl(Connectivity());
});

// --- Data Sources ---

final productRemoteDataSourceProvider =
    Provider<ProductRemoteDataSource>((ref) {
  return ProductRemoteDataSourceImpl();
});

final productLocalDataSourceProvider =
    Provider<ProductLocalDataSource>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ProductLocalDataSourceImpl(db);
});

final communityProductSourceProvider =
    Provider<CommunityProductSource>((ref) {
  final client = Supabase.instance.client;
  return CommunityProductSource(client);
});

final offProductSourceProvider = Provider<OpenFoodFactsSource>((ref) {
  final remote = ref.watch(productRemoteDataSourceProvider);
  return OpenFoodFactsSource(remote);
});

final barcodeLookupSourceProvider = Provider<BarcodeLookupSource>((ref) {
  return BarcodeLookupSource(Dio());
});

// --- Resolver ---

final productResolverProvider = Provider<ProductResolver>((ref) {
  return ProductResolver([
    ref.watch(communityProductSourceProvider),
    ref.watch(offProductSourceProvider),
    ref.watch(barcodeLookupSourceProvider),
  ]);
});

// --- Repository ---

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl(
    resolver: ref.watch(productResolverProvider),
    localDataSource: ref.watch(productLocalDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

// --- Use Cases ---

final getProductUseCaseProvider = Provider<GetProductUseCase>((ref) {
  return GetProductUseCase(ref.watch(productRepositoryProvider));
});

// --- HP Score Calculator ---

final hpScoreCalculatorProvider = Provider<HpScoreCalculator>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return HpScoreCalculator(db);
});

// --- UI Providers ---

/// Fetches product by barcode. Use `ref.watch(productByBarcodeProvider(barcode))`.
final productByBarcodeProvider =
    FutureProvider.family<ProductEntity?, String>((ref, barcode) async {
  final useCase = ref.watch(getProductUseCaseProvider);
  final result = await useCase(barcode);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (product) => product,
  );
});
```

**Step 2: Verify build**

Run: `flutter analyze lib/features/product/presentation/providers/product_provider.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/product/presentation/providers/product_provider.dart
git commit -m "feat: update providers with Strategy Pattern resolver and HP calculator"
```

---

## Task 9: Add New Packages — google_mlkit_text_recognition & image_picker

**Files:**
- Modify: `pubspec.yaml`

**Step 1: Add packages**

Run:

```bash
flutter pub add google_mlkit_text_recognition image_picker
```

**Step 2: Verify install**

Run: `flutter pub get`
Expected: No errors

**Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add google_mlkit_text_recognition and image_picker packages"
```

---

## Task 10: IngredientsOcrService — ML Kit OCR + Parser

**Files:**
- Create: `lib/core/services/ingredients_ocr_service.dart`

**Step 1: Create the OCR service with parser**

Create `lib/core/services/ingredients_ocr_service.dart`:

```dart
import 'dart:math';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:logger/logger.dart';

import '../../config/drift/app_database.dart';

class IngredientsParseResult {
  final String cleanedText;
  final List<String> detectedAdditives;
  final List<String> unmatchedAdditives;
  final double confidence;

  const IngredientsParseResult({
    required this.cleanedText,
    required this.detectedAdditives,
    required this.unmatchedAdditives,
    required this.confidence,
  });
}

class IngredientsOcrService {
  final AppDatabase _db;
  final _logger = Logger();
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  IngredientsOcrService(this._db);

  /// Extract raw text from image using ML Kit
  Future<String> extractText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    return recognizedText.text;
  }

  /// Parse ingredients text, extract E-codes, match against Additives DB
  Future<IngredientsParseResult> parseIngredients(String rawText) async {
    // Step 1: Clean text
    final cleaned = _cleanText(rawText);

    // Step 2: Extract E-codes via regex
    final eCodes = _extractECodes(cleaned);

    // Step 3: Match Turkish names from DB
    final turkishMatches = await _matchTurkishNames(cleaned);
    final allCodes = {...eCodes, ...turkishMatches};

    // Step 4: Match against Additives DB
    final detected = <String>[];
    final unmatched = <String>[];

    for (final code in allCodes) {
      final found = await _existsInDb(code);
      if (found) {
        detected.add(code);
      } else {
        unmatched.add(code);
      }
    }

    // Step 5: Calculate confidence
    final confidence = _calculateConfidence(
      eCodeCount: allCodes.length,
      textLength: cleaned.length,
    );

    return IngredientsParseResult(
      cleanedText: cleaned,
      detectedAdditives: detected,
      unmatchedAdditives: unmatched,
      confidence: confidence,
    );
  }

  void dispose() {
    _textRecognizer.close();
  }

  // --- Private helpers ---

  String _cleanText(String raw) {
    var text = raw;

    // Find "İçindekiler" or "Ingredients" header and take text after it
    final headerPatterns = [
      RegExp(r'[İi]çindekiler\s*:?\s*', caseSensitive: false),
      RegExp(r'[Ii]ngredients\s*:?\s*', caseSensitive: false),
    ];
    for (final pattern in headerPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        text = text.substring(match.end);
        break;
      }
    }

    // Cut at "Besin Değerleri" or "Nutrition Facts"
    final cutPatterns = [
      RegExp(r'[Bb]esin\s+[Dd]eğer', caseSensitive: false),
      RegExp(r'[Nn]utrition\s+[Ff]act', caseSensitive: false),
      RegExp(r'[Bb]esin\s+[İi]çeriği', caseSensitive: false),
    ];
    for (final pattern in cutPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        text = text.substring(0, match.start);
        break;
      }
    }

    // Normalize whitespace
    text = text.replaceAll(RegExp(r'\n+'), ' ');
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ');
    text = text.trim();

    return text;
  }

  Set<String> _extractECodes(String text) {
    final codes = <String>{};

    // Pattern 1: E followed by 3-4 digits and optional letter suffix
    // Handles: E471, E160a, E 471, E-471
    final pattern = RegExp(
      r'[Ee]\s?-?\s?(\d{3,4}\s?[a-zA-Z]?)',
    );

    for (final match in pattern.allMatches(text)) {
      final raw = match.group(0) ?? '';
      final normalized = _normalizeECode(raw);
      if (normalized != null) {
        codes.add(normalized);
      }
    }

    return codes;
  }

  String? _normalizeECode(String raw) {
    var code = raw.trim().toUpperCase();
    code = code.replaceAll(RegExp(r'[\s-]'), '');

    final match = RegExp(r'^E(\d{3,4}[A-Za-z]?)$').firstMatch(code);
    if (match == null) return null;

    return 'E${match.group(1)!.toLowerCase()}';
  }

  Future<Set<String>> _matchTurkishNames(String text) async {
    final matches = <String>{};
    final lowerText = text.toLowerCase();

    try {
      // Get all additives with Turkish names from DB
      final allAdditives = await _db.select(_db.additives).get();

      for (final additive in allAdditives) {
        final nameTr = additive.nameTr?.toLowerCase();
        if (nameTr != null && nameTr.isNotEmpty && lowerText.contains(nameTr)) {
          matches.add(additive.eNumber);
        }
      }
    } catch (e) {
      _logger.w('Turkish name matching failed: $e');
    }

    return matches;
  }

  Future<bool> _existsInDb(String eCode) async {
    try {
      final query = _db.select(_db.additives)
        ..where((t) => t.eNumber.equals(eCode));
      final row = await query.getSingleOrNull();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  double _calculateConfidence({
    required int eCodeCount,
    required int textLength,
  }) {
    if (textLength < 10) return 0.0;
    if (eCodeCount >= 3) return min(0.8 + (eCodeCount * 0.02), 1.0);
    if (eCodeCount >= 1) return 0.5 + (eCodeCount * 0.15);
    // No E-codes but meaningful text — possibly natural product
    if (textLength > 30) return 0.3;
    return 0.1;
  }
}
```

**Step 2: Verify build**

Run: `flutter analyze lib/core/services/ingredients_ocr_service.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/core/services/ingredients_ocr_service.dart
git commit -m "feat: add IngredientsOcrService with ML Kit OCR and E-code parser"
```

---

## Task 11: OCR Provider — Riverpod State Management

**Files:**
- Create: `lib/features/product/presentation/providers/ocr_provider.dart`

**Step 1: Create OCR provider**

Create `lib/features/product/presentation/providers/ocr_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/ingredients_ocr_service.dart';
import 'product_provider.dart';

final ocrServiceProvider = Provider<IngredientsOcrService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final service = IngredientsOcrService(db);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Process an image and return parsed ingredients.
final ocrResultProvider =
    FutureProvider.family<IngredientsParseResult, String>(
        (ref, imagePath) async {
  final ocrService = ref.watch(ocrServiceProvider);
  final rawText = await ocrService.extractText(imagePath);
  return ocrService.parseIngredients(rawText);
});
```

**Step 2: Verify build**

Run: `flutter analyze lib/features/product/presentation/providers/ocr_provider.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/product/presentation/providers/ocr_provider.dart
git commit -m "feat: add OCR Riverpod providers"
```

---

## Task 12: SubmitCommunityProductUseCase

**Files:**
- Create: `lib/features/product/domain/usecases/submit_community_product_usecase.dart`

**Step 1: Create the use case**

Create `lib/features/product/domain/usecases/submit_community_product_usecase.dart`:

```dart
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../data/datasources/community_product_source.dart';
import '../../data/datasources/product_local_datasource.dart';
import '../entities/product_entity.dart';

class SubmitCommunityProductUseCase {
  final CommunityProductSource _communitySource;
  final ProductLocalDataSource _localDataSource;

  const SubmitCommunityProductUseCase({
    required CommunityProductSource communitySource,
    required ProductLocalDataSource localDataSource,
  })  : _communitySource = communitySource,
        _localDataSource = localDataSource;

  Future<Either<Failure, void>> call({
    required ProductEntity product,
    required String userId,
    String? ingredientsPhotoUrl,
    String source = 'ocr',
  }) async {
    try {
      // Save to Supabase community DB
      await _communitySource.addProduct(
        product: product,
        ingredientsPhotoUrl: ingredientsPhotoUrl,
        userId: userId,
        source: source,
      );

      // Cache locally in Drift
      await _localDataSource.cacheProduct(product);

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to submit product: $e'));
    }
  }
}
```

**Step 2: Add provider**

Add to `lib/features/product/presentation/providers/product_provider.dart` at the end, before the closing of the file:

```dart
final submitCommunityProductUseCaseProvider =
    Provider<SubmitCommunityProductUseCase>((ref) {
  return SubmitCommunityProductUseCase(
    communitySource: ref.watch(communityProductSourceProvider),
    localDataSource: ref.watch(productLocalDataSourceProvider),
  );
});
```

Add import at top of `product_provider.dart`:

```dart
import '../../domain/usecases/submit_community_product_usecase.dart';
```

**Step 3: Verify build**

Run: `flutter analyze lib/features/product/domain/usecases/submit_community_product_usecase.dart`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/features/product/domain/usecases/submit_community_product_usecase.dart
git add lib/features/product/presentation/providers/product_provider.dart
git commit -m "feat: add SubmitCommunityProductUseCase for saving OCR results"
```

---

## Task 13: Route Names & Router Updates

**Files:**
- Modify: `lib/config/router/route_names.dart:1-25`
- Modify: `lib/config/router/app_router.dart:1-127`

**Step 1: Add new route names**

In `lib/config/router/route_names.dart`, add after line 15 (`additiveDetail`):

```dart
  static const String productNotFound = 'productNotFound';
  static const String ingredientsCamera = 'ingredientsCamera';
  static const String ingredientsVerification = 'ingredientsVerification';
  static const String manualIngredients = 'manualIngredients';
```

**Step 2: Add new routes in app_router.dart**

In `lib/config/router/app_router.dart`, add new imports at the top after line 14:

```dart
import '../../features/product/presentation/screens/product_not_found_screen.dart';
import '../../features/product/presentation/screens/ingredients_camera_screen.dart';
import '../../features/product/presentation/screens/ingredients_verification_screen.dart';
import '../../features/product/presentation/screens/manual_ingredients_screen.dart';
```

After the existing `/product/:barcode` route (after line 124, before `],`), add:

```dart
      GoRoute(
        path: '/product/:barcode/not-found',
        name: RouteNames.productNotFound,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final barcode = state.pathParameters['barcode']!;
          return ProductNotFoundScreen(barcode: barcode);
        },
      ),
      GoRoute(
        path: '/product/:barcode/ocr',
        name: RouteNames.ingredientsCamera,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final barcode = state.pathParameters['barcode']!;
          return IngredientsCameraScreen(barcode: barcode);
        },
      ),
      GoRoute(
        path: '/product/:barcode/verify',
        name: RouteNames.ingredientsVerification,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final barcode = state.pathParameters['barcode']!;
          final extra = state.extra as Map<String, dynamic>?;
          return IngredientsVerificationScreen(
            barcode: barcode,
            extra: extra,
          );
        },
      ),
      GoRoute(
        path: '/product/:barcode/manual',
        name: RouteNames.manualIngredients,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final barcode = state.pathParameters['barcode']!;
          return ManualIngredientsScreen(barcode: barcode);
        },
      ),
```

NOTE: These routes reference screens that will be created in Tasks 14-17. The build will not pass until those screens exist. This is expected — we're setting up the routing structure first.

**Step 3: Commit**

```bash
git add lib/config/router/route_names.dart lib/config/router/app_router.dart
git commit -m "feat: add OCR and community routes to GoRouter"
```

---

## Task 14: ProductNotFoundScreen

**Files:**
- Create: `lib/features/product/presentation/screens/product_not_found_screen.dart`

**Step 1: Create the screen**

Create `lib/features/product/presentation/screens/product_not_found_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';

class ProductNotFoundScreen extends StatelessWidget {
  final String barcode;

  const ProductNotFoundScreen({super.key, required this.barcode});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(l10n.productDetail),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: context.colors.surfaceCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.border),
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  size: 44,
                  color: context.colors.textMuted,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                l10n.productNotFound,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle — encouraging community contribution
              Text(
                'Bu ürün henüz veritabanımızda yok.\n'
                'İçindekiler listesinin fotoğrafını çekerek\n'
                'katkı madde analizi yapabilir ve bu ürünü\n'
                'herkes için veritabanına ekleyebilirsiniz!',
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // CTA: Take Photo
              GestureDetector(
                onTap: () => context.go('/product/$barcode/ocr'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: context.colors.primaryGradient,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_rounded,
                          color: Colors.black, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'İçindekileri Fotoğrafla',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // CTA: Manual Entry
              GestureDetector(
                onTap: () => context.go('/product/$barcode/manual'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceCard,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_note_rounded,
                          color: context.colors.textPrimary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Manuel Gir',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/product/presentation/screens/product_not_found_screen.dart
git commit -m "feat: add ProductNotFoundScreen with OCR and manual entry CTAs"
```

---

## Task 15: IngredientsCameraScreen

**Files:**
- Create: `lib/features/product/presentation/screens/ingredients_camera_screen.dart`

**Step 1: Create the camera screen**

Create `lib/features/product/presentation/screens/ingredients_camera_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/ocr_provider.dart';

class IngredientsCameraScreen extends ConsumerStatefulWidget {
  final String barcode;

  const IngredientsCameraScreen({super.key, required this.barcode});

  @override
  ConsumerState<IngredientsCameraScreen> createState() =>
      _IngredientsCameraScreenState();
}

class _IngredientsCameraScreenState
    extends ConsumerState<IngredientsCameraScreen> {
  final _picker = ImagePicker();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Auto-launch camera on enter
    WidgetsBinding.instance.addPostFrameCallback((_) => _takePicture());
  }

  Future<void> _takePicture() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 90,
    );

    if (image == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final ocrService = ref.read(ocrServiceProvider);
      final rawText = await ocrService.extractText(image.path);
      final result = await ocrService.parseIngredients(rawText);

      if (!mounted) return;

      if (result.confidence < 0.1) {
        // OCR failed — show retry dialog
        _showOcrFailedDialog();
        return;
      }

      // Navigate to verification screen with result
      context.go(
        '/product/${widget.barcode}/verify',
        extra: {
          'cleanedText': result.cleanedText,
          'detectedAdditives': result.detectedAdditives,
          'unmatchedAdditives': result.unmatchedAdditives,
          'confidence': result.confidence,
          'imagePath': image.path,
        },
      );
    } catch (e) {
      if (mounted) _showOcrFailedDialog();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showOcrFailedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surfaceCard,
        title: Text(
          'Metin Okunamadı',
          style: TextStyle(color: context.colors.textPrimary),
        ),
        content: Text(
          'İçindekiler listesi okunamadı. Lütfen daha yakın ve net bir fotoğraf çekin.',
          style: TextStyle(color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/product/${widget.barcode}/manual');
            },
            child: Text(
              'Manuel Gir',
              style: TextStyle(color: context.colors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _takePicture();
            },
            child: Text(
              'Tekrar Çek',
              style: TextStyle(color: context.colors.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('İçindekiler Fotoğrafı'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: _isProcessing
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: context.colors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'İçindekiler analiz ediliyor...',
                    style: TextStyle(
                      fontSize: 16,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    size: 64,
                    color: context.colors.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'İçindekiler listesinin fotoğrafını çekin',
                    style: TextStyle(
                      fontSize: 16,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        gradient: context.colors.primaryGradient,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt_rounded,
                              color: Colors.black, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Fotoğraf Çek',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/product/presentation/screens/ingredients_camera_screen.dart
git commit -m "feat: add IngredientsCameraScreen with ML Kit OCR processing"
```

---

## Task 16: Widgets — AdditiveChip, ChemicalLoadGauge, CommunityBadge

**Files:**
- Create: `lib/features/product/presentation/widgets/additive_chip.dart`
- Create: `lib/features/product/presentation/widgets/chemical_load_gauge.dart`
- Create: `lib/features/product/presentation/widgets/community_badge.dart`

**Step 1: Create AdditiveChip**

Create `lib/features/product/presentation/widgets/additive_chip.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class AdditiveChip extends StatelessWidget {
  final String eCode;
  final String? name;
  final int riskLevel;

  const AdditiveChip({
    super.key,
    required this.eCode,
    this.name,
    required this.riskLevel,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.colors.riskColor(riskLevel);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            eCode,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (name != null) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name!,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(width: 6),
          Text(
            '$riskLevel/5',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Create ChemicalLoadGauge**

Create `lib/features/product/presentation/widgets/chemical_load_gauge.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/constants/score_constants.dart';
import '../../../../core/theme/app_colors.dart';

class ChemicalLoadGauge extends StatelessWidget {
  final double chemicalLoad;
  final bool isPartial;

  const ChemicalLoadGauge({
    super.key,
    required this.chemicalLoad,
    this.isPartial = false,
  });

  @override
  Widget build(BuildContext context) {
    final score = (100 - chemicalLoad).clamp(0.0, 100.0);
    final gaugeLevel = ScoreConstants.hpToGauge(score);
    final color = context.colors.gaugeColor(gaugeLevel);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isPartial ? 'Kimyasal Yük Analizi' : 'Kimyasal Yük',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${score.toStringAsFixed(0)}/100',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: context.colors.surfaceCard2,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          if (isPartial) ...[
            const SizedBox(height: 8),
            Text(
              'Besin değerleri bilinmediği için kısmi analiz',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

**Step 3: Create CommunityBadge**

Create `lib/features/product/presentation/widgets/community_badge.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class CommunityBadge extends StatelessWidget {
  const CommunityBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.info.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 14,
            color: context.colors.info,
          ),
          const SizedBox(width: 4),
          Text(
            'Topluluk Katkısı',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.colors.info,
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 4: Commit**

```bash
git add lib/features/product/presentation/widgets/additive_chip.dart
git add lib/features/product/presentation/widgets/chemical_load_gauge.dart
git add lib/features/product/presentation/widgets/community_badge.dart
git commit -m "feat: add AdditiveChip, ChemicalLoadGauge, and CommunityBadge widgets"
```

---

## Task 17: IngredientsVerificationScreen

**Files:**
- Create: `lib/features/product/presentation/screens/ingredients_verification_screen.dart`

**Step 1: Create the verification screen**

Create `lib/features/product/presentation/screens/ingredients_verification_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/hp_score_calculator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product_entity.dart';
import '../providers/product_provider.dart';
import '../widgets/additive_chip.dart';
import '../widgets/chemical_load_gauge.dart';

class IngredientsVerificationScreen extends ConsumerStatefulWidget {
  final String barcode;
  final Map<String, dynamic>? extra;

  const IngredientsVerificationScreen({
    super.key,
    required this.barcode,
    this.extra,
  });

  @override
  ConsumerState<IngredientsVerificationScreen> createState() =>
      _IngredientsVerificationScreenState();
}

class _IngredientsVerificationScreenState
    extends ConsumerState<IngredientsVerificationScreen> {
  late TextEditingController _ingredientsController;
  late TextEditingController _productNameController;
  late TextEditingController _brandController;
  late List<String> _detectedAdditives;
  late List<String> _unmatchedAdditives;
  double? _confidence;
  String? _imagePath;
  HpScoreResult? _scoreResult;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final extra = widget.extra ?? {};
    _ingredientsController = TextEditingController(
      text: extra['cleanedText'] as String? ?? '',
    );
    _productNameController = TextEditingController();
    _brandController = TextEditingController();
    _detectedAdditives =
        List<String>.from(extra['detectedAdditives'] as List? ?? []);
    _unmatchedAdditives =
        List<String>.from(extra['unmatchedAdditives'] as List? ?? []);
    _confidence = extra['confidence'] as double?;
    _imagePath = extra['imagePath'] as String?;

    // Calculate score after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateScore());
  }

  @override
  void dispose() {
    _ingredientsController.dispose();
    _productNameController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  Future<void> _calculateScore() async {
    final calculator = ref.read(hpScoreCalculatorProvider);
    final allAdditives = [..._detectedAdditives, ..._unmatchedAdditives];

    final result = await calculator.calculatePartial(
      additivesTags: allAdditives,
    );

    setState(() => _scoreResult = result);
  }

  Future<void> _saveProduct() async {
    setState(() => _isSaving = true);

    try {
      final allAdditives = [..._detectedAdditives, ..._unmatchedAdditives];
      final product = ProductEntity(
        barcode: widget.barcode,
        productName: _productNameController.text.isNotEmpty
            ? _productNameController.text
            : null,
        brands:
            _brandController.text.isNotEmpty ? _brandController.text : null,
        ingredientsText: _ingredientsController.text,
        additivesTags: allAdditives,
        hpScore: _scoreResult?.hpScore,
        hpChemicalLoad: _scoreResult?.chemicalLoad,
        hpRiskFactor: _scoreResult?.riskFactor,
        hpNutriFactor: _scoreResult?.nutriFactor,
      );

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final submitUseCase = ref.read(submitCommunityProductUseCaseProvider);
      await submitUseCase(
        product: product,
        userId: userId,
        source: 'ocr',
      );

      if (!mounted) return;

      // Invalidate the product provider to reflect new data
      ref.invalidate(productByBarcodeProvider(widget.barcode));

      // Navigate to product detail
      context.go('/product/${widget.barcode}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bu ürünü veritabanımıza eklediniz!'),
          backgroundColor: context.colors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('İçerik Doğrulama'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name & brand
            TextField(
              controller: _productNameController,
              decoration: InputDecoration(
                labelText: 'Ürün Adı',
                labelStyle: TextStyle(color: context.colors.textMuted),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.primary),
                ),
              ),
              style: TextStyle(color: context.colors.textPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _brandController,
              decoration: InputDecoration(
                labelText: 'Marka',
                labelStyle: TextStyle(color: context.colors.textMuted),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.primary),
                ),
              ),
              style: TextStyle(color: context.colors.textPrimary),
            ),
            const SizedBox(height: 16),

            // Ingredients text (editable)
            Text(
              'İçindekiler Metni',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ingredientsController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'OCR ile okunan içindekiler metni...',
                hintStyle: TextStyle(color: context.colors.textMuted),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.primary),
                ),
              ),
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Detected additives
            if (_detectedAdditives.isNotEmpty) ...[
              Text(
                'Tespit Edilen Katkı Maddeleri',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _detectedAdditives
                    .map((code) => AdditiveChip(
                          eCode: code,
                          riskLevel: 3, // Will be resolved from DB at runtime
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Unmatched additives
            if (_unmatchedAdditives.isNotEmpty) ...[
              Text(
                'Veritabanında Bulunamayan E Kodları',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.warning,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _unmatchedAdditives
                    .map((code) => AdditiveChip(
                          eCode: code,
                          riskLevel: 3, // Default moderate
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Chemical load gauge
            if (_scoreResult != null) ...[
              ChemicalLoadGauge(
                chemicalLoad: _scoreResult!.chemicalLoad,
                isPartial: true,
              ),
              const SizedBox(height: 16),
            ],

            // Confidence indicator
            if (_confidence != null)
              Text(
                'OCR Güvenilirlik: ${(_confidence! * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textMuted,
                ),
              ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                // Retake photo
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.go('/product/${widget.barcode}/ocr'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceCard,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_rounded,
                              color: context.colors.textPrimary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Tekrar Çek',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Save
                Expanded(
                  child: GestureDetector(
                    onTap: _isSaving ? null : _saveProduct,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: context.colors.primaryGradient,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isSaving)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          else ...[
                            const Icon(Icons.check_rounded,
                                color: Colors.black, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'Onayla ve Kaydet',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/product/presentation/screens/ingredients_verification_screen.dart
git commit -m "feat: add IngredientsVerificationScreen with editable OCR results"
```

---

## Task 18: ManualIngredientsScreen

**Files:**
- Create: `lib/features/product/presentation/screens/manual_ingredients_screen.dart`

**Step 1: Create the manual entry screen**

Create `lib/features/product/presentation/screens/manual_ingredients_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/hp_score_calculator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product_entity.dart';
import '../providers/product_provider.dart';
import '../widgets/additive_chip.dart';
import '../widgets/chemical_load_gauge.dart';

class ManualIngredientsScreen extends ConsumerStatefulWidget {
  final String barcode;

  const ManualIngredientsScreen({super.key, required this.barcode});

  @override
  ConsumerState<ManualIngredientsScreen> createState() =>
      _ManualIngredientsScreenState();
}

class _ManualIngredientsScreenState
    extends ConsumerState<ManualIngredientsScreen> {
  final _ingredientsController = TextEditingController();
  final _productNameController = TextEditingController();
  final _brandController = TextEditingController();
  final _eCodeController = TextEditingController();

  final _manualECodes = <String>[];
  HpScoreResult? _scoreResult;
  bool _isSaving = false;

  @override
  void dispose() {
    _ingredientsController.dispose();
    _productNameController.dispose();
    _brandController.dispose();
    _eCodeController.dispose();
    super.dispose();
  }

  void _addECode() {
    final code = _eCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    // Validate E-code format
    final normalized = HpScoreCalculator.normalizeECode(code);
    if (!RegExp(r'^E\d{3,4}[a-z]?$', caseSensitive: false)
        .hasMatch(normalized)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Geçersiz E kodu formatı (örn: E471)'),
          backgroundColor: context.colors.warning,
        ),
      );
      return;
    }

    if (!_manualECodes.contains(normalized)) {
      setState(() {
        _manualECodes.add(normalized);
        _eCodeController.clear();
      });
      _calculateScore();
    }
  }

  void _removeECode(String code) {
    setState(() => _manualECodes.remove(code));
    _calculateScore();
  }

  Future<void> _calculateScore() async {
    if (_manualECodes.isEmpty) {
      setState(() => _scoreResult = null);
      return;
    }

    final calculator = ref.read(hpScoreCalculatorProvider);
    final result = await calculator.calculatePartial(
      additivesTags: _manualECodes,
    );
    setState(() => _scoreResult = result);
  }

  Future<void> _saveProduct() async {
    setState(() => _isSaving = true);

    try {
      final product = ProductEntity(
        barcode: widget.barcode,
        productName: _productNameController.text.isNotEmpty
            ? _productNameController.text
            : null,
        brands:
            _brandController.text.isNotEmpty ? _brandController.text : null,
        ingredientsText: _ingredientsController.text.isNotEmpty
            ? _ingredientsController.text
            : null,
        additivesTags: _manualECodes,
        hpScore: _scoreResult?.hpScore,
        hpChemicalLoad: _scoreResult?.chemicalLoad,
        hpRiskFactor: _scoreResult?.riskFactor,
        hpNutriFactor: _scoreResult?.nutriFactor,
      );

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final submitUseCase = ref.read(submitCommunityProductUseCaseProvider);
      await submitUseCase(
        product: product,
        userId: userId,
        source: 'community',
      );

      if (!mounted) return;

      ref.invalidate(productByBarcodeProvider(widget.barcode));
      context.go('/product/${widget.barcode}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bu ürünü veritabanımıza eklediniz!'),
          backgroundColor: context.colors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Manuel Giriş'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name
            TextField(
              controller: _productNameController,
              decoration: InputDecoration(
                labelText: 'Ürün Adı',
                labelStyle: TextStyle(color: context.colors.textMuted),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.primary),
                ),
              ),
              style: TextStyle(color: context.colors.textPrimary),
            ),
            const SizedBox(height: 12),

            // Brand
            TextField(
              controller: _brandController,
              decoration: InputDecoration(
                labelText: 'Marka',
                labelStyle: TextStyle(color: context.colors.textMuted),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.primary),
                ),
              ),
              style: TextStyle(color: context.colors.textPrimary),
            ),
            const SizedBox(height: 16),

            // Ingredients text
            Text(
              'İçindekiler Metni (opsiyonel)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ingredientsController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'İçindekiler listesini buraya yapıştırın...',
                hintStyle: TextStyle(color: context.colors.textMuted),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.primary),
                ),
              ),
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // E-code input
            Text(
              'Katkı Maddeleri (E Kodları)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _eCodeController,
                    decoration: InputDecoration(
                      hintText: 'E471',
                      hintStyle: TextStyle(color: context.colors.textMuted),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.colors.primary),
                      ),
                    ),
                    style: TextStyle(color: context.colors.textPrimary),
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _addECode(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addECode,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: context.colors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add, color: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // E-code chips
            if (_manualECodes.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _manualECodes.map((code) {
                  return GestureDetector(
                    onTap: () => _removeECode(code),
                    child: AdditiveChip(
                      eCode: code,
                      riskLevel: 3,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                'Kaldırmak için dokunun',
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Score gauge
            if (_scoreResult != null) ...[
              ChemicalLoadGauge(
                chemicalLoad: _scoreResult!.chemicalLoad,
                isPartial: true,
              ),
              const SizedBox(height: 16),
            ],

            // Save button
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _isSaving ? null : _saveProduct,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: context.colors.primaryGradient,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isSaving)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    else ...[
                      const Icon(Icons.check_rounded,
                          color: Colors.black, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Kaydet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/product/presentation/screens/manual_ingredients_screen.dart
git commit -m "feat: add ManualIngredientsScreen with E-code input and scoring"
```

---

## Task 19: Update ProductDetailScreen — NotFound Redirect + Partial Badge

**Files:**
- Modify: `lib/features/product/presentation/screens/product_detail_screen.dart:1-240`

**Step 1: Update _buildNotFound to redirect**

In `lib/features/product/presentation/screens/product_detail_screen.dart`:

Add import at top:

```dart
import 'package:go_router/go_router.dart';
import '../widgets/community_badge.dart';
```

Replace the `data:` handler (lines 32-58) with:

```dart
        data: (product) {
          if (product == null) {
            // Redirect to not-found screen with OCR CTAs
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/product/$barcode/not-found');
            });
            return _buildShimmer(context);
          }

          final isPartial = product.hpRiskFactor == null &&
              product.hpNutriFactor == null &&
              product.hpChemicalLoad != null;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductHeader(product: product),
                // Community badge for partial/community products
                if (isPartial)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: CommunityBadge(),
                  ),
                NovaCard(novaGroup: product.novaGroup),
                NutrimentTable(nutriments: product.nutriments),
                IngredientList(ingredientsText: product.ingredientsText),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    '${l10n.barcode}: ${product.barcode}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
```

**Step 2: Remove the old _buildNotFound method**

Delete the `_buildNotFound` method entirely (lines 195-239) since it's no longer used — the not-found case now redirects to `ProductNotFoundScreen`.

**Step 3: Verify build**

Run: `flutter analyze lib/features/product/presentation/screens/product_detail_screen.dart`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/features/product/presentation/screens/product_detail_screen.dart
git commit -m "feat: redirect not-found products to OCR screen, add community badge"
```

---

## Task 20: Full Build Verify & Smoke Test

**Step 1: Run full analysis**

Run: `flutter analyze`
Expected: No errors

**Step 2: Run build (Android)**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL

**Step 3: Fix any build errors**

If build errors occur, use the build-error-resolver agent to fix them.

**Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: resolve build errors from barcode resolution integration"
```

---

## Summary

| Task | What | Files |
|------|------|-------|
| 1 | Supabase tables | SQL via MCP |
| 2 | HP Score Calculator | `lib/core/services/hp_score_calculator.dart` |
| 3 | ProductSource interface + resolver | `lib/features/product/data/datasources/product_source.dart` |
| 4 | Community source (Supabase) | `community_product_source.dart` + `product_dto.dart` update |
| 5 | OFF source wrapper | `off_product_source.dart` |
| 6 | Barcode lookup source | `barcode_lookup_source.dart` + `api_constants.dart` update |
| 7 | Repository refactor | `product_repository_impl.dart` |
| 8 | Providers update | `product_provider.dart` |
| 9 | New packages | `pubspec.yaml` |
| 10 | OCR service + parser | `lib/core/services/ingredients_ocr_service.dart` |
| 11 | OCR providers | `ocr_provider.dart` |
| 12 | Submit use case | `submit_community_product_usecase.dart` |
| 13 | Routes | `route_names.dart` + `app_router.dart` |
| 14 | Not found screen | `product_not_found_screen.dart` |
| 15 | Camera screen | `ingredients_camera_screen.dart` |
| 16 | Widgets | `additive_chip.dart`, `chemical_load_gauge.dart`, `community_badge.dart` |
| 17 | Verification screen | `ingredients_verification_screen.dart` |
| 18 | Manual entry screen | `manual_ingredients_screen.dart` |
| 19 | Product detail update | `product_detail_screen.dart` |
| 20 | Full build verify | — |
