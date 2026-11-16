import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutria/app/providers.dart';
import 'package:nutria/core/theme.dart';
import 'package:nutria/data/db/database.dart';
import 'package:nutria/data/remote/open_food_facts.dart';
import 'package:nutria/features/barcode/barcode_scan_screen.dart';

Map<String, dynamic> _productJson() => {
      'status': 1,
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
        },
        'serving_size': '15 g',
        'serving_quantity': 15,
      },
    };

void main() {
  testWidgets('valida código curto e mostra o produto encontrado',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final service = OpenFoodFactsService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode(_productJson()),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          offServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: BarcodeScanScreen(
            day: DateTime(2026, 11, 12),
            meal: 'lunch',
            enableCamera: false,
          ),
        ),
      ),
    );
    await tester.pump();

    // Código inválido (muito curto): mensagem amigável, sem consultar a rede.
    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('Buscar produto'));
    await tester.pump();
    expect(find.textContaining('Código de barras inválido'), findsOneWidget);

    // Código válido: consulta (mock) e mostra o produto.
    await tester.enterText(find.byType(TextField), '3017620422003');
    await tester.tap(find.text('Buscar produto'));
    for (var i = 0; i < 20 && find.text('Nutella').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.textContaining('Nutella'), findsOneWidget);
    expect(find.text('OPEN FOOD FACTS'), findsOneWidget);
    expect(find.text('Escolher porção'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  });
}
