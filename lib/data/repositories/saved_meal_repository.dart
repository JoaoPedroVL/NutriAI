import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/text.dart';
import '../db/database.dart';

class SavedMealRepository {
  SavedMealRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<SavedMeal>> getAll() async {
    return _db.getSavedMeals();
  }

  Future<SavedMeal?> getById(int id) async {
    return _db.getSavedMeal(id);
  }

  Future<int> create({
    required String name,
    required String meal,
  }) async {
    return _db.createSavedMeal(name: name, meal: meal);
  }

  Future<void> delete(int id) async {
    await _db.deleteSavedMeal(id);
  }

  Future<List<SavedMealItem>> getItems(int savedMealId) async {
    return _db.getSavedMealItems(savedMealId);
  }

  Future<void> addItem(SavedMealItem item) async {
    await _db.addSavedMealItem(item);
  }

  Future<void> deleteWithItems(int id) async {
    await (_db.delete(_db.savedMealItems)
          ..where((i) => i.savedMealId.equals(id)))
        .go();
    await (_db.delete(_db.savedMeals)..where((s) => s.id.equals(id))).go();
  }

  /// Salva as entradas de uma refeição como template reutilizável.
  Future<int> saveFromEntries({
    required String name,
    required String meal,
    required List<DiaryEntry> entries,
  }) async {
    final id = await create(name: name, meal: meal);
    await _db.batch((batch) {
      for (final entry in entries) {
        batch.insert(
          _db.savedMealItems,
          SavedMealItemsCompanion.insert(
            savedMealId: id,
            foodId: Value(entry.foodId),
            foodName: entry.foodName,
            category: Value(entry.category),
            grams: entry.grams,
            kcal: Value(entry.kcal),
            protein: Value(entry.protein),
            carbs: Value(entry.carbs),
            fat: Value(entry.fat),
            meal: entry.meal,
          ),
        );
      }
    });
    return id;
  }

  /// Copia os itens de uma refeição salva para o diário de [day].
  ///
  /// Retorna quantos itens foram adicionados.
  Future<int> applyToDay({
    required int savedMealId,
    required DateTime day,
    String? meal,
  }) async {
    final items = await getItems(savedMealId);
    if (items.isEmpty) return 0;

    await _db.batch((batch) {
      for (final item in items) {
        batch.insert(
          _db.diaryEntries,
          DiaryEntriesCompanion.insert(
            day: startOfDay(day),
            meal: meal ?? item.meal,
            foodId: Value(item.foodId),
            foodName: item.foodName,
            category: Value(item.category),
            grams: item.grams,
            kcal: item.kcal,
            protein: item.protein,
            carbs: item.carbs,
            fat: item.fat,
            syncId: _uuid.v4(),
          ),
        );
      }
    });
    return items.length;
  }

  /// Insere uma refeição salva completa (para backup/import).
  Future<void> insert(SavedMeal meal) async {
    await _db.into(_db.savedMeals).insert(
      SavedMealsCompanion.insert(
        id: Value(meal.id),
        name: meal.name,
        meal: meal.meal,
        createdAt: Value(meal.createdAt),
      ),
    );
  }
}
