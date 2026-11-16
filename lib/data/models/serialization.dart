/// Extensões de serialização JSON para as classes de dados do Drift.
///
/// Mantém a serialização fora das classes geradas para não conflitar com
/// o build_runner.
library;

import '../../core/user_profile.dart';
import '../db/database.dart';

// ============ UserProfileData ============

extension UserProfileDataJson on UserProfileData {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sex': sex,
      'age': age,
      'weight': weight,
      'height': height,
      'activityLevel': activityLevel,
      'goal': goal,
      'kcal': kcal,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static UserProfileData fromJson(Map<String, dynamic> json) {
    return UserProfileData(
      id: json['id'] as int,
      sex: json['sex'] as String?,
      age: json['age'] as int?,
      weight: (json['weight'] as num?)?.toDouble(),
      height: json['height'] as int?,
      activityLevel: json['activityLevel'] as String?,
      goal: json['goal'] as String?,
      kcal: (json['kcal'] as num?)?.toDouble(),
      protein: (json['protein'] as num?)?.toDouble(),
      carbs: (json['carbs'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

// ============ NutritionGoals (core) ============

extension NutritionGoalsJson on NutritionGoals {
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

// ============ DiaryEntry ============

extension DiaryEntryJson on DiaryEntry {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'day': day.toIso8601String(),
      'meal': meal,
      'foodId': foodId,
      'foodName': foodName,
      'category': category,
      'grams': grams,
      'kcal': kcal,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'syncId': syncId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static DiaryEntry fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'] as int,
      day: DateTime.parse(json['day'] as String),
      meal: json['meal'] as String,
      foodId: json['foodId'] as int?,
      foodName: json['foodName'] as String,
      category: json['category'] as String,
      grams: (json['grams'] as num).toDouble(),
      kcal: (json['kcal'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      syncId: json['syncId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

// ============ WeightLog ============

extension WeightLogJson on WeightLog {
  Map<String, dynamic> toJson() {
    return {
      'day': day.toIso8601String(),
      'weight': weight,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static WeightLog fromJson(Map<String, dynamic> json) {
    return WeightLog(
      day: DateTime.parse(json['day'] as String),
      weight: (json['weight'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

// ============ SavedMeal ============

extension SavedMealJson on SavedMeal {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'meal': meal,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static SavedMeal fromJson(Map<String, dynamic> json) {
    return SavedMeal(
      id: json['id'] as int,
      name: json['name'] as String,
      meal: json['meal'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

// ============ Favorite ============

extension FavoriteJson on Favorite {
  Map<String, dynamic> toJson() {
    return {
      'foodId': foodId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static Favorite fromJson(Map<String, dynamic> json) {
    return Favorite(
      foodId: json['foodId'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

// ============ RecentFood ============

extension RecentFoodJson on RecentFood {
  Map<String, dynamic> toJson() {
    return {
      'foodId': foodId,
      'lastUsedAt': lastUsedAt.toIso8601String(),
    };
  }

  static RecentFood fromJson(Map<String, dynamic> json) {
    return RecentFood(
      foodId: json['foodId'] as int,
      lastUsedAt: DateTime.parse(json['lastUsedAt'] as String),
    );
  }
}

// ============ WaterLog ============

extension WaterLogJson on WaterLog {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'day': day.toIso8601String(),
      'amountMl': amountMl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static WaterLog fromJson(Map<String, dynamic> json) {
    return WaterLog(
      id: json['id'] as int,
      day: DateTime.parse(json['day'] as String),
      amountMl: (json['amountMl'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

// ============ Food ============

extension FoodJson on Food {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'searchKey': searchKey,
      'category': category,
      'kcal100': kcal100,
      'protein100': protein100,
      'carbs100': carbs100,
      'fat100': fat100,
      'fiber100': fiber100,
      'sodium100': sodium100,
      'barcode': barcode,
      'source': source,
      'isCustom': isCustom,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static Food fromJson(Map<String, dynamic> json) {
    return Food(
      id: json['id'] as int,
      name: json['name'] as String,
      searchKey: json['searchKey'] as String,
      category: json['category'] as String,
      kcal100: (json['kcal100'] as num).toDouble(),
      protein100: (json['protein100'] as num).toDouble(),
      carbs100: (json['carbs100'] as num).toDouble(),
      fat100: (json['fat100'] as num).toDouble(),
      fiber100: (json['fiber100'] as num).toDouble(),
      sodium100: (json['sodium100'] as num).toDouble(),
      barcode: json['barcode'] as String?,
      source: json['source'] as String,
      isCustom: json['isCustom'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}