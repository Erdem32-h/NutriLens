import 'dart:convert';

import '../domain/entities/nutrient_entity.dart';

/// Parses `assets/nutrients/nutrients.json`.
///
/// The asset is bundled content, so a bad entry is a packaging bug: every
/// problem is reported as a [FormatException] that names the entry.
List<NutrientEntity> parseNutrients(String jsonSource) {
  final Object? decoded;
  try {
    decoded = jsonDecode(jsonSource);
  } on FormatException catch (e) {
    throw FormatException('nutrients.json is not valid JSON: ${e.message}');
  }
  if (decoded is! Map<String, dynamic> || decoded['nutrients'] is! List) {
    throw const FormatException('nutrients.json: missing "nutrients" list');
  }

  final seen = <String>{};
  final result = <NutrientEntity>[];
  final entries = decoded['nutrients'] as List;
  for (var i = 0; i < entries.length; i++) {
    final raw = entries[i];
    if (raw is! Map<String, dynamic>) {
      throw FormatException('nutrients.json: entry #$i is not an object');
    }
    final entity = _parseEntry(raw, i);
    if (!seen.add(entity.id)) {
      throw FormatException('nutrients.json: duplicate id "${entity.id}"');
    }
    result.add(entity);
  }
  return result;
}

NutrientEntity _parseEntry(Map<String, dynamic> m, int index) {
  final id = m['id'];
  final label = id is String && id.trim().isNotEmpty ? id : '#$index';

  String text(String key) {
    final v = m[key];
    if (v is! String || v.trim().isEmpty) {
      throw FormatException('nutrient "$label": missing or empty "$key"');
    }
    return v;
  }

  List<String> list(String key) {
    final v = m[key];
    if (v is! List ||
        v.isEmpty ||
        v.any((e) => e is! String || e.trim().isEmpty)) {
      throw FormatException(
        'nutrient "$label": "$key" must be a non-empty list of text',
      );
    }
    return v.cast<String>();
  }

  String? optionalText(String key) {
    final v = m[key];
    if (v == null) return null;
    if (v is! String || v.trim().isEmpty) {
      throw FormatException('nutrient "$label": "$key" must be non-empty text');
    }
    return v;
  }

  List<String>? optionalList(String key) {
    final v = m[key];
    if (v == null) return null;
    if (v is! List ||
        v.isEmpty ||
        v.any((e) => e is! String || e.trim().isEmpty)) {
      throw FormatException(
        'nutrient "$label": "$key" must be a non-empty list of text',
      );
    }
    return v.cast<String>();
  }

  Localized<String> pair(String base) => Localized(
    tr: text('${base}_tr'),
    en: text('${base}_en'),
    es: optionalText('${base}_es'),
    pt: optionalText('${base}_pt'),
    ar: optionalText('${base}_ar'),
    zh: optionalText('${base}_zh'),
  );

  Localized<List<String>> listPair(String base) => Localized(
    tr: list('${base}_tr'),
    en: list('${base}_en'),
    es: optionalList('${base}_es'),
    pt: optionalList('${base}_pt'),
    ar: optionalList('${base}_ar'),
    zh: optionalList('${base}_zh'),
  );

  final categoryName = text('category');
  final category = switch (categoryName) {
    'vitamin' => NutrientCategory.vitamin,
    'mineral' => NutrientCategory.mineral,
    'amino_acid' => NutrientCategory.aminoAcid,
    _ => throw FormatException(
      'nutrient "$label": unknown category "$categoryName"',
    ),
  };

  final hasAltTr = m.containsKey('alt_name_tr');
  final hasAltEn = m.containsKey('alt_name_en');
  if (hasAltTr != hasAltEn) {
    throw FormatException(
      'nutrient "$label": alt_name_tr and alt_name_en must come together',
    );
  }

  final upper = m['upper_limit'];
  if (upper != null && (upper is! String || upper.trim().isEmpty)) {
    throw FormatException('nutrient "$label": "upper_limit" must be text');
  }

  return NutrientEntity(
    id: text('id'),
    category: category,
    name: pair('name'),
    altName: hasAltTr ? pair('alt_name') : null,
    function: pair('function'),
    deficiency: listPair('deficiency'),
    excess: listPair('excess'),
    sources: listPair('sources'),
    dailyNeed: text('daily_need'),
    upperLimit: upper as String?,
    source: text('source'),
  );
}
