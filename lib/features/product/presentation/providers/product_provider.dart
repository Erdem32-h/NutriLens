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
import '../../../../core/error/failures.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/usecases/get_product_usecase.dart';
import '../../domain/usecases/submit_community_product_usecase.dart';

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
    (failure) {
      // NotFoundFailure → return null so UI redirects to not-found screen
      if (failure is NotFoundFailure) return null;
      throw Exception(failure.message);
    },
    (product) => product,
  );
});

// --- Submit Community Product ---

final submitCommunityProductUseCaseProvider =
    Provider<SubmitCommunityProductUseCase>((ref) {
  return SubmitCommunityProductUseCase(
    communitySource: ref.watch(communityProductSourceProvider),
    localDataSource: ref.watch(productLocalDataSourceProvider),
  );
});
