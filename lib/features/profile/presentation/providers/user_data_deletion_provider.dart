import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../product/presentation/providers/product_provider.dart';
import '../../data/services/account_deletion_service.dart';
import '../../data/services/user_data_deletion_service.dart';

final userDataDeletionServiceProvider = Provider<UserDataDeletionService>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return UserDataDeletionService(
    db: ref.watch(appDatabaseProvider),
    remoteStore: SupabaseRemoteUserDataStore(client),
    preferences: ref.watch(sharedPreferencesProvider),
    currentUserId: () => client.auth.currentUser?.id,
  );
});

final accountDeletionServiceProvider = Provider<AccountDeletionService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AccountDeletionService(
    userDataCleaner: ref.watch(userDataDeletionServiceProvider),
    accountStore: SupabaseRemoteAccountDeletionStore(
      client,
      ref.watch(sharedPreferencesProvider),
    ),
    authSession: SupabaseAuthSessionTerminator(client),
    preferences: ref.watch(sharedPreferencesProvider),
  );
});
