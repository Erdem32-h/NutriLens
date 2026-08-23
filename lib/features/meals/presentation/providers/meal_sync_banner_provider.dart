import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/locale_provider.dart';

/// Yazıldıktan sonra öğün-senkron banner'ı bir daha hiç gösterilmez.
/// Aynı kalıp: [kCompareHintDismissedKey] (compare_hint_provider.dart).
const String kMealSyncBannerDismissedKey = 'meal_sync_banner_dismissed';

/// true → banner gizli. Prefs erişilemiyorsa da true — bozuk bir prefs
/// eklentisi kullanıcıyı her açılışta aynı banner'la rahatsız etmesin.
final mealSyncBannerDismissedProvider = Provider<bool>((ref) {
  try {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(kMealSyncBannerDismissedKey) ?? false;
  } catch (_) {
    return true;
  }
});

/// X butonunun aksiyonu: flag'i kalıcı yaz, provider'ı tazele.
Future<void> dismissMealSyncBanner(WidgetRef ref) async {
  try {
    final write = ref
        .read(sharedPreferencesProvider)
        .setBool(kMealSyncBannerDismissedKey, true);
    ref.invalidate(mealSyncBannerDismissedProvider);
    await write;
  } catch (_) {}
}
