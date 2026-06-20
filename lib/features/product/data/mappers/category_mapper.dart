/// Maps Open Food Facts `categoriesTags` to a canonical product category id
/// (see [ProductCategories]). Uses keyword-substring matching over the joined,
/// lowercased tags — robust to OFF's hierarchical tag noise
/// (e.g. `en:dairies, en:fermented-foods, en:yogurts`).
abstract final class CategoryMapper {
  /// First match wins; order matters (specific before generic — e.g. `yogurt`
  /// and `cheese` are checked before the generic `milk`/`dairies`).
  static const _rules = <(String keyword, String categoryId)>[
    ('yogurt', 'yogurt'),
    ('cheese', 'peynir'),
    ('butter', 'yag'),
    ('margarine', 'yag'),
    ('biscuit', 'biskuvi'),
    ('cookie', 'biskuvi'),
    ('cracker', 'biskuvi'),
    ('chocolate', 'cikolata'),
    ('candies', 'sekerleme'),
    ('candy', 'sekerleme'),
    ('chips', 'cips'),
    ('crisps', 'cips'),
    ('nuts', 'kuruyemis'),
    ('soda', 'gazli_icecek'),
    ('carbonated', 'gazli_icecek'),
    ('fruit-juice', 'meyve_suyu'),
    ('juice', 'meyve_suyu'),
    ('waters', 'su'),
    ('coffee', 'kahve_cay'),
    ('teas', 'kahve_cay'),
    ('breakfast-cereal', 'gevrek'),
    ('cereals', 'gevrek'),
    ('bread', 'ekmek'),
    ('pasta', 'makarna'),
    ('legumes', 'makarna'),
    ('canned', 'hazir_yemek'),
    ('meals', 'hazir_yemek'),
    ('sauce', 'sos'),
    ('ketchup', 'sos'),
    ('jam', 'recel_bal'),
    ('honey', 'recel_bal'),
    ('charcuterie', 'et_sarkuteri'),
    ('sausage', 'et_sarkuteri'),
    ('ice-cream', 'dondurma'),
    ('milk', 'sut'),
    ('dairies', 'sut'),
  ];

  /// Returns the canonical category id, or `null` when [tags] is empty or no
  /// rule matches (caller leaves category unset / shows no alternatives).
  static String? fromOffTags(List<String> tags) {
    if (tags.isEmpty) return null;
    final hay = tags.join(' ').toLowerCase();
    for (final (keyword, id) in _rules) {
      if (hay.contains(keyword)) return id;
    }
    return null;
  }
}
