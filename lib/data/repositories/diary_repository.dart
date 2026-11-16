import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/text.dart';
import '../../core/user_profile.dart';
import '../db/database.dart';

class DayTotals {
  const DayTotals({
    this.kcal = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  factory DayTotals.from(Iterable<DiaryEntry> entries) {
    var kcal = 0.0;
    var protein = 0.0;
    var carbs = 0.0;
    var fat = 0.0;
    for (final e in entries) {
      kcal += e.kcal;
      protein += e.protein;
      carbs += e.carbs;
      fat += e.fat;
    }
    return DayTotals(kcal: kcal, protein: protein, carbs: carbs, fat: fat);
  }
}

class DiaryRepository {
  DiaryRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<DiaryEntry>> watchDay(DateTime day) {
    final start = startOfDay(day);
    final end = nextDay(day);
    return (_db.select(_db.diaryEntries)
          ..where((e) =>
              e.day.isBiggerOrEqualValue(start) &
              e.day.isSmallerThanValue(end))
          ..orderBy([(e) => OrderingTerm.asc(e.createdAt)]))
        .watch();
  }

  /// Registros de um intervalo [from, to) — usado pelos gráficos de progresso.
  Stream<List<DiaryEntry>> watchRange(DateTime from, DateTime to) {
    return (_db.select(_db.diaryEntries)
          ..where((e) =>
              e.day.isBiggerOrEqualValue(startOfDay(from)) &
              e.day.isSmallerThanValue(startOfDay(to)))
          ..orderBy([(e) => OrderingTerm.asc(e.day)]))
        .watch();
  }

  /// Grava o registro com snapshot dos macros. É uma escrita local e
  /// síncrona do ponto de vista da UI: não depende de rede.
  Future<int> addEntry({
    required DateTime day,
    required String meal,
    required Food food,
    required double grams,
  }) {
    final factor = grams / 100.0;
    return _db.into(_db.diaryEntries).insert(
          DiaryEntriesCompanion.insert(
            day: startOfDay(day),
            meal: meal,
            foodId: Value(food.id),
            foodName: food.name,
            category: Value(food.category),
            grams: grams,
            kcal: food.kcal100 * factor,
            protein: food.protein100 * factor,
            carbs: food.carbs100 * factor,
            fat: food.fat100 * factor,
            syncId: _uuid.v4(),
          ),
        );
  }

  /// Recalcula os macros proporcionalmente, sem consultar o catálogo
  /// (o snapshot continua sendo a fonte da verdade).
  ///
  /// Retorna true se gravou, false se `grams` for inválido (<= 0).
  Future<bool> updateGrams(DiaryEntry entry, double grams) async {
    if (entry.grams <= 0 || grams <= 0) return false;
    final ratio = grams / entry.grams;
    await (_db.update(_db.diaryEntries)
          ..where((e) => e.id.equals(entry.id)))
        .write(
      DiaryEntriesCompanion(
        grams: Value(grams),
        kcal: Value(entry.kcal * ratio),
        protein: Value(entry.protein * ratio),
        carbs: Value(entry.carbs * ratio),
        fat: Value(entry.fat * ratio),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return true;
  }

  Future<void> deleteEntry(int id) async {
    await (_db.delete(_db.diaryEntries)..where((e) => e.id.equals(id))).go();
  }

  /// Copia todas as entradas de uma refeição de outro dia.
  ///
  /// Retorna quantas entradas foram copiadas (0 quando a origem está vazia).
  Future<int> copyMeal({
    required DateTime fromDay,
    required DateTime toDay,
    required String meal,
  }) async {
    final source = await (_db.select(_db.diaryEntries)
          ..where((e) =>
              e.day.isBiggerOrEqualValue(startOfDay(fromDay)) &
              e.day.isSmallerThanValue(nextDay(fromDay)) &
              e.meal.equals(meal)))
        .get();
    if (source.isEmpty) return 0;

    await _db.batch((batch) {
      for (final entry in source) {
        batch.insert(
          _db.diaryEntries,
          DiaryEntriesCompanion.insert(
            day: startOfDay(toDay),
            meal: meal,
            foodId: Value(entry.foodId),
            foodName: entry.foodName,
            category: Value(entry.category),
            grams: entry.grams,
            kcal: entry.kcal,
            protein: entry.protein,
            carbs: entry.carbs,
            fat: entry.fat,
            syncId: _uuid.v4(),
          ),
        );
      }
    });
    return source.length;
  }

  Future<List<DiaryEntry>> getAllEntries() async {
    return (_db.select(_db.diaryEntries)
          ..orderBy([(e) => OrderingTerm.asc(e.day)]))
        .get();
  }

  Future<NutritionGoals?> getGoals() async {
    final row = await (_db.select(_db.goals)).getSingleOrNull();
    if (row == null) return null;
    return NutritionGoals(
      kcal: row.kcal,
      protein: row.protein,
      carbs: row.carbs,
      fat: row.fat,
    );
  }

  Future<void> setGoals(NutritionGoals goals) async {
    await _db.into(_db.goals).insertOnConflictUpdate(
      GoalsCompanion.insert(
        id: const Value(1),
        kcal: goals.kcal,
        protein: goals.protein,
        carbs: goals.carbs,
        fat: goals.fat,
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> insertEntry(DiaryEntry entry) async {
    await _db.into(_db.diaryEntries).insert(
      DiaryEntriesCompanion.insert(
        id: Value(entry.id),
        day: entry.day,
        meal: entry.meal,
        foodId: Value(entry.foodId),
        foodName: entry.foodName,
        category: Value(entry.category),
        grams: entry.grams,
        kcal: entry.kcal,
        protein: entry.protein,
        carbs: entry.carbs,
        fat: entry.fat,
        syncId: entry.syncId,
        createdAt: Value(entry.createdAt),
        updatedAt: Value(entry.updatedAt),
      ),
    );
  }
}
