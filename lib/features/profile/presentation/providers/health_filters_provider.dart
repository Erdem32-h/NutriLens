import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthFiltersState {
  final List<String> allergens;
  final List<String> diets;
  final List<String> oils;
  final List<String> chemicals;

  const HealthFiltersState({
    this.allergens = const [],
    this.diets = const [],
    this.oils = const [],
    this.chemicals = const [],
  });

  HealthFiltersState copyWith({
    List<String>? allergens,
    List<String>? diets,
    List<String>? oils,
    List<String>? chemicals,
  }) {
    return HealthFiltersState(
      allergens: allergens ?? this.allergens,
      diets: diets ?? this.diets,
      oils: oils ?? this.oils,
      chemicals: chemicals ?? this.chemicals,
    );
  }
}

class HealthFiltersNotifier extends Notifier<HealthFiltersState> {
  static const _allergensKey = 'health_filters_allergens';
  static const _dietsKey = 'health_filters_diets';
  static const _oilsKey = 'health_filters_oils';
  static const _chemicalsKey = 'health_filters_chemicals';

  SharedPreferences? _prefs;

  @override
  HealthFiltersState build() {
    _init();
    return const HealthFiltersState();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    if (_prefs == null) return;
    state = HealthFiltersState(
      allergens: _prefs!.getStringList(_allergensKey) ?? [],
      diets: _prefs!.getStringList(_dietsKey) ?? [],
      oils: _prefs!.getStringList(_oilsKey) ?? [],
      chemicals: _prefs!.getStringList(_chemicalsKey) ?? [],
    );
  }

  Future<void> _saveAllergens(List<String> list) async {
    await _prefs?.setStringList(_allergensKey, list);
  }

  Future<void> _saveDiets(List<String> list) async {
    await _prefs?.setStringList(_dietsKey, list);
  }

  Future<void> _saveOils(List<String> list) async {
    await _prefs?.setStringList(_oilsKey, list);
  }

  Future<void> _saveChemicals(List<String> list) async {
    await _prefs?.setStringList(_chemicalsKey, list);
  }

  void toggleAllergen(String id) {
    final list = List<String>.from(state.allergens);
    if (list.contains(id)) {
      list.remove(id);
    } else {
      list.add(id);
    }
    state = state.copyWith(allergens: list);
    _saveAllergens(list);
  }

  void toggleDiet(String id) {
    final list = List<String>.from(state.diets);
    if (list.contains(id)) {
      list.remove(id);
    } else {
      list.add(id);
    }
    state = state.copyWith(diets: list);
    _saveDiets(list);
  }

  void toggleOil(String id) {
    final list = List<String>.from(state.oils);
    if (list.contains(id)) {
      list.remove(id);
    } else {
      list.add(id);
    }
    state = state.copyWith(oils: list);
    _saveOils(list);
  }

  void toggleChemical(String id) {
    final list = List<String>.from(state.chemicals);
    if (list.contains(id)) {
      list.remove(id);
    } else {
      list.add(id);
    }
    state = state.copyWith(chemicals: list);
    _saveChemicals(list);
  }
}

final healthFiltersProvider = NotifierProvider<HealthFiltersNotifier, HealthFiltersState>(() {
  return HealthFiltersNotifier();
});
