import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/food_style.dart';
import '../../core/text.dart';

/// Produto encontrado no Open Food Facts, já normalizado para o app.
class OffProduct {
  const OffProduct({
    required this.barcode,
    required this.name,
    required this.brand,
    required this.category,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sodiumMg,
    this.servingGrams,
    this.servingLabel,
  });

  final String barcode;
  final String name;
  final String brand;

  /// Categoria já mapeada para o vocabulário do app.
  final String category;

  /// Valores por 100 g (ou 100 ml).
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;

  /// Miligramas por 100 g.
  final double sodiumMg;

  /// Peso de uma porção, quando o produto informa.
  final double? servingGrams;
  final String? servingLabel;

  /// Nome de exibição, evitando repetir a marca.
  String get displayName {
    final cleanBrand = brand.trim();
    if (cleanBrand.isEmpty) return name;
    final normalizedName = normalizeForSearch(name);
    final normalizedBrand = normalizeForSearch(cleanBrand);
    if (normalizedName.contains(normalizedBrand) ||
        normalizedBrand.contains(normalizedName)) {
      return name;
    }
    return '$name · $cleanBrand';
  }

  factory OffProduct.fromJson(
    Map<String, dynamic> json, {
    String? requestedBarcode,
  }) {
    final product = json['product'];
    if (product is! Map<String, dynamic>) {
      throw const OffProductNotFoundException();
    }

    final nutriments = product['nutriments'] is Map<String, dynamic>
        ? product['nutriments'] as Map<String, dynamic>
        : const <String, dynamic>{};

    double nutrient(String key) => (nutriments[key] as num?)?.toDouble() ?? 0;

    final code = (product['code'] as String?)?.trim();
    final barcode = (code != null && code.isNotEmpty)
        ? code
        : (requestedBarcode ?? '');

    final rawName = _firstNonEmpty([
      product['product_name_pt'],
      product['product_name'],
      product['generic_name_pt'],
      product['generic_name'],
    ]);
    if (rawName.isEmpty) {
      throw const OffProductNotFoundException(
        'Produto sem nome cadastrado no Open Food Facts.',
      );
    }

    var kcal = nutrient('energy-kcal_100g');
    if (kcal <= 0) {
      final kj = nutrient('energy_100g') > 0
          ? nutrient('energy_100g')
          : nutrient('energy-kj_100g');
      if (kj > 0) kcal = kj / 4.184;
    }

    final protein = nutrient('proteins_100g');
    final carbs = nutrient('carbohydrates_100g');
    final fat = nutrient('fat_100g');
    final fiber = nutrient('fiber_100g');
    final sodiumMg = nutrient('sodium_100g') * 1000;

    if (kcal <= 0 && protein + carbs + fat <= 0) {
      throw const OffProductNotFoundException(
        'Este produto ainda não tem valores nutricionais no Open Food Facts.',
      );
    }

    final categories = (product['categories'] as String?) ?? '';
    final servingQuantity = (product['serving_quantity'] as num?)?.toDouble();
    final servingSize = (product['serving_size'] as String?)?.trim();

    return OffProduct(
      barcode: barcode,
      name: rawName,
      brand: _firstBrand(product['brands']),
      category: categoryFromOff(categories),
      kcal: kcal,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      sodiumMg: sodiumMg,
      servingGrams: servingQuantity != null && servingQuantity > 0
          ? servingQuantity
          : null,
      servingLabel: servingSize != null && servingSize.isNotEmpty
          ? '1 porção ($servingSize)'
          : null,
    );
  }

  static String _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  static String _firstBrand(Object? value) {
    if (value is! String) return '';
    final first = value.split(',').first.trim();
    return first;
  }
}

/// Erros de consulta ao Open Food Facts, separados por tipo para a UI
/// conseguir dar uma mensagem útil.
class OffException implements Exception {
  const OffException(this.message);
  final String message;

  @override
  String toString() => message;
}

class OffProductNotFoundException extends OffException {
  const OffProductNotFoundException([
    super.message =
        'Produto não encontrado no Open Food Facts. Confira o código.',
  ]);
}

class OffNetworkException extends OffException {
  const OffNetworkException([
    super.message =
        'Não foi possível consultar o Open Food Facts. Verifique sua conexão.',
  ]);
}

class OpenFoodFactsService {
  OpenFoodFactsService({
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static const _fields = 'code,product_name,product_name_pt,brands,'
      'categories,nutriments,serving_size,serving_quantity,quantity';

  Future<OffProduct> lookup(String barcode) async {
    final code = barcode.trim();
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/$code.json',
      {'fields': _fields},
    );

    late http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
    } on TimeoutException {
      throw const OffNetworkException(
        'O Open Food Facts demorou demais para responder. Tente de novo.',
      );
    } catch (_) {
      throw const OffNetworkException();
    }

    if (response.statusCode == 404) {
      throw const OffProductNotFoundException();
    }
    if (response.statusCode != 200) {
      throw OffNetworkException(
        'Open Food Facts respondeu ${response.statusCode}. Tente de novo.',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic> || decoded['status'] != 1) {
      throw const OffProductNotFoundException();
    }

    try {
      return OffProduct.fromJson(decoded, requestedBarcode: code);
    } on OffException {
      rethrow;
    } catch (_) {
      throw const OffProductNotFoundException(
        'Não conseguimos ler os dados deste produto.',
      );
    }
  }
}
