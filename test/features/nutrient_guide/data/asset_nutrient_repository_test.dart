import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/nutrient_guide/data/asset_nutrient_repository.dart';
import 'package:nutrilens/features/nutrient_guide/presentation/providers/nutrient_provider.dart';

const _validJson = '''
{"version":"1.0","updated_at":"2026-11-23","nutrients":[
{"id":"vitamin_c","category":"vitamin",
 "name_tr":"C Vitamini","name_en":"Vitamin C",
 "function_tr":"a","function_en":"a",
 "deficiency_tr":["x"],"deficiency_en":["x"],
 "excess_tr":["y"],"excess_en":["y"],
 "sources_tr":["z"],"sources_en":["z"],
 "daily_need":"75–90 mg","source":"NIH ODS"}
]}
''';

/// Serves scripted responses to `loadString` and counts the calls.
class _ScriptedBundle extends AssetBundle {
  _ScriptedBundle(this._responses);

  final List<Object> _responses; // String → value, Exception → thrown
  int calls = 0;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final r =
        _responses[calls < _responses.length ? calls : _responses.length - 1];
    calls++;
    if (r is Exception) throw r;
    return r as String;
  }

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(_validJson)));
}

void main() {
  group('AssetNutrientRepository', () {
    test('getAll parses the asset once and caches', () async {
      final bundle = _ScriptedBundle([_validJson]);
      final repo = AssetNutrientRepository(bundle);

      final first = await repo.getAll();
      final second = await repo.getAll();

      expect(first.single.id, 'vitamin_c');
      expect(second, same(first));
      expect(bundle.calls, 1);
    });

    test('getAll rethrows FormatException for corrupt asset', () async {
      final repo = AssetNutrientRepository(_ScriptedBundle(['{oops']));
      await expectLater(repo.getAll(), throwsFormatException);
    });

    test('a failed load is not cached: next call succeeds', () async {
      final bundle = _ScriptedBundle([Exception('boom'), _validJson]);
      final repo = AssetNutrientRepository(bundle);

      await expectLater(repo.getAll(), throwsException);
      final list = await repo.getAll();

      expect(list.single.id, 'vitamin_c');
      expect(bundle.calls, 2);
    });
  });

  group('providers', () {
    test(
      'nutrientByIdProvider returns the entry and null for unknown id',
      () async {
        final container = ProviderContainer(
          overrides: [
            nutrientRepositoryProvider.overrideWithValue(
              AssetNutrientRepository(_ScriptedBundle([_validJson])),
            ),
          ],
        );
        addTearDown(container.dispose);

        final found = await container.read(
          nutrientByIdProvider('vitamin_c').future,
        );
        final missing = await container.read(
          nutrientByIdProvider('nope').future,
        );

        expect(found?.name.en, 'Vitamin C');
        expect(missing, isNull);
      },
    );
  });
}
