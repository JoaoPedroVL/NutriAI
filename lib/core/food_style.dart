import 'package:flutter/material.dart';

/// Emoji e cor por categoria da TACO — dá personalidade sem precisar de fotos.
String categoryEmoji(String category) {
  final c = category.toLowerCase();
  if (c.contains('cereal') || c.contains('cereais')) return '🌾';
  if (c.contains('carne')) return '🍗';
  if (c.contains('pescado') || c.contains('peixe')) return '🐟';
  if (c.contains('fruta')) return '🍎';
  if (c.contains('hortaliça') || c.contains('verdura') || c.contains('legume')) {
    return '🥦';
  }
  if (c.contains('leguminosa')) return '🫘';
  if (c.contains('ovo')) return '🥚';
  if (c.contains('leite') || c.contains('lácteo') || c.contains('derivado')) {
    return '🥛';
  }
  if (c.contains('bebida')) return '🥤';
  if (c.contains('açúcar') || c.contains('doce')) return '🍬';
  if (c.contains('gordura') || c.contains('óleo')) return '🫒';
  if (c.contains('noz') || c.contains('semente')) return '🥜';
  if (c.contains('preparado')) return '🍲';
  if (c.contains('industrializado')) return '🏷️';
  return '🍽️';
}

Color categoryColor(String category) {
  final c = category.toLowerCase();
  if (c.contains('cereal') || c.contains('cereais')) {
    return const Color(0xFFC99A2E);
  }
  if (c.contains('carne')) return const Color(0xFFC9553D);
  if (c.contains('pescado') || c.contains('peixe')) return const Color(0xFF3E8FB0);
  if (c.contains('fruta')) return const Color(0xFFE07A3F);
  if (c.contains('hortaliça') || c.contains('verdura') || c.contains('legume')) {
    return const Color(0xFF4C9A4C);
  }
  if (c.contains('leguminosa')) return const Color(0xFF8A6B3F);
  if (c.contains('ovo')) return const Color(0xFFC9A227);
  if (c.contains('leite') || c.contains('lácteo') || c.contains('derivado')) {
    return const Color(0xFF6D8CC7);
  }
  if (c.contains('bebida')) return const Color(0xFF5AA9A3);
  if (c.contains('açúcar') || c.contains('doce')) return const Color(0xFFC060A0);
  if (c.contains('gordura') || c.contains('óleo')) return const Color(0xFF9B8B3F);
  if (c.contains('noz') || c.contains('semente')) return const Color(0xFF8A6B3F);
  if (c.contains('preparado')) return const Color(0xFFB07A4A);
  if (c.contains('industrializado')) return const Color(0xFF8A7A68);
  return const Color(0xFF4C7A1F);
}

/// Versão curta da categoria, para caber em uma linha nas listas.
String shortCategory(String category) {
  switch (category) {
    case 'Carnes e derivados':
      return 'Carnes';
    case 'Verduras, hortaliças e derivados':
      return 'Hortaliças';
    case 'Frutas e derivados':
      return 'Frutas';
    case 'Cereais e derivados':
      return 'Cereais';
    case 'Pescados e frutos do mar':
      return 'Pescados';
    case 'Alimentos preparados':
      return 'Preparados';
    case 'Leguminosas e derivados':
      return 'Leguminosas';
    case 'Leite e derivados':
      return 'Leite';
    case 'Produtos açucarados':
      return 'Açúcares';
    case 'Gorduras e óleos':
      return 'Gorduras';
    case 'Bebidas (alcoólicas e não alcoólicas)':
      return 'Bebidas';
    case 'Nozes e sementes':
      return 'Nozes';
    case 'Ovos e derivados':
      return 'Ovos';
    case 'Outros alimentos industrializados':
    case 'Produtos industrializados':
      return 'Industrializados';
    default:
      return category;
  }
}

/// Categorias principais para os filtros da aba Alimentos.
const kCategoryFilters = <String>[
  'Todos',
  'Cereais',
  'Carnes',
  'Frutas',
  'Leguminosas',
  'Leite',
  'Verduras',
  'Ovos',
  'Pescados',
];


/// Traduz as categorias (em inglês) do Open Food Facts para o vocabulário
/// usado no app — assim o produto ganha emoji e cor coerentes.
String categoryFromOff(String raw) {
  final c = raw.toLowerCase();
  bool has(List<String> words) => words.any(c.contains);

  if (has(['beverage', 'drink', 'juice', 'soda', 'water', 'refrigerante',
      'bebida', 'suco', 'café', 'chá', 'energético'])) {
    return 'Bebidas';
  }
  if (has(['dairy', 'milk', 'cheese', 'yogurt', 'laticín', 'leite', 'queijo',
      'iogurte', 'requeijão'])) {
    return 'Leite e derivados';
  }
  if (has(['cereal', 'bread', 'pasta', 'rice', 'flour', 'pão', 'arroz',
      'massa', 'farinha', 'aveia', 'granola'])) {
    return 'Cereais e derivados';
  }
  if (has(['meat', 'poultry', 'carne', 'frango', 'bovina', 'suíno', 'presunto',
      'salsicha'])) {
    return 'Carnes e derivados';
  }
  if (has(['fish', 'seafood', 'peixe', 'atum', 'sardinha', 'camarão'])) {
    return 'Pescados e frutos do mar';
  }
  if (has(['fruit', 'fruta'])) return 'Frutas e derivados';
  if (has(['vegetable', 'verdura', 'hortaliça', 'salada', 'legume'])) {
    return 'Verduras, hortaliças e derivados';
  }
  if (has(['chocolate', 'candy', 'sweet', 'snack', 'dessert', 'doce', 'açúcar',
      'biscoito', 'bolacha', 'spread', 'wafer', 'sorvete'])) {
    return 'Açúcares e doces';
  }
  if (has(['oil', 'fat', 'óleo', 'gordura', 'azeite', 'manteiga'])) {
    return 'Gorduras e óleos';
  }
  if (has(['nut', 'seed', 'noz', 'castanha', 'amendoim', 'semente'])) {
    return 'Nozes e sementes';
  }
  if (has(['prepared', 'meal', 'preparado', 'prato', 'pizza', 'lasanha',
      'hambúrguer'])) {
    return 'Alimentos preparados';
  }
  return 'Produtos industrializados';
}
