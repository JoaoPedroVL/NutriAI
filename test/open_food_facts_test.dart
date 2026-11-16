import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutria/core/food_style.dart';
import 'package:nutria/data/remote/open_food_facts.dart';

Map<String, dynamic> _nutellaJson() => {
      'status': 1,
      'code': '3017620422003',
      'product': {
        'code': '3017620422003',
        'product_name': 'Nutella',
        'brands': 'Ferrero, Nutella',
        'categories': 'Hazelnut spreads, Confectionary based spreads',
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
  group('OffProduct', () {
    test('lê os valores por 100 g e a porção', () {
      final product = OffProduct.fromJson(_nutellaJson());

      expect(product.barcode, '3017620422003');
      expect(product.name, 'Nutella');
      expect(product.kcal, 539);
      expect(product.protein, 6.3);
      expect(product.carbs, 57.5);
      expect(product.fat, 30.9);
      expect(product.sodiumMg, closeTo(42.8, 0.01));
      expect(product.servingGrams, 15);
      expect(product.servingLabel, '1 porção (15 g)');
      expect(product.category, 'Açúcares e doces');
    });

    test('usa kJ quando não há kcal', () {
      final product = OffProduct.fromJson({
        'product': {
          'code': '123',
          'product_name': 'Teste',
          'nutriments': {
            'energy_100g': 418.4,
            'proteins_100g': 10,
          },
        },
      });

      expect(product.kcal, closeTo(100, 0.01));
    });

    test('não repete a marca no nome', () {
      final product = OffProduct.fromJson({
        'product': {
          'code': '7894900010015',
          'product_name': 'Coca Cola LT 350ml',
          'brands': 'Coca-Cola',
          'nutriments': {'energy-kcal_100g': 44},
        },
      });

      expect(product.displayName, 'Coca Cola LT 350ml');
    });

    test('lança erro amigável sem dados nutricionais', () {
      expect(
        () => OffProduct.fromJson({
          'product': {
            'code': '123',
            'product_name': 'Água',
            'nutriments': <String, dynamic>{},
          },
        }),
        throwsA(isA<OffProductNotFoundException>()),
      );
    });
  });

  group('OpenFoodFactsService', () {
    test('busca o produto e devolve os dados normalizados', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'world.openfoodfacts.org');
        expect(request.url.path, contains('/product/3017620422003.json'));
        return http.Response(
          jsonEncode(_nutellaJson()),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final product =
          await OpenFoodFactsService(client: client).lookup('3017620422003');

      expect(product.name, 'Nutella');
      expect(product.kcal, 539);
    });

    test('código inexistente vira OffProductNotFoundException', () async {
      final client = MockClient(
        (_) async => http.Response('{"status":0}', 200),
      );

      expect(
        () => OpenFoodFactsService(client: client).lookup('0000000000000'),
        throwsA(isA<OffProductNotFoundException>()),
      );
    });

    test('falha de rede vira OffNetworkException', () async {
      final client = MockClient((_) async => throw Exception('offline'));

      expect(
        () => OpenFoodFactsService(client: client).lookup('3017620422003'),
        throwsA(isA<OffNetworkException>()),
      );
    });
  });

  group('categoryFromOff', () {
    test('mapeia bebidas', () {
      expect(
        categoryFromOff('Colas, Sweetened beverages, pt:Refrigerantes'),
        'Bebidas',
      );
    });

    test('mapeia laticínios, cereais e carnes', () {
      expect(categoryFromOff('Dairies, Yogurts'), 'Leite e derivados');
      expect(categoryFromOff('Breads, Cereals and potatoes'),
          'Cereais e derivados');
      expect(categoryFromOff('Meats, Poultry'), 'Carnes e derivados');
    });

    test('cai em produtos industrializados quando não reconhece', () {
      expect(categoryFromOff('Something unknown'), 'Produtos industrializados');
    });
  });
}
