import '../../../l10n/generated/app_localizations.dart';
import '../domain/entities/nutrient_entity.dart';

/// Display label for an amino acid class, shared by the guide's group
/// headers and the detail screen's chip.
String aminoClassLabel(AppLocalizations l10n, AminoAcidClass c) => switch (c) {
  AminoAcidClass.essential => l10n.nutrientAminoEssential,
  AminoAcidClass.conditional => l10n.nutrientAminoConditional,
  AminoAcidClass.nonEssential => l10n.nutrientAminoNonEssential,
};
