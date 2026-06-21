/// Pure builders for the social-share caption text. Localized pieces
/// (`scannedLabel` / `calculatedLabel`) are passed in by the caller so this
/// stays locale-independent and unit-testable. Segments are joined with " · ".
abstract final class ShareCaption {
  static String forProduct({
    required String name,
    required String? hpScoreText,
    required String scannedLabel,
    required String storeUrl,
  }) {
    final head = hpScoreText == null ? name : '$name — $hpScoreText';
    return [head, scannedLabel, storeUrl].join(' · ');
  }

  static String forMeal({
    required String foodName,
    required int calories,
    required String calculatedLabel,
    required String storeUrl,
  }) {
    return ['$foodName — $calories kcal', calculatedLabel, storeUrl]
        .join(' · ');
  }
}
