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
import '../../data/datasources/barcode_lookup_source.dart';
import '../../data/datasources/community_product_source.dart';
import '../../data/datasources/off_product_source.dart';
import '../../data/datasources/product_local_datasource.dart';
import '../../data/datasources/product_remote_datasource.dart';
import '../../data/datasources/product_source.dart';
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

// --- AI Service ---

final geminiAiServiceProvider = Provider<GeminiAiService>((ref) {
  return GeminiAiService(ref.watch(supabaseClientProvider));
});

final anthropicAiServiceProvider = Provider<AnthropicAiService>((ref) {
  return AnthropicAiService(
    dio: ref.watch(dioProvider),
    apiKey: dotenv.env['ANTHROPIC_API_KEY'] ?? '',
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
    (product) {
      debugPrint(
        '[Provider] productByBarcode($barcode) → found: '
        'name=${product.productName}, hasEssential=${product.hasEssentialData}',
      );
      return product;
    },
  );
});

// --- Submit Community Product ---

final submitCommunityProductUseCaseProvider =
    Provider<SubmitCommunityProductUseCase>((ref) {
      return SubmitCommunityProductUseCase(
        ref.watch(productRepositoryProvider),
      );
    });

// --- Alternatives ---

/// Returns up to 5 locally cached products with a better HP score than
/// the product identified by [barcode]. The record is a (barcode, hpScore) pair.
final alternativesProvider =
    FutureProvider.family<
      List<ProductEntity>,
      ({String barcode, double hpScore})
    >((ref, args) async {
      final local = ref.watch(productLocalDataSourceProvider);
      return local.getAlternatives(
        barcode: args.barcode,
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
