
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutria/data/db/database.dart';
import 'package:nutria/data/remote/open_food_facts.dart';
import 'package:nutria/data/repositories/food_repository.dart';

Map<String, dynamic> _productJson() => {
      'product': {
        'code': '3017620422003',
        'product_name': 'Nutella',
        'brands': 'Ferrero',
        'categories': 'Hazelnut spreads',
        'nutriments': {
          'energy-kcal_100g': 539,
          'proteins_100g': 6.3,
          'carbohydrates_100g': 57.5,
          'fat_100g': 30.9,
          'fiber_100g': 0,
          'sodium_100g': 0.0428,
        },
        'serving_size': '15 g',
        'serving_quantity': 15,
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('cache local do Open Food Facts', () {
    late AppDatabase db;
    late FoodRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = FoodRepository(db);
    });

    tearDown(() => db.close());

    test('importa o produto com código de barras e porção', () async {
      final product = OffProduct.fromJson(_productJson());
      final food = await repo.saveOffProduct(product);

      expect(food.source, 'off');
      expect(food.barcode, '3017620422003');
      expect(food.kcal100, 539);
      expect(food.protein100, 6.3);
      expect(food.category, 'Açúcares e doces');

      final servings = await repo.servingsFor(food.id);
      expect(servings, hasLength(1));
      expect(servings.single.grams, 15);
    });

    test('reaproveita o cache em vez de duplicar', () async {
      final product = OffProduct.fromJson(_productJson());
      final first = await repo.saveOffProduct(product);
      final second = await repo.saveOffProduct(product);

      expect(second.id, first.id);
      expect(await db.foodCount(), 1);
    });

    test('encontra o produto pelo código e pela busca textual', () async {
      final product = OffProduct.fromJson(_productJson());
      final saved = await repo.saveOffProduct(product);

      final byBarcode = await repo.byBarcode('3017620422003');
      final bySearch = await repo.search('nutella');
      final missing = await repo.byBarcode('0000000000000');

      expect(byBarcode?.id, saved.id);
      expect(bySearch.map((f) => f.id), contains(saved.id));
      expect(missing, isNull);
    });

    test('a lista reativa inclui produtos escaneados', () async {
      final stream = repo.watchList(category: 'Açúcares');
      expect(await stream.first, isEmpty);

      await repo.saveOffProduct(OffProduct.fromJson(_productJson()));

      final foods = await stream.first;
      expect(foods, hasLength(1));
      expect(foods.single.name, contains('Nutella'));
    });
  });
}
