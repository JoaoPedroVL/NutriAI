/// Normaliza texto para busca: minúsculas, sem acentos e sem pontuação.
///
/// Ex.: "Feijão, carioca, cozido" -> "feijao carioca cozido"
String normalizeForSearch(String input) {
  const accented = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const plain = 'aaaaaeeeeiiiiooooouuuucn';

  var out = input.toLowerCase();
  for (var i = 0; i < accented.length; i++) {
    out = out.replaceAll(accented[i], plain[i]);
  }
  return out.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// Chave estável de um dia (sem hora), usada em rascunhos e consultas.
String dayKey(DateTime date) {
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '${date.year}-$m-$d';
}

/// Zera horas/minutos/segundos.
DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

/// Primeiro instante do dia seguinte, no calendário civil local.
///
/// Diferente de `start.add(Duration(days: 1))`, funciona em dias de horário
/// de verão (23 h) e de 25 h.
DateTime nextDay(DateTime date) =>
    DateTime(date.year, date.month, date.day + 1);

/// Mesmo dia do calendário.
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

const _monthsShort = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

/// "Hoje", "Ontem", "Amanhã" ou "11 de nov".
String prettyDate(DateTime date) {
  final today = startOfDay(DateTime.now());
  // Datas em UTC só para contar dias civis, sem sofrer com DST.
  final a = DateTime.utc(date.year, date.month, date.day);
  final b = DateTime.utc(today.year, today.month, today.day);
  final diff = a.difference(b).inDays;
  if (diff == 0) return 'Hoje';
  if (diff == -1) return 'Ontem';
  if (diff == 1) return 'Amanhã';
  return '${date.day} de ${_monthsShort[date.month - 1]}';
}

/// 100.0 -> "100"; 12.5 -> "12,5".
String formatGrams(double grams) {
  final rounded = grams.roundToDouble();
  final text = (grams - rounded).abs() < 0.05
      ? rounded.toStringAsFixed(0)
      : grams.toStringAsFixed(1);
  return text.replaceAll('.', ',');
}

/// Lê número digitado em português ou inglês.
///
/// Aceita "12,5", "12.5", "1.000" (milhar) e "1.000,50". Devolve `null` para
/// vazio, texto inválido, `NaN` ou `Infinity`.
double? parseNumber(String raw) {
  var text = raw.trim().replaceAll(RegExp(r'\s'), '');
  if (text.isEmpty) return null;

  final hasComma = text.contains(',');
  final hasDot = text.contains('.');

  if (hasComma && hasDot) {
    // Formato brasileiro: ponto de milhar, vírgula decimal.
    text = text.replaceAll('.', '').replaceAll(',', '.');
  } else if (hasComma) {
    text = text.replaceAll(',', '.');
  } else if (hasDot && RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(text)) {
    // "1.000" / "2.500" são milhares, não decimais.
    text = text.replaceAll('.', '');
  }

  final value = double.tryParse(text);
  if (value == null || !value.isFinite) return null;
  return value;
}

/// Valida o dígito verificador de EAN-8, UPC-A, EAN-13 e ITF-14 (GTIN).
bool isValidGtin(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 8 &&
      digits.length != 12 &&
      digits.length != 13 &&
      digits.length != 14) {
    return false;
  }

  var sum = 0;
  var weight = 3;
  for (var i = digits.length - 2; i >= 0; i--) {
    sum += int.parse(digits[i]) * weight;
    weight = weight == 3 ? 1 : 3;
  }
  final check = (10 - (sum % 10)) % 10;
  return check == int.parse(digits[digits.length - 1]);
}

/// Nome amigável da fonte do alimento.
String sourceLabel(String source) {
  switch (source.toLowerCase()) {
    case 'taco':
      return 'TACO 4ª ed.';
    case 'tbca':
      return 'TBCA';
    case 'off':
      return 'Open Food Facts';
    case 'custom':
      return 'Personalizado';
    case 'ai':
      return 'Estimado por IA';
    default:
      return source.toUpperCase();
  }
}

/// Unidade de exibição: bebidas em ml, sólidos em g.
///
/// Internamente tudo continua em gramas; é só a leitura que fica natural.
String unitForCategory(String category) {
  final c = category.toLowerCase();
  if (c.contains('bebida') || c.contains('suco') || c.contains('líquido')) {
    return 'ml';
  }
  return 'g';
}

/// Rótulo de medida caseira sem repetir um peso que já está no texto.
String servingDisplayLabel(String label, double grams, String category) {
  final hasSize = RegExp(
    r'\d+(?:[.,]\d+)?\s*(g|ml|kg|l)\b',
    caseSensitive: false,
  ).hasMatch(label);
  final unit = unitForCategory(category);
  return hasSize ? label : '$label (${formatGrams(grams)} $unit)';
}
