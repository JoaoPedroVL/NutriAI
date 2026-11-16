import 'package:drift/drift.dart';

import '../../core/defaults.dart';
import '../../core/text.dart';
import '../db/database.dart';
import '../remote/open_food_facts.dart';

class FoodRepository {
  FoodRepository(this._db);

  final AppDatabase _db;

  /// Busca por nome normalizado (sem acento, minúsculo).
  Future<List<Food>> search(String query, {int limit = 40}) async {
    final q = normalizeForSearch(query);
    // Se a consulta original não era vazia mas normalizou para vazio
    // (ex.: só símbolos/emoji), não devolve o catálogo inteiro.
    final select = _db.select(_db.foods);
    if (query.trim().isNotEmpty && q.isEmpty) {
      select.where((f) => f.id.equals(-1)); // sempre falso
    } else if (q.isNotEmpty) {
      select.where((f) => f.searchKey.like('%$q%'));
    }
    select
      ..orderBy([(f) => OrderingTerm.asc(f.name)])
      ..limit(limit);
    return select.get();
  }

  Future<Food?> byId(int id) =>
      (_db.select(_db.foods)..where((f) => f.id.equals(id))).getSingleOrNull();

  /// Produto já importado do Open Food Facts (cache local).
  Future<Food?> byBarcode(String barcode) async {
    final rows = await (_db.select(_db.foods)
          ..where((f) => f.barcode.equals(barcode))
          ..limit(2))
        .get();
    if (rows.length > 1) {
      // Não deveria acontecer (índice UNIQUE), mas se houver duplicatas
      // devolve a primeira e loga para diagnóstico.
      return rows.first;
    }
    return rows.isEmpty ? null : rows.first;
  }

  /// Lista o catálogo com filtros opcionais de texto e categoria.
  Future<List<Food>> list({
    String query = '',
    String? category,
    int limit = 1000,
  }) async {
    final q = normalizeForSearch(query);
    final select = _db.select(_db.foods);
    if (q.isNotEmpty) {
      select.where((f) => f.searchKey.like('%$q%'));
    }
    if (category != null && category.isNotEmpty) {
      select.where((f) => f.category.like('%$category%'));
    }
    select
      ..orderBy([(f) => OrderingTerm.asc(f.name)])
      ..limit(limit);
    return select.get();
  }

  /// Versão reativa de [list] — a lista se atualiza quando o catálogo muda
  /// (por exemplo, ao importar um produto escaneado).
  Stream<List<Food>> watchList({
    String query = '',
    String? category,
    int limit = 300,
  }) {
    final q = normalizeForSearch(query);
    final select = _db.select(_db.foods);
    if (q.isNotEmpty) {
      select.where((f) => f.searchKey.like('%$q%'));
    }
    if (category != null && category.isNotEmpty) {
      select.where((f) => f.category.like('%$category%'));
    }
    select
      ..orderBy([(f) => OrderingTerm.asc(f.name)])
      ..limit(limit);
    return select.watch();
  }

  Future<List<FoodServing>> servingsFor(int foodId) => (_db.select(_db.foodServings)
        ..where((s) => s.foodId.equals(foodId))
        ..orderBy([(s) => OrderingTerm.asc(s.grams)]))
      .get();

  Future<Food> createCustomFood({
    required String name,
    required double kcal100,
    required double protein100,
    required double carbs100,
    required double fat100,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Nome do alimento não pode ser vazio.');
    }
    if (!kcal100.isFinite ||
        kcal100 < 0 ||
        kcal100 > kMaxKcalPer100 ||
        !protein100.isFinite ||
        protein100 < 0 ||
        protein100 > kMaxMacroPer100 ||
        !carbs100.isFinite ||
        carbs100 < 0 ||
        carbs100 > kMaxMacroPer100 ||
        !fat100.isFinite ||
        fat100 < 0 ||
        fat100 > kMaxMacroPer100) {
      throw ArgumentError('Valores nutricionais inválidos.');
    }

    final searchKey = normalizeForSearch(trimmed);
    final id = await _db.into(_db.foods).insert(
          FoodsCompanion.insert(
            name: trimmed,
            searchKey: searchKey.isEmpty ? 'personalizado' : searchKey,
            kcal100: kcal100,
            protein100: protein100,
            carbs100: carbs100,
            fat100: fat100,
            fiber100: 0,
            sodium100: 0,
            source: const Value('custom'),
            isCustom: const Value(true),
          ),
        );
    return (await byId(id))!;
  }

  /// Importa (ou reaproveita) um produto do Open Food Facts.
  ///
  /// O produto fica em cache local com `source = 'off'`, então escaneá-lo de
  /// novo funciona até sem internet. Valida os dados antes de gravar.
  Future<Food> saveOffProduct(OffProduct product) async {
    // Barreira reentrante: se já existe, devolve (o índice UNIQUE impede
    // duplicatas, mas isso evita a consulta extra).
    final existing = await byBarcode(product.barcode);
    if (existing != null) return existing;

    // Valida/limita os valores vindos do OFF antes de persistir.
    final kcal = product.kcal.isFinite && product.kcal >= 0 && product.kcal <= kMaxKcalPer100
        ? product.kcal.toDouble()
        : 0.0;
    final protein = product.protein.isFinite && product.protein >= 0 && product.protein <= kMaxMacroPer100
        ? product.protein.toDouble()
        : 0.0;
    final carbs = product.carbs.isFinite && product.carbs >= 0 && product.carbs <= kMaxMacroPer100
        ? product.carbs.toDouble()
        : 0.0;
    final fat = product.fat.isFinite && product.fat >= 0 && product.fat <= kMaxMacroPer100
        ? product.fat.toDouble()
        : 0.0;
    final fiber = product.fiber.isFinite && product.fiber >= 0 && product.fiber <= kMaxMacroPer100
        ? product.fiber.toDouble()
        : 0.0;
    final sodiumMg = product.sodiumMg.isFinite && product.sodiumMg >= 0 && product.sodiumMg <= kMaxSodiumMgPer100
        ? product.sodiumMg.toDouble()
        : 0.0;

    // Se tudo zerou/foi barrado, não salva.
    if (kcal == 0 && protein == 0 && carbs == 0 && fat == 0) {
      throw OffProductNotFoundException(
        'Este produto não tem valores nutricionais válidos.',
      );
    }

    final servingGrams = product.servingGrams;
    final validServing = servingGrams != null &&
        servingGrams > 0 &&
        servingGrams <= kMaxServingGrams &&
        servingGrams.isFinite;

    // Transação: garante atomicidade entre food + food_servings.
    return _db.transaction(() async {
      final name = _truncate(product.displayName, 140);
      final id = await _db.into(_db.foods).insert(
            FoodsCompanion.insert(
              name: name,
              searchKey: normalizeForSearch(name),
              category: Value(product.category),
              kcal100: kcal,
              protein100: protein,
              carbs100: carbs,
              fat100: fat,
              fiber100: fiber,
              sodium100: sodiumMg,
              source: const Value('off'),
              isCustom: const Value(false),
              barcode: Value(product.barcode),
            ),
          );

      if (validServing) {
        await _db.upsertServing(
          foodId: id,
          label: product.servingLabel ?? '1 porção',
          grams: servingGrams,
        );
      }

      return (await byId(id))!;
    });
  }

  static String _truncate(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);
}
