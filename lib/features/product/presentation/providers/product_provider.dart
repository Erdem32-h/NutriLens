import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/drift/app_database.dart';
import '../../../../core/network/network_info.dart';
import '../../data/datasources/product_local_datasource.dart';
import '../../data/datasources/product_remote_datasource.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/usecases/get_product_usecase.dart';

// Database provider - will be overridden in bootstrap
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('AppDatabase must be overridden');
});

final networkInfoProvider = Provider<NetworkInfo>((ref) {
  return NetworkInfoImpl(Connectivity());
});

final productRemoteDataSourceProvider =
    Provider<ProductRemoteDataSource>((ref) {
  return ProductRemoteDataSourceImpl();
});

final productLocalDataSourceProvider =
    Provider<ProductLocalDataSource>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ProductLocalDataSourceImpl(db);
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl(
    remoteDataSource: ref.watch(productRemoteDataSourceProvider),
    localDataSource: ref.watch(productLocalDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

final getProductUseCaseProvider = Provider<GetProductUseCase>((ref) {
  return GetProductUseCase(ref.watch(productRepositoryProvider));
});

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
