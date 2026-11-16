import 'package:drift/drift.dart';

import '../db/database.dart';
import '../../core/user_profile.dart' as core;

class UserProfileRepository {
  UserProfileRepository(this._db);

  final AppDatabase _db;

  Future<UserProfileData?> get() async {
    return await _db.getUserProfile();
  }

  Future<void> save(UserProfileData profile) async {
    await _db.saveUserProfile(profile);
  }

  Future<void> updatePartial({
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
  }) async {
    final current = await get();
    if (current == null) return;

    final updated = current.copyWith(
      sex: _value(sex),
      age: _value(age),
      weight: _value(weight),
      height: _value(height),
      activityLevel: _value(activityLevel),
      goal: _value(goal),
      kcal: _value(kcal),
      protein: _value(protein),
      carbs: _value(carbs),
      fat: _value(fat),
      updatedAt: DateTime.now(),
    );
    await _db.saveUserProfile(updated);
  }

  static Value<T> _value<T>(T? value) =>
      value == null ? const Value.absent() : Value(value);

  Future<void> delete() async {
    await (_db.delete(_db.userProfiles)..where((u) => u.id.equals(1))).go();
  }

  Future<UserProfileData?> getProfile() async {
    return get();
  }

  Future<void> saveProfile(UserProfileData profile) async {
    await save(profile);
  }
}

extension UserProfileDataExtension on UserProfileData {
  core.UserProfile toCore() {
    return core.UserProfile(
      sex: sex ?? '',
      age: age ?? 0,
      weight: weight ?? 0,
      height: height ?? 0,
      activityLevel: activityLevel ?? '',
      goal: goal ?? '',
      kcal: kcal ?? 0,
      protein: protein ?? 0,
      carbs: carbs ?? 0,
      fat: fat ?? 0,
    );
  }
}