import 'package:equatable/equatable.dart';

/// A value written in Turkish and English. Every other UI language reads the
/// English text, so [of] never returns an empty value for a supported locale.
class Localized<T> extends Equatable {
  final T tr;
  final T en;

  const Localized({required this.tr, required this.en});

  T of(String languageCode) => languageCode == 'tr' ? tr : en;

  @override
  List<Object?> get props => [tr, en];
}

enum NutrientCategory { vitamin, mineral, aminoAcid }

class NutrientEntity extends Equatable {
  final String id;
  final NutrientCategory category;
  final Localized<String> name;
  final Localized<String>? altName;
  final Localized<String> function;
  final Localized<List<String>> deficiency;
  final Localized<List<String>> excess;
  final Localized<List<String>> sources;

  /// Adult daily need as display text, number and unit only (e.g. "75–90 mg").
  final String dailyNeed;

  /// Tolerable upper intake as display text, null when none is established.
  final String? upperLimit;

  /// Where the figures come from (e.g. "NIH ODS", "EFSA").
  final String source;

  const NutrientEntity({
    required this.id,
    required this.category,
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
