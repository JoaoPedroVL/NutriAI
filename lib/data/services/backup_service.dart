import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/user_profile.dart';
import '../db/database.dart';
import '../repositories/diary_repository.dart';
import '../repositories/saved_meal_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../repositories/weight_repository.dart';

/// Serviço de backup/exportação/importação de dados.
///
/// Exporta todo o banco para JSON (estrutura compatível com importação).
/// Importa substituindo os dados atuais (transação atômica).
class BackupService {
  BackupService(this._db, this._diaryRepo, this._savedMealRepo,
      this._userProfileRepo, this._weightRepo);

  final AppDatabase _db;
  final DiaryRepository _diaryRepo;
  final SavedMealRepository _savedMealRepo;
  final UserProfileRepository _userProfileRepo;
  final WeightRepository _weightRepo;

  /// Exporta todos os dados para um arquivo JSON e compartilha (Share Sheet).
  Future<void> exportAndShare() async {
    final jsonString = await exportToJson();
    final fileName = 'nutria_backup_${_dateStamp()}.json';

    // Salva em cache temporário e compartilha
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(jsonString);

    await Share.shareXFiles([XFile(file.path)], text: 'Backup do Nutria');
  }

  /// Exporta todos os dados para string JSON.
  Future<String> exportToJson() async {
    final profile = await _userProfileRepo.getProfile();
    final goals = await _diaryRepo.getGoals();
    final entries = await _diaryRepo.getAllEntries();
    final weightLogs = await _weightRepo.getAllLogs();
    final savedMeals = await _savedMealRepo.getAll();
    final favorites = await _db.getFavorites();
    final recentFoods = await _db.getRecentFoods(limit: 100);
    final waterLogs = await _db.getWaterLogs(limit: 1000);
    final customFoods = await _db.getCustomFoods();

    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': profile?.toJson(),
      'goals': goals?.toJson(),
      'entries': entries.map((e) => e.toJson()).toList(),
      'weightLogs': weightLogs.map((w) => w.toJson()).toList(),
      'savedMeals': savedMeals.map((s) => s.toJson()).toList(),
      'favorites': favorites.map((f) => f.toJson()).toList(),
      'recentFoods': recentFoods.map((r) => r.toJson()).toList(),
      'waterLogs': waterLogs.map((w) => w.toJson()).toList(),
      'customFoods': customFoods.map((f) => f.toJson()).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  /// Importa dados de um arquivo JSON (seletor de arquivo).
  Future<void> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'Selecione o arquivo de backup',
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    String jsonString;

    if (file.bytes != null) {
      jsonString = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      jsonString = await File(file.path!).readAsString();
    } else {
      throw Exception('Arquivo inválido');
    }

    await importFromJson(jsonString);
  }

  /// Importa dados de string JSON (transação atômica).
  Future<void> importFromJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final version = data['version'] as int? ?? 1;

    if (version > 1) {
      throw Exception('Versão de backup não suportada: $version');
    }

    await _db.transaction(() async {
      // Limpa dados atuais (exceto catálogo de alimentos padrão)
      await _clearUserData();

      // Restaura perfil
      if (data['profile'] != null) {
        await _userProfileRepo.saveProfile(
          UserProfileData.fromJson(data['profile'] as Map<String, dynamic>),
        );
      }

      // Restaura metas
      if (data['goals'] != null) {
        await _diaryRepo.setGoals(
          NutritionGoals.fromJson(data['goals'] as Map<String, dynamic>),
        );
      }

      // Restaura entradas do diário
      final entries = (data['entries'] as List<dynamic>?)
              ?.map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      for (final entry in entries) {
        await _diaryRepo.insertEntry(entry);
      }

      // Restaura logs de peso
      final weightLogs = (data['weightLogs'] as List<dynamic>?)
              ?.map((w) => WeightLog.fromJson(w as Map<String, dynamic>))
              .toList() ??
          [];
      for (final log in weightLogs) {
        await _weightRepo.saveWeightLog(log);
      }

      // Restaura refeições salvas
      final savedMeals = (data['savedMeals'] as List<dynamic>?)
              ?.map((s) => SavedMeal.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [];
      for (final meal in savedMeals) {
        await _savedMealRepo.insert(meal);
      }

      // Restaura favoritos
      final favorites = (data['favorites'] as List<dynamic>?)
              ?.map((f) => Favorite.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [];
      for (final fav in favorites) {
        await _db.into(_db.favorites).insert(
          FavoritesCompanion.insert(
            foodId: Value(fav.foodId),
            createdAt: Value(fav.createdAt),
          ),
        );
      }

      // Restaura recentes
      final recentFoods = (data['recentFoods'] as List<dynamic>?)
              ?.map((r) => RecentFood.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [];
      for (final recent in recentFoods) {
        await _db.into(_db.recentFoods).insertOnConflictUpdate(
          RecentFoodsCompanion.insert(
            foodId: Value(recent.foodId),
            lastUsedAt: Value(recent.lastUsedAt),
          ),
        );
      }

      // Restaura logs de água
      final waterLogs = (data['waterLogs'] as List<dynamic>?)
              ?.map((w) => WaterLog.fromJson(w as Map<String, dynamic>))
              .toList() ??
          [];
      for (final log in waterLogs) {
        await _db.into(_db.waterLogs).insert(
          WaterLogsCompanion.insert(
            id: Value(log.id),
            day: log.day,
            amountMl: log.amountMl,
            createdAt: Value(log.createdAt),
          ),
        );
      }

      // Restaura alimentos customizados
      final customFoods = (data['customFoods'] as List<dynamic>?)
              ?.map((f) => Food.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [];
      for (final food in customFoods) {
        await _db.into(_db.foods).insertOnConflictUpdate(
          FoodsCompanion.insert(
            id: Value(food.id),
            name: food.name,
            searchKey: food.searchKey,
            category: Value(food.category),
            kcal100: food.kcal100,
            protein100: food.protein100,
            carbs100: food.carbs100,
            fat100: food.fat100,
            fiber100: food.fiber100,
            sodium100: food.sodium100,
            barcode: Value(food.barcode),
            source: Value(food.source),
            isCustom: Value(true),
            createdAt: Value(food.createdAt),
          ),
        );
      }
    });
  }

  /// Remove todos os dados do usuário (mantém catálogo padrão).
  Future<void> _clearUserData() async {
    await _db.delete(_db.diaryEntries).go();
    await _db.delete(_db.weightLogs).go();
    await _db.delete(_db.savedMealItems).go();
    await _db.delete(_db.savedMeals).go();
    await _db.delete(_db.favorites).go();
    await _db.delete(_db.recentFoods).go();
    await _db.delete(_db.waterLogs).go();
    await _db.delete(_db.userProfiles).go();
    await _db.delete(_db.goals).go();
    // Alimentos customizados (source = 'custom')
    await _db.customStatement('DELETE FROM foods WHERE source = ?', ['custom']);
  }

  String _dateStamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }
}