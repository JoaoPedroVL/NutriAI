import '../db/database.dart';
import 'package:drift/drift.dart';

class WaterRepository {
  WaterRepository(this._db);

  final AppDatabase _db;

  /// Obtém todos os logs de água (padrão: últimos 365 dias).
  Future<List<WaterLog>> getAll({int limit = 365}) async {
    return _db.getWaterLogs(limit: limit);
  }

  /// Obtém o total de água consumida hoje em ml.
  Future<double> getTodayAmount() async {
    return _db.getTodayWaterAmount();
  }

  /// Registros de hoje, do mais recente para o mais antigo (para desfazer).
  Future<List<WaterLog>> getTodayLogs() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return (_db.select(_db.waterLogs)
          ..where((w) => w.day.equals(today))
          ..orderBy([(w) => OrderingTerm.desc(w.createdAt)]))
        .get();
  }

  /// Adiciona um registro de água.
  Future<void> addLog(double amountMl) async {
    await _db.addWaterLog(amountMl);
  }

  /// Remove um registro de água.
  Future<void> deleteLog(int id) async {
    await _db.deleteWaterLog(id);
  }

  /// Obtém logs de água de um intervalo de datas.
  Future<List<WaterLog>> getRange(DateTime from, DateTime to) async {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day).add(const Duration(days: 1));
    return (_db.select(_db.waterLogs)
          ..where((w) => w.day.isBetweenValues(start, end))
          ..orderBy([(w) => OrderingTerm.asc(w.day)]))
        .get();
  }

  /// Obtém média diária de água nos últimos N dias.
  Future<double?> getAverage({int days = 30}) async {
    final logs = await getAll(limit: days);
    if (logs.isEmpty) return null;
    final sum = logs.fold<double>(0.0, (sum, log) => sum + log.amountMl);
    return sum / logs.length;
  }
}