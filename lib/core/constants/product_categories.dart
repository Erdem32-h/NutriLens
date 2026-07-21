/// Canonical product category ids.
///
/// The id is the stable value: it is written to `community_products.category`
/// and used for same-category alternative matching, so it must never change.
/// Display labels used to live here as Turkish strings, which meant the
/// edit-form dropdown showed Turkish to English users; they now come from
/// `categoryLabel` in
/// `features/product/presentation/category_display.dart`, mirroring how
/// `meal_display.dart` localizes meal names.
abstract final class ProductCategories {
  static const all = <String>[
    'sut',
    'yogurt',
    'peynir',
    'yag',
    'biskuvi',
    'cikolata',
    'sekerleme',
    'cips',
    'kuruyemis',
    'gazli_icecek',
    'meyve_suyu',
    'su',
    'kahve_cay',
    'ekmek',
    'gevrek',
    'makarna',
    'hazir_yemek',
    'sos',
    'recel_bal',
    'et_sarkuteri',
    'dondurma',
    'diger',
  ];

  static final validIds = all.toSet();

  static bool isValid(String? id) => id != null && validIds.contains(id);
}
