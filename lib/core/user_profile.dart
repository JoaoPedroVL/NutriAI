/// Modelo de perfil do usuário para onboarding.
class UserProfile {
  const UserProfile({
    this.id,
    this.sex,
    this.age,
    this.weight,
    this.height,
    this.activityLevel,
    this.goal,
    this.kcal,
    this.protein,
    this.carbs,
    this.fat,
    this.updatedAt,
  });

  final int? id;
  final String? sex; // 'masculino' | 'feminino'
  final int? age;
  final double? weight; // kg
  final int? height; // cm
  final String? activityLevel; // 'sedentario' | 'leve' | 'moderado' | 'intenso'
  final String? goal; // 'perder' | 'manter' | 'ganhar'
  final double? kcal;
  final double? protein; // g
  final double? carbs; // g
  final double? fat; // g
  final DateTime? updatedAt;

  UserProfile copyWith({
    int? id,
    String? sex,
    int? age,
    double? weight,
    int? height,
    String? activityLevel,
    String? goal,
    double? kcal,
    double? protein,
    double? carbs,
    double? fat,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      sex: sex ?? this.sex,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      activityLevel: activityLevel ?? this.activityLevel,
      goal: goal ?? this.goal,
      kcal: kcal ?? this.kcal,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isComplete =>
      sex != null &&
      age != null &&
      weight != null &&
      height != null &&
      activityLevel != null &&
      goal != null &&
      kcal != null;
}

/// Nível de atividade física.
enum ActivityLevel {
  sedentario('Sedentário', 'Pouco ou nenhum exercício', 1.2),
  leve('Leve', 'Exercício leve 1-3 dias/semana', 1.375),
  moderado('Moderado', 'Exercício moderado 3-5 dias/semana', 1.55),
  intenso('Intenso', 'Exercício intenso 6-7 dias/semana', 1.725);

  const ActivityLevel(this.label, this.description, this.factor);
  final String label;
  final String description;
  final double factor;

  static ActivityLevel fromString(String value) {
    return ActivityLevel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ActivityLevel.sedentario,
    );
  }
}

/// Objetivo do usuário.
enum Goal {
  perder('Perder peso', 'Déficit calórico para emagrecer', -500),
  manter('Manter peso', 'Calorias de manutenção', 0),
  ganhar('Ganhar massa', 'Superávit para hipertrofia', 300);

  const Goal(this.label, this.description, this.adjustment);
  final String label;
  final String description;
  final int adjustment;

  static Goal fromString(String value) {
    return Goal.values.firstWhere(
      (e) => e.name == value,
      orElse: () => Goal.manter,
    );
  }
}

/// Calculadora de metas usando Mifflin-St Jeor.
class GoalCalculator {
  /// Calcula TMB (Taxa Metabólica Basal) - Mifflin-St Jeor.
  static double calculateBMR({
    required String sex,
    required int age,
    required double weight, // kg
    required int height, // cm
  }) {
    if (sex == 'masculino') {
      return (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      return (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }
  }

  /// Calcula TDEE (Gasto Energético Total Diário).
  static double calculateTDEE({
    required double bmr,
    required ActivityLevel activityLevel,
  }) {
    return bmr * activityLevel.factor;
  }

  /// Calcula meta calórica final com ajuste do objetivo.
  static double calculateGoalKcal({
    required double tdee,
    required Goal goal,
  }) {
    return (tdee + goal.adjustment).roundToDouble();
  }

  /// Distribui macros conforme objetivo.
  static NutritionGoals distributeMacros({
    required double kcal,
    required Goal goal,
    required double weight, // kg
  }) {
    double proteinPerKg;
    double fatPercent;
    
    switch (goal) {
      case Goal.perder:
        proteinPerKg = 2.0; // 2g/kg para preservar massa magra
        fatPercent = 0.25;
        break;
      case Goal.manter:
        proteinPerKg = 1.6;
        fatPercent = 0.30;
        break;
      case Goal.ganhar:
        proteinPerKg = 1.8;
        fatPercent = 0.25;
        break;
    }

    final protein = (weight * proteinPerKg).roundToDouble();
    final fat = ((kcal * fatPercent) / 9).roundToDouble(); // 9 kcal/g gordura
    final carbs = ((kcal - (protein * 4) - (fat * 9)) / 4).roundToDouble(); // 4 kcal/g

    return NutritionGoals(
      kcal: kcal,
      protein: protein.clamp(0, kcal / 4),
      carbs: carbs.clamp(0, kcal / 4),
      fat: fat.clamp(0, kcal / 9),
    );
  }

  /// Pipeline completo: calcula tudo de uma vez.
  static NutritionGoals calculateAll({
    required String sex,
    required int age,
    required double weight,
    required int height,
    required ActivityLevel activityLevel,
    required Goal goal,
  }) {
    final bmr = calculateBMR(sex: sex, age: age, weight: weight, height: height);
    final tdee = calculateTDEE(bmr: bmr, activityLevel: activityLevel);
    final goalKcal = calculateGoalKcal(tdee: tdee, goal: goal);
    return distributeMacros(kcal: goalKcal, goal: goal, weight: weight);
  }
}

/// Metas nutricionais.
class NutritionGoals {
  const NutritionGoals({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  static const defaults = NutritionGoals(
    kcal: 2000,
    protein: 150,
    carbs: 250,
    fat: 60,
  );

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  NutritionGoals copyWith({
    double? kcal,
    double? protein,
    double? carbs,
    double? fat,
  }) {
    return NutritionGoals(
      kcal: kcal ?? this.kcal,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
    );
  }

  double get proteinPercent => (protein * 4 / kcal * 100).clamp(0, 100);
  double get carbsPercent => (carbs * 4 / kcal * 100).clamp(0, 100);
  double get fatPercent => (fat * 9 / kcal * 100).clamp(0, 100);

  Map<String, dynamic> toJson() {
    return {
      'kcal': kcal,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  static NutritionGoals fromJson(Map<String, dynamic> json) {
    return NutritionGoals(
      kcal: (json['kcal'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
    );
  }
}