import 'package:flutter/material.dart';

class Meal {
  const Meal(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

const kMeals = [
  Meal('breakfast', 'Café da manhã', Icons.free_breakfast_rounded),
  Meal('lunch', 'Almoço', Icons.lunch_dining_rounded),
  Meal('dinner', 'Jantar', Icons.dinner_dining_rounded),
  Meal('snack', 'Lanches', Icons.bakery_dining_rounded),
];

String mealLabelFor(String id) =>
    kMeals.firstWhere((m) => m.id == id, orElse: () => kMeals.last).label;

Meal mealFor(String id) =>
    kMeals.firstWhere((m) => m.id == id, orElse: () => kMeals.last);

String defaultMealFor(DateTime now) {
  final hour = now.hour;
  if (hour < 11) return 'breakfast';
  if (hour < 15) return 'lunch';
  if (hour < 21) return 'dinner';
  return 'snack';
}
