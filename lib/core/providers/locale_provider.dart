import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localePrefKey = 'locale';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized before use');
});

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final saved = prefs.getString(_localePrefKey);
    if (saved != null && saved.isNotEmpty) {
      return Locale(saved);
    }
    // First launch (no explicit choice yet): follow the device language.
    // Turkish phones open in Turkish; everything else falls back to English.
    return Locale(_deviceDefaultLanguageCode());
  }

  static const _supportedLanguages = {'tr', 'en', 'pt', 'es', 'ar', 'zh'};

  /// Resolves the OS locale to one of the app's supported languages.
  static String _deviceDefaultLanguageCode() {
    final deviceLocales = ui.PlatformDispatcher.instance.locales;
    final primary = deviceLocales.isNotEmpty
        ? deviceLocales.first.languageCode
        : ui.PlatformDispatcher.instance.locale.languageCode;
    return _supportedLanguages.contains(primary) ? primary : 'en';
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localePrefKey, locale.languageCode);
  }
}
