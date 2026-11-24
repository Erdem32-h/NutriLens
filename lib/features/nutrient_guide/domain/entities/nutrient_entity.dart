import 'package:equatable/equatable.dart';

/// A value written in Turkish and English, with optional translations for
/// Spanish, Portuguese, Arabic, and Chinese. Missing locales fall back to
/// English so [of] never returns an empty value.
class Localized<T> extends Equatable {
  final T tr;
  final T en;
  final T? es;
  final T? pt;
  final T? ar;
  final T? zh;

  const Localized({
    required this.tr,
    required this.en,
    this.es,
    this.pt,
    this.ar,
    this.zh,
  });

  T of(String languageCode) => switch (languageCode) {
    'tr' => tr,
    'es' => es ?? en,
    'pt' => pt ?? en,
    'ar' => ar ?? en,
    'zh' => zh ?? en,
    _ => en,
  };

  @override
  List<Object?> get props => [tr, en, es, pt, ar, zh];
}

enum NutrientCategory { vitamin, mineral, aminoAcid }

/// Whether the body can make an amino acid: [essential] ones must come from
/// food, [conditional] ones only in illness or stress, [nonEssential] ones
/// the body always makes.
enum AminoAcidClass { essential, conditional, nonEssential }

class NutrientEntity extends Equatable {
  final String id;
  final NutrientCategory category;
  final Localized<String> name;
  final Localized<String>? altName;
  final Localized<String> function;
  final Localized<List<String>> deficiency;
  final Localized<List<String>> excess;
  final Localized<List<String>> sources;

  /// Set for amino acids only.
  final AminoAcidClass? aminoClass;

  /// Adult daily need as display text, number and unit only (e.g. "75–90 mg").
  /// Null only for amino acids the body makes, which have no set need.
  final String? dailyNeed;

  /// Tolerable upper intake as display text, null when none is established.
  final String? upperLimit;

  /// Where the figures come from (e.g. "NIH ODS", "EFSA").
  final String source;

  const NutrientEntity({
    required this.id,
    required this.category,
    this.aminoClass,
    required this.name,
    required this.altName,
    required this.function,
    required this.deficiency,
    required this.excess,
    required this.sources,
    required this.dailyNeed,
    required this.upperLimit,
    required this.source,
  });

  @override
  List<Object?> get props => [
    id,
    category,
    aminoClass,
    name,
    altName,
    function,
    deficiency,
    excess,
    sources,
    dailyNeed,
    upperLimit,
    source,
  ];
}
