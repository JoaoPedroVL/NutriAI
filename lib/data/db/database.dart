import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Catálogo de alimentos. Valores sempre por 100 g de parte comestível.
@DataClassName('Food')
class Foods extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Nome de exibição, ex.: "Arroz, tipo 1, cozido".
  TextColumn get name => text()();

  /// Nome normalizado (sem acento, minúsculo) para busca rápida.
  TextColumn get searchKey => text()();

  TextColumn get category => text().withDefault(const Constant(''))();

  RealColumn get kcal100 => real()();
  RealColumn get protein100 => real()();
  RealColumn get carbs100 => real()();
  RealColumn get fat100 => real()();
  RealColumn get fiber100 => real()();
  RealColumn get sodium100 => real()();

  /// Código de barras (EAN/UPC), quando o alimento vem de um produto.
  ///
  /// `UNIQUE` (NULLs são permitidos) impede que o mesmo produto entre duas
  /// vezes por duas consultas concorrentes.
  TextColumn get barcode => text().nullable().unique()();

  /// taco | tbca | off | ai | custom
  TextColumn get source => text().withDefault(const Constant('taco'))();

  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Medidas caseiras: "1 colher de sopa de arroz = 25 g".
@DataClassName('FoodServing')
@TableIndex(
  name: 'food_servings_unique',
  columns: {#foodId, #label},
  unique: true,
)
class FoodServings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get foodId =>
      integer().references(Foods, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text()();
  RealColumn get grams => real()();
}

/// Registro do diário. Guarda um SNAPSHOT dos macros no momento do log,
/// para que o histórico não mude se o catálogo for corrigido depois.
@DataClassName('DiaryEntry')
class DiaryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Dia do registro (hora zerada).
  DateTimeColumn get day => dateTime()();

  /// breakfast | lunch | dinner | snack
  TextColumn get meal => text()();

  IntColumn get foodId =>
      integer().nullable().references(Foods, #id, onDelete: KeyAction.setNull)();

  TextColumn get foodName => text()();

  /// Categoria do alimento no momento do log (para ícone/cor).
  TextColumn get category => text().withDefault(const Constant(''))();

  RealColumn get grams => real()();

  RealColumn get kcal => real()();
  RealColumn get protein => real()();
  RealColumn get carbs => real()();
  RealColumn get fat => real()();

  /// UUID estável: garante sync idempotente (não duplica ao reenviar).
  TextColumn get syncId => text().unique()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Rascunho persistido de formulários. Salvo a cada digitação.
@DataClassName('Draft')
class Drafts extends Table {
  TextColumn get key => text()();
  TextColumn get payload => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Metas diárias (linha única, id = 1).
@DataClassName('Goal')
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get kcal => real()();
  RealColumn get protein => real()();
  RealColumn get carbs => real()();
  RealColumn get fat => real()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Metadados internos (ex.: versão do dataset semeado).
@DataClassName('AppMetaRow')
class AppMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Perfil do usuário (onboarding).
/// Uma única linha (id = 1).
@DataClassName('UserProfileData')
class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// masculino | feminino
  TextColumn get sex => text().nullable()();
  IntColumn get age => integer().nullable()();
  /// Peso em kg
  RealColumn get weight => real().nullable()();
  /// Altura em cm
  IntColumn get height => integer().nullable()();
  /// sedentario | leve | moderado | intenso
  TextColumn get activityLevel => text().nullable()();
  /// perder | manter | ganhar
  TextColumn get goal => text().nullable()();
  /// Metas calculadas (kcal, protein, carbs, fat)
  RealColumn get kcal => real().nullable()();
  RealColumn get protein => real().nullable()();
  RealColumn get carbs => real().nullable()();
  RealColumn get fat => real().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Histórico de peso (para gráfico de progresso).
@DataClassName('WeightLog')
class WeightLogs extends Table {
  DateTimeColumn get day => dateTime()();
  RealColumn get weight => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {day};
}

/// Refeições salvas (templates para reutilização rápida).
@DataClassName('SavedMeal')
class SavedMeals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  /// breakfast | lunch | dinner | snack
  TextColumn get meal => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Itens de uma refeição salva.
@DataClassName('SavedMealItem')
class SavedMealItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get savedMealId =>
      integer().references(SavedMeals, #id, onDelete: KeyAction.cascade)();
  IntColumn get foodId => integer()
      .nullable()
      .references(Foods, #id, onDelete: KeyAction.setNull)();
  TextColumn get foodName => text()();
  TextColumn get category => text().withDefault(const Constant(''))();
  RealColumn get grams => real()();
  RealColumn get kcal => real().withDefault(const Constant(0))();
  RealColumn get protein => real().withDefault(const Constant(0))();
  RealColumn get carbs => real().withDefault(const Constant(0))();
  RealColumn get fat => real().withDefault(const Constant(0))();
  TextColumn get meal => text()(); // breakfast | lunch | dinner | snack
}

/// Favoritos do usuário (alimentos marcados com estrela).
@DataClassName('Favorite')
class Favorites extends Table {
  IntColumn get foodId =>
      integer().references(Foods, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {foodId};
}

/// Alimentos recentes (últimos usados para acesso rápido).
@DataClassName('RecentFood')
class RecentFoods extends Table {
  IntColumn get foodId =>
      integer().references(Foods, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get lastUsedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {foodId};
}

/// Registro de consumo de água.
@DataClassName('WaterLog')
class WaterLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get day => dateTime()(); // dia (hora zerada)
  RealColumn get amountMl => real()(); // quantidade em ml
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(
  tables: [
    Foods,
    FoodServings,
    DiaryEntries,
    Drafts,
    Goals,
    AppMeta,
    UserProfiles,
    WeightLogs,
    SavedMeals,
    SavedMealItems,
    Favorites,
    RecentFoods,
    WaterLogs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(
          executor ??
              driftDatabase(
                name: 'nutria',
                web: DriftWebOptions(
                  sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                  driftWorker: Uri.parse('drift_worker.js'),
                ),
              ),
        );

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(diaryEntries, diaryEntries.category);
          }
          if (from < 3) {
            await m.addColumn(foods, foods.barcode);
          }
          if (from < 4) {
            // No web (WASM), customStatement pode falhar silenciosamente se
            // houver deadlock. Usamos IF NOT EXISTS e tentamos dedup com
            // SQL simples. Se tudo falhar, a próxima abertura recria o schema.
            try {
              await _dedupeBarcodes();
              await _dedupeServings();
            } catch (_) {
              // Ignora erros de dedup no web; os índices UNIQUE abaixo
              // impedirão duplicatas futuras.
            }
            await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS foods_barcode_unique '
              'ON foods (barcode)',
            );
            await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS food_servings_unique '
              'ON food_servings (food_id, label)',
            );
            await m.create(appMeta);
          }
          if (from < 5) {
            // Novas tabelas: perfil do usuário, peso, refeições salvas, favoritos, recentes
            await m.create(userProfiles);
            await m.create(weightLogs);
            await m.create(savedMeals);
            await m.create(savedMealItems);
            await m.create(favorites);
            await m.create(recentFoods);
          }
          if (from == 5) {
            // Snapshot dos macros nos itens de refeições salvas.
            await m.addColumn(savedMealItems, savedMealItems.category);
            await m.addColumn(savedMealItems, savedMealItems.kcal);
            await m.addColumn(savedMealItems, savedMealItems.protein);
            await m.addColumn(savedMealItems, savedMealItems.carbs);
            await m.addColumn(savedMealItems, savedMealItems.fat);
          }
          if (from < 7) {
            // Tabela de consumo de água.
            await m.create(waterLogs);
          }
        },
        beforeOpen: (details) async {
          // SQLite nasce com FKs desligadas; sem isso os `references` do
          // schema são apenas decorativos.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<int> foodCount() async {
    final count = foods.id.count();
    final query = selectOnly(foods)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> tacoFoodCount() async {
    final count = foods.id.count();
    final query = selectOnly(foods)
      ..addColumns([count])
      ..where(foods.source.equals('taco'));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<String?> metaValue(String key) async {
    final row = await (select(appMeta)..where((m) => m.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setMeta(String key, String value) async {
    await into(appMeta).insertOnConflictUpdate(
      AppMetaCompanion.insert(key: key, value: value),
    );
  }

  /// Junta produtos repetidos (mesmo código de barras), preservando o mais
  /// antigo e reapontando porções/diário antes de apagar as cópias.
  Future<void> _dedupeBarcodes() async {
    final duplicated = await customSelect(
      'SELECT barcode, MIN(id) AS keep FROM foods '
      'WHERE barcode IS NOT NULL '
      'GROUP BY barcode HAVING COUNT(*) > 1',
    ).get();

    for (final row in duplicated) {
      final barcode = row.read<String>('barcode');
      final keep = row.read<int>('keep');
      final copies = await customSelect(
        'SELECT id FROM foods WHERE barcode = ? AND id <> ?',
        variables: [Variable.withString(barcode), Variable.withInt(keep)],
      ).get();

      for (final copy in copies) {
        final id = copy.read<int>('id');
        await customStatement(
          'UPDATE food_servings SET food_id = ? WHERE food_id = ?',
          [keep, id],
        );
        await customStatement(
          'UPDATE diary_entries SET food_id = ? WHERE food_id = ?',
          [keep, id],
        );
        await customStatement('DELETE FROM foods WHERE id = ?', [id]);
      }
    }
  }

  /// Remove medidas caseiras repetidas (mesmo alimento + mesmo rótulo).
  Future<void> _dedupeServings() async {
    await customStatement(
      'DELETE FROM food_servings WHERE id NOT IN ('
      '  SELECT MIN(id) FROM food_servings GROUP BY food_id, label'
      ')',
    );
  }

  /// Insere ou atualiza uma medida caseira usando o índice único (food_id, label).
  /// Evita erro de UNIQUE constraint quando a medida já existe.
  Future<void> upsertServing({
    required int foodId,
    required String label,
    required double grams,
  }) async {
    await customStatement(
      'INSERT INTO food_servings (food_id, label, grams) VALUES (?, ?, ?) '
      'ON CONFLICT(food_id, label) DO UPDATE SET grams = ?',
      [foodId, label, grams, grams],
    );
  }

  /// Perfil do usuário (onboarding) — linha única id = 1.
  Future<UserProfileData?> getUserProfile() async {
    return (select(userProfiles)..where((u) => u.id.equals(1))).getSingleOrNull();
  }

  Future<void> saveUserProfile(UserProfileData profile) async {
    await into(userProfiles).insertOnConflictUpdate(
      UserProfilesCompanion.insert(
        id: const Value(1),
        sex: Value(profile.sex),
        age: Value(profile.age),
        weight: Value(profile.weight),
        height: Value(profile.height),
        activityLevel: Value(profile.activityLevel),
        goal: Value(profile.goal),
        kcal: Value(profile.kcal),
        protein: Value(profile.protein),
        carbs: Value(profile.carbs),
        fat: Value(profile.fat),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Histórico de peso.
  Future<List<WeightLog>> getWeightLogs({int limit = 365}) async {
    return (select(weightLogs)
          ..orderBy([(w) => OrderingTerm.desc(w.day)])
          ..limit(limit))
        .get();
  }

  Future<void> upsertWeightLog(DateTime day, double weight) async {
    await into(weightLogs).insertOnConflictUpdate(
      WeightLogsCompanion.insert(
        day: DateTime(day.year, day.month, day.day),
        weight: weight,
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  /// Refeições salvas.
  Future<List<SavedMeal>> getSavedMeals() async {
    return (select(savedMeals)
          ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
        .get();
  }

  Future<SavedMeal?> getSavedMeal(int id) async {
    return (select(savedMeals)..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  Future<int> createSavedMeal({
    required String name,
    required String meal,
  }) async {
    return await into(savedMeals).insert(
      SavedMealsCompanion.insert(
        name: name,
        meal: meal,
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteSavedMeal(int id) async {
    await (delete(savedMeals)..where((s) => s.id.equals(id))).go();
  }

  Future<List<SavedMealItem>> getSavedMealItems(int savedMealId) async {
    return (select(savedMealItems)
          ..where((i) => i.savedMealId.equals(savedMealId)))
        .get();
  }

  Future<void> addSavedMealItem(SavedMealItem item) async {
    await into(savedMealItems).insert(
      SavedMealItemsCompanion.insert(
        savedMealId: item.savedMealId,
        foodId: Value(item.foodId),
        foodName: item.foodName,
        category: Value(item.category),
        grams: item.grams,
        kcal: Value(item.kcal),
        protein: Value(item.protein),
        carbs: Value(item.carbs),
        fat: Value(item.fat),
        meal: item.meal,
      ),
    );
  }

  /// Favoritos.
  Future<List<Favorite>> getFavorites() async {
    return (select(favorites)
          ..orderBy([(f) => OrderingTerm.desc(f.createdAt)]))
        .get();
  }

  Future<bool> isFavorite(int foodId) async {
    final row = await (select(favorites)..where((f) => f.foodId.equals(foodId)))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> toggleFavorite(int foodId) async {
    final existing = await isFavorite(foodId);
    if (existing) {
      await (delete(favorites)..where((f) => f.foodId.equals(foodId))).go();
    } else {
      await into(favorites).insert(
        FavoritesCompanion.insert(
          foodId: Value(foodId),
          createdAt: Value(DateTime.now()),
        ),
      );
    }
  }

  /// Alimentos recentes.
  Future<List<RecentFood>> getRecentFoods({int limit = 10}) async {
    return (select(recentFoods)
          ..orderBy([(r) => OrderingTerm.desc(r.lastUsedAt)])
          ..limit(limit))
        .get();
  }

  Future<void> addRecentFood(int foodId) async {
    await into(recentFoods).insertOnConflictUpdate(
      RecentFoodsCompanion.insert(
        foodId: Value(foodId),
        lastUsedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Consumo de água.
  Future<List<WaterLog>> getWaterLogs({int limit = 365}) async {
    return (select(waterLogs)
          ..orderBy([(w) => OrderingTerm.desc(w.day)])
          ..limit(limit))
        .get();
  }

  Future<double> getTodayWaterAmount() async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final result = await (select(waterLogs)..where((w) => w.day.equals(today))).get();
    return result.fold<double>(0.0, (sum, log) => sum + log.amountMl);
  }

  Future<void> addWaterLog(double amountMl) async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    await into(waterLogs).insert(
      WaterLogsCompanion.insert(
        day: today,
        amountMl: amountMl,
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteWaterLog(int id) async {
    await (delete(waterLogs)..where((w) => w.id.equals(id))).go();
  }

  Future<List<Food>> getCustomFoods() async {
    return (select(foods)..where((f) => f.source.equals('custom'))).get();
  }
}

