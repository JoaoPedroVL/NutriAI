import '../db/database.dart';

class RecentFoodRepository {
  RecentFoodRepository(this._db);

  final AppDatabase _db;

  Future<List<RecentFood>> getAll({int limit = 10}) async {
    return _db.getRecentFoods(limit: limit);
  }

  Future<void> add(int foodId) async {
    await _db.addRecentFood(foodId);
  }
}