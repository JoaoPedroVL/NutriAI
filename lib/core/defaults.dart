/// Valores padrão e limites usados em todo o app.
///
/// Ficam num só lugar para que seed, repositórios e UI não divirjam.
library;

const double kDefaultKcal = 2000;
const double kDefaultProtein = 150;
const double kDefaultCarbs = 250;
const double kDefaultFat = 60;

/// Maior quantidade aceita num único lançamento (10 kg / 10 L).
const double kMaxGrams = 10000;

/// Maiores valores plausíveis por 100 g/ml, usados para barrar dados
/// corrompidos vindos de fontes externas.
const double kMaxKcalPer100 = 900;
const double kMaxMacroPer100 = 100;
const double kMaxSodiumMgPer100 = 50000;

/// Maior porção declarada aceita de um produto (10 kg / 10 L).
const double kMaxServingGrams = 10000;
