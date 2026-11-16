import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../../core/defaults.dart';
import '../../core/text.dart';
import 'database.dart';

/// Popula o banco local com a TACO (597 alimentos) e as medidas caseiras
/// curadas, apenas na primeira execução.
///
/// Usa a tabela `AppMeta` para saber se o dataset já foi importado — assim,
/// se o usuário apaga os alimentos e roda de novo, a TACO volta. Se o usuário
/// só criou alguns alimentos personalizados, a TACO não é importada de novo.
class SeedService {
  SeedService(this._db);

  final AppDatabase _db;

  static const _datasetVersion = 'taco-4th-1';

  Future<void> ensureSeeded({AssetBundle? bundle}) async {
    // Checa se já importamos ESTE dataset; não usa foodCount() porque o
    // usuário pode ter apagado os alimentos e querer reimportar.
    if (await _db.metaValue('dataset_version') == _datasetVersion) {
      return;
    }

    final assets = bundle ?? rootBundle;
    final foodsCsv = await assets.loadString('assets/data/taco_foods.csv');
    final servingsCsv = await assets.loadString('assets/data/servings.csv');

    const converter = CsvDecoder();
    final foods = converter.convert(foodsCsv);
    final servings = converter.convert(servingsCsv);

    final idsByName = <String, int>{};

    await _db.transaction(() async {
      for (final row in foods.skip(1)) {
        if (row.length < 9) continue;
        final id = int.tryParse(row[0].toString());
        if (id == null) continue;

        final name = row[1].toString();
        await _db.into(_db.foods).insert(
              FoodsCompanion.insert(
                id: Value(id),
                name: name,
                searchKey: normalizeForSearch(name),
                category: Value(row[2].toString()),
                kcal100: _num(row[3]),
                protein100: _num(row[4]),
                carbs100: _num(row[5]),
                fat100: _num(row[6]),
                fiber100: _num(row[7]),
                sodium100: _num(row[8]),
                source: const Value('taco'),
              ),
              mode: InsertMode.insertOrIgnore,
            );
        idsByName[name] = id;
      }

      for (final row in servings.skip(1)) {
        if (row.length < 3) continue;
        final foodId = idsByName[row[0].toString()];
        if (foodId == null) continue;
        await _db.upsertServing(
          foodId: foodId,
          label: row[1].toString(),
          grams: _num(row[2]),
        );
      }

      await _db.into(_db.goals).insertOnConflictUpdate(
            GoalsCompanion.insert(
              id: const Value(1),
              kcal: kDefaultKcal,
              protein: kDefaultProtein,
              carbs: kDefaultCarbs,
              fat: kDefaultFat,
            ),
          );

      // Marca que este dataset já foi importado.
      await _db.setMeta('dataset_version', _datasetVersion);
    });
  }

  double _num(Object? value) {
    final text = value?.toString().trim() ?? '';
    return double.tryParse(text) ?? 0;
  }
}
