import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/drift/app_database.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/services/anthropic_ai_service.dart';
import '../../../../core/services/gemini_ai_service.dart';
import '../../../../core/services/hp_score_calculator.dart';
import '../../../../core/services/product_score_enricher.dart';
import '../../data/datasources/barcode_lookup_source.dart';
import '../../data/datasources/community_product_source.dart';
import '../../data/datasources/off_product_source.dart';
import '../../data/datasources/product_local_datasource.dart';
import '../../data/datasources/product_remote_datasource.dart';
import '../../data/datasources/product_source.dart';
import '../../data/datasources/usda_fdc_source.dart';
import '../../data/repositories/product_repository_impl.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/usecases/get_product_usecase.dart';
import '../../domain/usecases/submit_community_product_usecase.dart';

// Database provider — overridden in main.dart
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('AppDatabase must be overridden');
});

// Supabase client provider — overridden in main.dart
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  throw UnimplementedError('SupabaseClient must be overridden');
});

// Shared Dio instance with base configuration
final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
});

// --- Data Sources ---

final productRemoteDataSourceProvider = Provider<ProductRemoteDataSource>((
  ref,
) {
  return ProductRemoteDataSourceImpl();
});

final productLocalDataSourceProvider = Provider<ProductLocalDataSource>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ProductLocalDataSourceImpl(db);
});

final communityProductSourceProvider = Provider<CommunityProductSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return CommunityProductSource(client);
});

final offProductSourceProvider = Provider<OpenFoodFactsSource>((ref) {
  final remote = ref.watch(productRemoteDataSourceProvider);
  return OpenFoodFactsSource(remote);
});

final barcodeLookupSourceProvider = Provider<BarcodeLookupSource>((ref) {
  return BarcodeLookupSource(ref.watch(dioProvider));
});

final usdaFdcSourceProvider = Provider<UsdaFdcSource>((ref) {
  return UsdaFdcSource(
    ref.watch(dioProvider),
    dotenv.env['USDA_FDC_API_KEY'] ?? '',
  );
});

// --- Resolver ---

final productResolverProvider = Provider<ProductResolver>((ref) {
  return ProductResolver([
    ref.watch(communityProductSourceProvider),
    ref.watch(offProductSourceProvider),
    ref.watch(barcodeLookupSourceProvider),
    ref.watch(usdaFdcSourceProvider),
  ]);
});

