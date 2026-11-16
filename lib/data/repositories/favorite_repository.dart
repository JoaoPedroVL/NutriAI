import '../db/database.dart';

class FavoriteRepository {
  FavoriteRepository(this._db);

  final AppDatabase _db;

  Future<List<Favorite>> getAll() async {
    return _db.getFavorites();
  }

  Future<bool> isFavorite(int foodId) async {
    return _db.isFavorite(foodId);
  }

  Future<void> toggle(int foodId) async {
    await _db.toggleFavorite(foodId);
  }
}