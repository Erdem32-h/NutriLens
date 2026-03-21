import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network_info.dart';

final connectivityProvider = Provider<NetworkInfo>((ref) {
  return NetworkInfoImpl(Connectivity());
});

final isOnlineProvider = FutureProvider<bool>((ref) async {
  final networkInfo = ref.watch(connectivityProvider);
  return networkInfo.isConnected;
});

final connectivityStreamProvider = StreamProvider<bool>((ref) {
  final networkInfo = ref.watch(connectivityProvider);
  return networkInfo.onConnectivityChanged;
});
