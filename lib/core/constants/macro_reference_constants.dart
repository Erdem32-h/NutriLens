/// Genel diyet referansı: bir makronun toplam makro-enerji içindeki payı
/// bu aralıkların altında/üstünde ise Düşük/Yüksek sayılır.
/// Kişisel hedef DEĞİLDİR (uygulamada TDEE altyapısı yok — spec §4).
enum MacroLevel { low, normal, high }

abstract final class MacroReferenceConstants {
  // Kabul edilebilir pay aralıkları (% — toplam makro kcal içindeki pay)
  static const double proteinMinPct = 10;
  static const double proteinMaxPct = 35;
  static const double carbMinPct = 45;
  static const double carbMaxPct = 65;
  static const double fatMinPct = 20;
  static const double fatMaxPct = 35;

  // Atwater faktörleri (kcal/gram)
  static const double kcalPerGramProtein = 4;
  static const double kcalPerGramCarb = 4;
  static const double kcalPerGramFat = 9;

  static MacroLevel levelFor(
    double pct, {
    required double min,
    required double max,
  }) {
    if (pct < min) return MacroLevel.low;
    if (pct > max) return MacroLevel.high;
    return MacroLevel.normal;
  }
}
