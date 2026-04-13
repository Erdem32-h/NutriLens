import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../config/drift/app_database.dart';
import '../../../../core/services/hp_score_calculator.dart';
import '../../domain/entities/additive_entity.dart';
import '../../domain/entities/allergen_entity.dart';
import '../models/additive_json_model.dart';

abstract interface class AdditiveLocalDataSource {
  Future<List<AdditiveEntity>> getAdditivesByCodes(List<String> eCodes);
  Future<AdditiveEntity?> getAdditiveByCode(String eCode);
  Future<List<AllergenEntity>> getAllAllergens();
  Future<bool> isSeedRequired();
  Future<void> seedFromJson(String jsonContent);
}

class AdditiveLocalDataSourceImpl implements AdditiveLocalDataSource {
  final AppDatabase _db;

  const AdditiveLocalDataSourceImpl(this._db);

  @override
  Future<List<AdditiveEntity>> getAdditivesByCodes(
    List<String> eCodes,
  ) async {
    final normalised = eCodes
        .map(HpScoreCalculator.normalizeECode)
        .toSet()
        .toList(growable: false);

    if (normalised.isEmpty) return [];

    final rows = await (_db.select(_db.additives)
          ..where((t) => t.eNumber.isIn(normalised)))
        .get();

    return rows.map(_rowToEntity).toList();
  }

  @override
  Future<AdditiveEntity?> getAdditiveByCode(String eCode) async {
    final normalised = HpScoreCalculator.normalizeECode(eCode);
    final row = await (_db.select(_db.additives)
          ..where((t) => t.eNumber.equals(normalised)))
        .getSingleOrNull();
    return row != null ? _rowToEntity(row) : null;
  }

  @override
  Future<List<AllergenEntity>> getAllAllergens() async {
    final rows = await _db.select(_db.allergens).get();
    return rows.map(_allergenRowToEntity).toList();
  }

  @override
  Future<bool> isSeedRequired() async {
    final count = await _db.additives.count().getSingle();
    return count == 0;
  }

  @override
  Future<void> seedFromJson(String jsonContent) async {
    final Map<String, dynamic> root =
        jsonDecode(jsonContent) as Map<String, dynamic>;
    final List<dynamic> items = root['additives'] as List<dynamic>;

    await _db.transaction(() async {
      for (final item in items) {
        final entity =
            AdditiveJsonModel.fromJson(item as Map<String, dynamic>);
        await _db
            .into(_db.additives)
            .insertOnConflictUpdate(_entityToCompanion(entity));
      }
    });
  }

  // ── Converters ──────────────────────────────────────────────────────

  AdditiveEntity _rowToEntity(Additive row) {
    return AdditiveEntity(
      id: row.id,
      eNumber: row.eNumber,
      nameEn: row.nameEn,
      nameTr: row.nameTr,
      category: row.category,
      riskLevel: row.riskLevel,
      riskLabel: row.riskLabel,
      descriptionEn: row.descriptionEn,
      descriptionTr: row.descriptionTr,
      efsaStatus: row.efsaStatus,
      turkishCodexStatus: row.turkishCodexStatus,
      isVegan: row.isVegan,
      isVegetarian: row.isVegetarian,
      isHalal: row.isHalal,
    );
  }

  AllergenEntity _allergenRowToEntity(Allergen row) {
    return AllergenEntity(
      id: row.id,
      nameEn: row.nameEn,
      nameTr: row.nameTr,
      category: row.category ?? '',
      iconName: row.iconName ?? 'warning',
      severityNote: row.severityNote,
    );
  }

  AdditivesCompanion _entityToCompanion(AdditiveEntity e) {
    return AdditivesCompanion(
      id: Value(e.id),
      eNumber: Value(e.eNumber),
      nameEn: Value(e.nameEn),
      nameTr: Value(e.nameTr),
      category: Value(e.category ?? ''),
      riskLevel: Value(e.riskLevel),
      riskLabel: Value(e.riskLabel ?? ''),
      descriptionEn: Value(e.descriptionEn),
      descriptionTr: Value(e.descriptionTr),
      efsaStatus: Value(e.efsaStatus),
      turkishCodexStatus: Value(e.turkishCodexStatus),
      isVegan: Value(e.isVegan),
      isVegetarian: Value(e.isVegetarian),
      isHalal: Value(e.isHalal),
    );
  }
}
