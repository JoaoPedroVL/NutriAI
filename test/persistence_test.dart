import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutria/data/db/database.dart';
import 'package:nutria/data/db/seed.dart';
import 'package:nutria/data/repositories/diary_repository.dart';
import 'package:nutria/data/repositories/draft_repository.dart';
import 'package:nutria/data/repositories/food_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('catálogo TACO', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await SeedService(db).ensureSeeded();
    });

    tearDown(() => db.close());

    test('importa os 597 alimentos da TACO', () async {
      expect(await db.foodCount(), 597);
    });

    test('busca ignora acento e maiúsculas', () async {
      final repo = FoodRepository(db);
      final results = await repo.search('FEIJAO carioca');
      expect(results, isNotEmpty);
      expect(results.first.name.toLowerCase(), contains('feijão'));
    });

    test('alimento tem medidas caseiras', () async {
      final repo = FoodRepository(db);
      final arroz = (await repo.search('arroz tipo 1 cozido')).first;
      final servings = await repo.servingsFor(arroz.id);
      expect(servings.map((s) => s.label), contains('colher de sopa'));
    });
  });

  group('diário', () {
    late AppDatabase db;
    late DiaryRepository diary;
    late FoodRepository foods;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await SeedService(db).ensureSeeded();
      diary = DiaryRepository(db);
      foods = FoodRepository(db);
    });

    tearDown(() => db.close());

    test('grava snapshot imutável mesmo se o catálogo mudar', () async {
      final arroz = (await foods.search('arroz tipo 1 cozido')).first;
      final day = DateTime(2026, 11, 11);

      await diary.addEntry(day: day, meal: 'lunch', food: arroz, grams: 100);
      final before = (await diary.watchDay(day).first).single;

      await (db.update(db.foods)..where((f) => f.id.equals(arroz.id)))
          .write(const FoodsCompanion(kcal100: Value(9999)));

      final after = (await diary.watchDay(day).first).single;
      expect(after.kcal, closeTo(before.kcal, 0.001));
      expect(after.kcal, closeTo(arroz.kcal100, 0.001));
    });

    test('editar gramas recalcula macros proporcionalmente', () async {
      final arroz = (await foods.search('arroz tipo 1 cozido')).first;
      final day = DateTime(2026, 11, 11);

      await diary.addEntry(day: day, meal: 'lunch', food: arroz, grams: 100);
      final entry = (await diary.watchDay(day).first).single;

      await diary.updateGrams(entry, 200);
      final updated = (await diary.watchDay(day).first).single;

      expect(updated.grams, 200);
      expect(updated.kcal, closeTo(entry.kcal * 2, 0.001));
      expect(updated.protein, closeTo(entry.protein * 2, 0.001));
    });

    test('totais do dia somam apenas o dia selecionado', () async {
      final arroz = (await foods.search('arroz tipo 1 cozido')).first;
      await diary.addEntry(
        day: DateTime(2026, 11, 11),
        meal: 'lunch',
        food: arroz,
        grams: 100,
      );
      await diary.addEntry(
        day: DateTime(2026, 11, 12),
        meal: 'lunch',
        food: arroz,
        grams: 100,
      );

      final day11 = await diary.watchDay(DateTime(2026, 11, 11)).first;
      expect(day11, hasLength(1));
      expect(DayTotals.from(day11).kcal, closeTo(arroz.kcal100, 0.001));
    });
  });

  test('rascunho sobrevive a fechar e reabrir o banco (matar o app)', () async {
    final dir = await Directory.systemTemp.createTemp('nutria_test_');
    final file = File('${dir.path}/nutria.sqlite');

    final first = AppDatabase(NativeDatabase(file));
    await DraftRepository(first).save(
      'add_food|2026-11-11|lunch',
      jsonEncode({'foodId': 3, 'query': 'arroz', 'grams': 150}),
    );
    await first.close();

    // Simula reabrir o app: nova instância, mesmo arquivo.
    final second = AppDatabase(NativeDatabase(file));
    final raw = await DraftRepository(second).load('add_food|2026-11-11|lunch');
    await second.close();

    expect(raw, isNotNull);
    final payload = jsonDecode(raw!) as Map<String, dynamic>;
    expect(payload['query'], 'arroz');
    expect(payload['grams'], 150);

    await dir.delete(recursive: true);
  });
}
