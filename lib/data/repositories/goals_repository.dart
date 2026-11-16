import 'package:drift/drift.dart';

import '../../core/user_profile.dart';
import '../db/database.dart';

export '../../core/user_profile.dart' show NutritionGoals;

class GoalsRepository {
  GoalsRepository(this._db);

  final AppDatabase _db;

  Stream<NutritionGoals> watch() => (_db.select(_db.goals)
        ..where((g) => g.id.equals(1)))
      .watchSingleOrNull()
      .map((g) => g == null
          ? NutritionGoals.defaults
          : NutritionGoals(
              kcal: g.kcal,
              protein: g.protein,
              carbs: g.carbs,
              fat: g.fat,
            ));

  Future<void> save(NutritionGoals goals) async {
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
}
