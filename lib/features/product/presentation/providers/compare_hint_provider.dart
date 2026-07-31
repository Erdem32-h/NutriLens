import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/locale_provider.dart';

/// Yazıldıktan sonra kıyas ipucu şeridi bir daha hiç gösterilmez.
const String kCompareHintDismissedKey = 'compare_hint_dismissed';

/// true → şerit gizli. Prefs erişilemiyorsa da true: bozuk bir prefs
/// eklentisi kullanıcıyı her açılışta aynı ipucuyla rahatsız etmesin
/// (kOnboardingSeenKey'in savunmacı varsayılanıyla aynı gerekçe, ters yön —
/// bkz. app_session.dart `_prefsOrNull`).
final compareHintDismissedProvider = Provider<bool>((ref) {
  try {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(kCompareHintDismissedKey) ?? false;
  } catch (_) {
    return true;
  }
});

/// X butonunun aksiyonu: flag'i kalıcı yaz, provider'ı tazele.
/// Prefs yoksa yazma sessizce atlanır — provider o durumda zaten true
/// döndüğü için şerit ekranda değildir, buraya normalde gelinmez.
Future<void> dismissCompareHint(WidgetRef ref) async {
  try {
    final write = ref
        .read(sharedPreferencesProvider)
        .setBool(kCompareHintDismissedKey, true);
    ref.invalidate(compareHintDismissedProvider);
    await write;
  } catch (_) {}
}
