/// Canonical product categories — a single string id is used both in the
/// `community_products.category` column and in same-category alternative
/// matching. `label` is the Turkish UI label for the edit-form dropdown.
class ProductCategory {
  final String id;
  final String label;
  const ProductCategory(this.id, this.label);
}

abstract final class ProductCategories {
  static const all = <ProductCategory>[
    ProductCategory('sut', 'Süt'),
    ProductCategory('yogurt', 'Yoğurt'),
    ProductCategory('peynir', 'Peynir'),
    ProductCategory('yag', 'Tereyağı / Margarin'),
    ProductCategory('biskuvi', 'Bisküvi / Kraker'),
    ProductCategory('cikolata', 'Çikolata'),
    ProductCategory('sekerleme', 'Şekerleme'),
    ProductCategory('cips', 'Cips / Atıştırmalık'),
    ProductCategory('kuruyemis', 'Kuruyemiş'),
    ProductCategory('gazli_icecek', 'Gazlı içecek'),
    ProductCategory('meyve_suyu', 'Meyve suyu'),
    ProductCategory('su', 'Su / Maden suyu'),
    ProductCategory('kahve_cay', 'Kahve / Çay'),
    ProductCategory('ekmek', 'Ekmek / Unlu mamul'),
    ProductCategory('gevrek', 'Kahvaltılık gevrek'),
    ProductCategory('makarna', 'Makarna / Bakliyat'),
    ProductCategory('hazir_yemek', 'Hazır yemek / Konserve'),
    ProductCategory('sos', 'Sos'),
    ProductCategory('recel_bal', 'Reçel / Bal'),
    ProductCategory('et_sarkuteri', 'Et / Şarküteri'),
    ProductCategory('dondurma', 'Dondurma'),
    ProductCategory('diger', 'Diğer'),
  ];

  static const validIds = {
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
  };

  static bool isValid(String? id) => id != null && validIds.contains(id);

  static String? labelFor(String? id) {
    if (id == null) return null;
    for (final c in all) {
      if (c.id == id) return c.label;
    }
    return null;
  }
}
