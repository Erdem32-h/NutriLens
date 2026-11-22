import 'entities/nutrient_entity.dart';

/// Lower-cases [input] and folds Turkish letters to ASCII so "iyot" finds
/// "İyot" and "sut" finds "süt". `İ`, `I` and `ı` must be mapped before
/// `toLowerCase`, which would otherwise turn `I` into `i` but `İ` into `i̇`.
String foldForSearch(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(switch (ch) {
      'İ' || 'I' || 'ı' => 'i',
      'Ş' || 'ş' => 's',
      'Ğ' || 'ğ' => 'g',
      'Ü' || 'ü' => 'u',
      'Ö' || 'ö' => 'o',
      'Ç' || 'ç' => 'c',
      _ => ch.toLowerCase(),
    });
  }
  return buffer.toString();
}

/// Entries whose name or alt name (in [languageCode], English for non-Turkish
/// locales) contains [query]. A blank query returns [all] unchanged.
List<NutrientEntity> searchNutrients(
  List<NutrientEntity> all,
  String query,
  String languageCode,
) {
  final needle = foldForSearch(query.trim());
  if (needle.isEmpty) return all;
  return all.where((n) {
    final name = foldForSearch(n.name.of(languageCode));
    final alt = n.altName == null
        ? ''
        : foldForSearch(n.altName!.of(languageCode));
    return name.contains(needle) || alt.contains(needle);
  }).toList();
}
