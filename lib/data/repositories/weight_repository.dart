import '../db/database.dart';

class WeightRepository {
  WeightRepository(this._db);

  final AppDatabase _db;

  Future<List<WeightLog>> getAll({int limit = 365}) async {
    return _db.getWeightLogs(limit: limit);
  }

  Future<WeightLog?> getToday() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    return (_db.select(_db.weightLogs)..where((w) => w.day.equals(startOfDay)))
        .getSingleOrNull();
  }

  Future<void> upsert(DateTime day, double weight) async {
    await _db.upsertWeightLog(day, weight);
  }

  Future<void> deleteToday() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    await (_db.delete(_db.weightLogs)..where((w) => w.day.equals(startOfDay))).go();
  }

  Future<double?> getAverage({int days = 30}) async {
    final logs = await getAll(limit: days);
    if (logs.isEmpty) return null;
    final sum = logs.fold<double>(0, (sum, log) => sum + log.weight);
    return sum / logs.length;
  }

  Future<int> getStreak() async {
    final logs = await getAll(limit: 365);
    if (logs.isEmpty) return 0;

    var streak = 0;
    var currentDate = DateTime.now();
    final startOfToday = DateTime(currentDate.year, currentDate.month, currentDate.day);

    for (var i = 0; i < logs.length; i++) {
      final logDate = DateTime(
        logs[i].day.year,
        logs[i].day.month,
        logs[i].day.day,
      );
      if (logDate == startOfToday.subtract(Duration(days: i))) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  Future<List<WeightLog>> getAllLogs() async {
    return getAll(limit: 1000);
  }

  Future<void> saveWeightLog(WeightLog log) async {
    await _db.upsertWeightLog(log.day, log.weight);
  }
}