// --- Repository ---

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl(
    resolver: ref.watch(productResolverProvider),
    localDataSource: ref.watch(productLocalDataSourceProvider),
    networkInfo: ref.watch(connectivityProvider),
    communitySource: ref.watch(communityProductSourceProvider),
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

final productScoreEnricherProvider = Provider<ProductScoreEnricher>((ref) {
  return ProductScoreEnricher(ref.watch(hpScoreCalculatorProvider));
});

// --- AI Service ---

final geminiAiServiceProvider = Provider<GeminiAiService>((ref) {
  return GeminiAiService(ref.watch(supabaseClientProvider));
});

final anthropicAiServiceProvider = Provider<AnthropicAiService>((ref) {
  return AnthropicAiService(
    dio: ref.watch(dioProvider),
    apiKey: dotenv.env['ANTHROPIC_API_KEY'] ?? '',
    // Optional ops override; falls back to the service's default model.
    model: dotenv.env['ANTHROPIC_MODEL'],
  );
});

// --- UI Providers ---

/// Fetches product by barcode. Use `ref.watch(productByBarcodeProvider(barcode))`.
/// Includes a 20-second timeout to prevent indefinite loading.
final productByBarcodeProvider = FutureProvider.family<ProductEntity?, String>((
  ref,
  barcode,
) async {
  debugPrint('[Provider] productByBarcode($barcode) → fetching...');
  final useCase = ref.watch(getProductUseCaseProvider);
  final scoreEnricher = ref.watch(productScoreEnricherProvider);
  final localDataSource = ref.watch(productLocalDataSourceProvider);
  final result = await useCase(barcode).timeout(
    const Duration(seconds: 20),
    onTimeout: () {
      debugPrint('[Provider] productByBarcode($barcode) → TIMEOUT');
      return const Left(ServerFailure('Request timed out'));
    },
  );
  return result.fold(
    (failure) {
      debugPrint(
        '[Provider] productByBarcode($barcode) → failure: '
        '${failure.runtimeType} - ${failure.message}',
      );
      // NotFoundFailure → return null so UI redirects to edit screen
      if (failure is NotFoundFailure) return null;
      throw Exception(failure.message);
    },
    (product) async {
      final enriched = await scoreEnricher.ensureFreshScore(product);
      if (enriched != product) {
        try {
          await localDataSource.cacheProduct(enriched);
        } catch (_) {
          // Score calculation should still be shown even if local cache fails.
        }
      }
      // Best-effort: backfill community_products with API-resolved entries
      // so the TR corpus grows passively. Idempotent + skips entries
      // missing essential data (those go through manual edit flow).
      unawaited(_autoImportToCommunity(ref, enriched));
      debugPrint(
        '[Provider] productByBarcode($barcode) → found: '
        'name=${enriched.productName}, hasEssential=${enriched.hasEssentialData}, '
        'hpScore=${enriched.hpScore}',
      );
      return enriched;
    },
  );
});

// Session-scoped dedupe: don't re-fire the upsert for the same barcode
// in the same app run. The Supabase call is idempotent already (ignore-
// duplicates) but skipping the network round-trip is cheap and obvious.
final _autoImportedBarcodes = <String>{};

Future<void> _autoImportToCommunity(Ref ref, ProductEntity product) async {
  if (_autoImportedBarcodes.contains(product.barcode)) return;
  // Only push complete rows — partial OFF/3rd-party entries should
  // route through the user-edit flow instead so they don't pollute the
  // community DB.
  if (!product.hasEssentialData) return;
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;
  try {
    final source = ref.read(communityProductSourceProvider);
    final inserted = await source.autoImportFromApi(
      product: product,
      userId: userId,
      source: 'api_import',
    );
    _autoImportedBarcodes.add(product.barcode);
    if (inserted) {
      debugPrint('[auto-import] ${product.barcode} → community_products');
    }
  } catch (e) {
    debugPrint('[auto-import] ${product.barcode} failed: $e');
  }
}

// --- Submit Community Product ---

final submitCommunityProductUseCaseProvider =
    Provider<SubmitCommunityProductUseCase>((ref) {
      return SubmitCommunityProductUseCase(
        ref.watch(productRepositoryProvider),
      );
    });

// --- Alternatives ---

/// Up to 5 same-category community products with a strictly better HP score
/// than the current product. Returns [] when the category is unknown.
final alternativesProvider =
    FutureProvider.family<
      List<ProductEntity>,
      ({String barcode, double hpScore, String? category})
    >((ref, args) async {
      final source = ref.watch(communityProductSourceProvider);
      return source.getAlternatives(
        category: args.category,
        selfBarcode: args.barcode,
        currentHpScore: args.hpScore,
      );
    });

// --- Additives ---

final additivesByCodesProvider =
    FutureProvider.family<Map<String, int>, List<String>>((ref, codes) async {
      if (codes.isEmpty) return {};

      final db = ref.watch(appDatabaseProvider);
      final result = <String, int>{};

      try {
        final query = db.select(db.additives)
          ..where((t) => t.eNumber.isIn(codes));
        final rows = await query.get();

        for (final row in rows) {
          result[row.eNumber] = row.riskLevel;
        }

        for (final code in codes) {
          if (!result.containsKey(code)) {
            result[code] = 3;
          }
        }
      } catch (_) {
        for (final code in codes) {
          result[code] = 3;
        }
      }

      return result;
    });
