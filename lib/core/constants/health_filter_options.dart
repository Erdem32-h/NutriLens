class FilterOption {
  final String id;
  final String nameKey;
  final String descKey;
  final List<String> triggersTr;
  final List<String> triggersEn;

  const FilterOption({
    required this.id,
    required this.nameKey,
    required this.descKey,
    required this.triggersTr,
    required this.triggersEn,
  });
}

class HealthFilterOptions {
  static const List<FilterOption> allergens = [
    FilterOption(
      id: 'gluten',
      nameKey: 'filterGluten',
      descKey: 'filterGlutenDesc',
      triggersTr: ['gluten', 'buğday', 'arpa', 'yulaf', 'çavdar', 'malt'],
      triggersEn: ['gluten', 'wheat', 'barley', 'oat', 'rye', 'malt'],
    ),
    FilterOption(
      id: 'lactose',
      nameKey: 'filterLactose',
      descKey: 'filterLactoseDesc',
      triggersTr: ['süt', 'laktoz', 'peynir', 'yoğurt', 'kazein', 'tereyağı', 'krema'],
      triggersEn: ['milk', 'lactose', 'cheese', 'yogurt', 'casein', 'butter', 'cream'],
    ),
    FilterOption(
      id: 'peanut',
      nameKey: 'filterPeanut',
      descKey: 'filterPeanutDesc',
      triggersTr: ['yer fıstığı', 'fıstık'],
      triggersEn: ['peanut'],
    ),
    FilterOption(
      id: 'soy',
      nameKey: 'filterSoy',
      descKey: 'filterSoyDesc',
      triggersTr: ['soya', 'lesitin'],
      triggersEn: ['soy', 'lecithin'],
    ),
    FilterOption(
      id: 'egg',
      nameKey: 'filterEgg',
      descKey: 'filterEggDesc',
      triggersTr: ['yumurta', 'albumen', 'albümin'],
      triggersEn: ['egg', 'albumen'],
    ),
    FilterOption(
      id: 'fish',
      nameKey: 'filterFish',
      descKey: 'filterFishDesc',
      triggersTr: ['balık', 'karides', 'kalamar', 'midye', 'istridye'],
      triggersEn: ['fish', 'shrimp', 'squid', 'mussel', 'oyster'],
    ),
  ];

  static const List<FilterOption> diets = [
    FilterOption(
      id: 'vegan',
      nameKey: 'filterVegan',
      descKey: 'filterVeganDesc',
      triggersTr: [
        'et', 'tavuk', 'balık', 'süt', 'peynir', 'yoğurt', 'yumurta',
        'bal', 'kazein', 'jelatin', 'hayvansal'
      ],
      triggersEn: [
        'meat', 'chicken', 'fish', 'milk', 'cheese', 'yogurt', 'egg',
        'honey', 'casein', 'gelatin', 'animal'
      ],
    ),
    FilterOption(
      id: 'vegetarian',
      nameKey: 'filterVegetarian',
      descKey: 'filterVegetarianDesc',
      triggersTr: ['et', 'tavuk', 'balık', 'kıyma', 'jambon', 'sosis', 'sucuk', 'salam', 'jelatin'],
      triggersEn: ['meat', 'chicken', 'fish', 'beef', 'pork', 'bacon', 'sausage', 'gelatin'],
    ),
    FilterOption(
      id: 'halal',
      nameKey: 'filterHalal',
      descKey: 'filterHalalDesc',
      triggersTr: ['domuz', 'alkol', 'şarap', 'likör', 'birası'],
      triggersEn: ['pork', 'alcohol', 'wine', 'liquor', 'beer', 'bacon', 'ham'],
    ),
  ];

  static const List<FilterOption> oils = [
    FilterOption(
      id: 'palm_oil',
      nameKey: 'filterPalmOil',
      descKey: 'filterPalmOilDesc',
      triggersTr: ['palm', 'hurma yağı', 'palmiye'],
      triggersEn: ['palm'],
    ),
    FilterOption(
      id: 'trans_fat',
      nameKey: 'filterTransFat',
      descKey: 'filterTransFatDesc',
      triggersTr: ['margarin', 'hidrojene', 'trans'],
      triggersEn: ['margarine', 'hydrogenated', 'trans'],
    ),
    FilterOption(
      id: 'canola',
      nameKey: 'filterCanola',
      descKey: 'filterCanolaDesc',
      triggersTr: ['kanola', 'kolza'],
      triggersEn: ['canola', 'rapeseed'],
    ),
  ];

  static const List<FilterOption> chemicals = [
    FilterOption(
      id: 'msg',
      nameKey: 'filterMsg',
      descKey: 'filterMsgDesc',
      triggersTr: ['msg', 'monosodyum glutamat', 'e621', 'aroma artırıcı'],
      triggersEn: ['msg', 'monosodium glutamate', 'e621', 'flavor enhancer'],
    ),
    FilterOption(
      id: 'aspartame',
      nameKey: 'filterAspartame',
      descKey: 'filterAspartameDesc',
      triggersTr: ['aspartam', 'e951', 'sukraloz', 'e955', 'asesülfam', 'e950', 'sakkarin', 'e954'],
      triggersEn: ['aspartame', 'e951', 'sucralose', 'e955', 'acesulfame', 'e950', 'saccharin', 'e954'],
    ),
    FilterOption(
      id: 'hfcs',
      nameKey: 'filterHfcs',
      descKey: 'filterHfcsDesc',
      triggersTr: ['nbş', 'nişasta bazlı şeker', 'glikoz şurubu', 'fruktoz şurubu', 'mısır şurubu', 'invert'],
      triggersEn: ['hfcs', 'high fructose corn syrup', 'glucose syrup', 'fructose syrup', 'corn syrup', 'invert'],
    ),
    FilterOption(
      id: 'nitrite',
      nameKey: 'filterNitrite',
      descKey: 'filterNitriteDesc',
      triggersTr: ['nitrit', 'nitrat', 'e250', 'e251', 'e252'],
      triggersEn: ['nitrite', 'nitrate', 'e250', 'e251', 'e252'],
    ),
    FilterOption(
      id: 'colorant',
      nameKey: 'filterColorant',
      descKey: 'filterColorantDesc',
      triggersTr: ['renklendirici', 'e1', 'titanyum dioksit', 'tartrazin', 'karmin'],
      triggersEn: ['colorant', 'e1', 'titanium dioxide', 'tartrazine', 'carmine', 'artificial color'],
    ),
  ];
}
