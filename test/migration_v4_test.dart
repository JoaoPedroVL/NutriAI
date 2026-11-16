import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutria/data/db/database.dart';
import 'package:nutria/data/db/seed.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migração v3 -> v4 roda sem erro', () async {
    final dir = await Directory.systemTemp.createTemp('nutria_mig_v4_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'nutria.sqlite'));

    // 1) Cria banco no schema v3
    final v3db = AppDatabase(NativeDatabase(file));
    await v3db.customStatement('PRAGMA user_version = 3');
    await v3db.close();

    // 2) Reabre com schema v4 - deve rodar onUpgrade(3->4)
    final v4db = AppDatabase(NativeDatabase(file));
    addTearDown(v4db.close);

    // Verifica se a tabela AppMeta existe
    final tables = await v4db.customSelect("SELECT name FROM sqlite_master WHERE type='table'").get();
    final tableNames = tables.map((t) => t.read<String>('name')).toList();
    expect(tableNames, contains('app_meta'));

    // Verifica coluna barcode
    final cols = await v4db.customSelect('PRAGMA table_info(foods)').get();
    final hasBarcode = cols.any((c) => c.read<String>('name') == 'barcode');
    expect(hasBarcode, isTrue);

    // Verifica índices únicos
    final indexes = await v4db.customSelect("SELECT name FROM sqlite_master WHERE type='index' AND name LIKE '%unique%'").get();
    final indexNames = indexes.map((i) => i.read<String>('name')).toList();
    expect(indexNames, contains('foods_barcode_unique'));
    expect(indexNames, contains('food_servings_unique'));

    // Testa seed
    await SeedService(v4db).ensureSeeded();
    expect(await v4db.foodCount(), greaterThan(0));
  });
}