import '../db/database.dart';

/// Rascunhos de formulário: salvos a cada alteração para que matar o app
/// no meio do preenchimento não perca nada.
class DraftRepository {
  DraftRepository(this._db);

  final AppDatabase _db;

  Future<void> save(String key, String payload) async {
    await _db.into(_db.drafts).insertOnConflictUpdate(
          DraftsCompanion.insert(
            key: key,
            payload: payload,
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<String?> load(String key) async {
    final row = await (_db.select(_db.drafts)..where((d) => d.key.equals(key)))
        .getSingleOrNull();
    return row?.payload;
  }

  Future<void> clear(String key) async {
    await (_db.delete(_db.drafts)..where((d) => d.key.equals(key))).go();
  }
}
