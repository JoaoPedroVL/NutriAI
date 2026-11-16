import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutria/data/db/database.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migração v5 -> v6 adiciona snapshot de macros às refeições salvas',
      () async {
    final dir = await Directory.systemTemp.createTemp('nutria_mig_v5_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'nutria.sqlite'));

    // Schema v5 mínimo: apenas a tabela que a migração altera.
    final raw = sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE saved_meal_items (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        saved_meal_id INTEGER NOT NULL,
        food_id INTEGER NOT NULL,
        food_name TEXT NOT NULL,
        grams REAL NOT NULL,
        meal TEXT NOT NULL
      )
    ''');
    raw.execute('PRAGMA user_version = 5');
    raw.close();

    final v6 = AppDatabase(NativeDatabase(file));
    addTearDown(v6.close);

    final cols =
        await v6.customSelect('PRAGMA table_info(saved_meal_items)').get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, containsAll(['category', 'kcal', 'protein', 'carbs', 'fat']));
  });
}
