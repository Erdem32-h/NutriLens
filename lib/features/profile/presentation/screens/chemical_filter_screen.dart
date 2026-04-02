import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/health_filter_options.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../providers/health_filters_provider.dart';
import '../widgets/filter_selection_view.dart';

class ChemicalFilterScreen extends ConsumerWidget {
  const ChemicalFilterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(healthFiltersProvider);
    
    return FilterSelectionView(
      title: l10n.chemicalFilters,
      options: HealthFilterOptions.chemicals,
      selectedIds: state.chemicals,
      onToggle: (id) => ref.read(healthFiltersProvider.notifier).toggleChemical(id),
    );
  }
}