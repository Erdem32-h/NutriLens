import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/turkish_cities.dart';
import '../providers/location_provider.dart';

/// What the caller needs to enable Ramadan mode: coordinates, a display
/// label, the plate code when the pick came from the city list (null for
/// GPS), and `source` for the `location_source` analytics prop
/// (`RamadanController.enable`) — `"city"` or `"gps"`.
typedef RamadanLocationPick = ({
  double lat,
  double lng,
  String label,
  int? plate,
  String source,
});

/// Opens the province picker and resolves to the chosen location, or null
/// if dismissed without a pick.
Future<RamadanLocationPick?> showCityPicker(BuildContext context) {
  return showModalBottomSheet<RamadanLocationPick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const CityPickerSheet(),
  );
}

/// Bottom sheet: "use my location" (GPS, via [currentPositionProvider]) or
/// search-and-pick from the 81 provinces. Mirrors the shape of
/// `ProductPickerSheet` (drag handle + `DraggableScrollableSheet`).
class CityPickerSheet extends ConsumerStatefulWidget {
  const CityPickerSheet({super.key});

  @override
  ConsumerState<CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends ConsumerState<CityPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _locating = false;

  /// Shown inline under the GPS button — a SnackBar would land on the root
  /// Scaffold, hidden under this 70% sheet.
  bool _locationFailed = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _locationFailed = false;
    });
    final position = await ref.read(currentPositionProvider)();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _locationFailed = position == null;
    });
    if (position == null) return;
    Navigator.pop(context, (
      lat: position.lat,
      lng: position.lng,
      label: context.l10n.ramadanMyLocationLabel,
      plate: null,
      source: 'gps',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final query = foldTurkish(_query.trim());
    final cities = query.isEmpty
        ? turkishCities
        : turkishCities
              .where((c) => foldTurkish(c.name).contains(query))
              .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: l10n.ramadanSearchCity,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _locating ? null : _useMyLocation,
                    icon: _locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded),
                    label: Text(l10n.ramadanUseMyLocation),
                  ),
                ),
              ),
              if (_locationFailed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    l10n.ramadanLocationFailed,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.error,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                  itemCount: cities.length,
                  itemBuilder: (_, i) {
                    final city = cities[i];
                    return ListTile(
                      title: Text(city.name),
                      onTap: () => Navigator.pop(context, (
                        lat: city.lat,
                        lng: city.lng,
                        label: city.name,
                        plate: city.plate,
                        source: 'city',
                      )),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
