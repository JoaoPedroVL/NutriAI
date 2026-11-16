import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/text.dart';
import '../data/db/database.dart';
import '../data/db/seed.dart';
import '../data/repositories/diary_repository.dart';
import '../data/repositories/draft_repository.dart';
import '../data/repositories/food_repository.dart';
import '../data/repositories/goals_repository.dart';
import '../data/repositories/favorite_repository.dart';
import '../data/repositories/recent_food_repository.dart';
import '../data/repositories/saved_meal_repository.dart';
import '../data/repositories/user_profile_repository.dart';
import '../data/repositories/weight_repository.dart';
import '../data/repositories/water_repository.dart';
import '../data/remote/open_food_facts.dart';
import '../data/services/backup_service.dart';
import '../data/services/notification_service.dart';

export '../data/providers/theme_provider.dart' show themeModeProvider, ThemeModeNotifier;

/// Banco local (SQLite). Fonte da verdade no aparelho.
final databaseProvider = Provider<AppDatabase>((ref) {
  try {
    final database = AppDatabase();
    ref.onDispose(database.close);
    return database;
  } catch (e, st) {
    debugPrint('[Nutria] Erro ao criar AppDatabase: $e');
    debugPrint('[Nutria] Stack: $st');
    rethrow;
  }
});

/// Provider que expõe erro de inicialização do banco para a UI poder mostrar detalhes.
final databaseInitErrorProvider = Provider<AsyncError?>((ref) {
  ref.watch(databaseProvider);
  // Força a abertura do banco acessando uma query simples.
  return null; // O erro real vem do seedProvider.
});

/// Garante a importação da TACO antes da primeira tela.
final seedProvider = FutureProvider<void>((ref) async {
  try {
    await SeedService(ref.watch(databaseProvider)).ensureSeeded();
  } catch (e, st) {
    debugPrint('[Nutria] Erro no seed/abertura do banco: $e');
    debugPrint('[Nutria] Stack: $st');
    rethrow;
  }
});

final foodRepositoryProvider = Provider<FoodRepository>(
  (ref) => FoodRepository(ref.watch(databaseProvider)),
);

final diaryRepositoryProvider = Provider<DiaryRepository>(
  (ref) => DiaryRepository(ref.watch(databaseProvider)),
);

final draftRepositoryProvider = Provider<DraftRepository>(
  (ref) => DraftRepository(ref.watch(databaseProvider)),
);

final goalsRepositoryProvider = Provider<GoalsRepository>(
  (ref) => GoalsRepository(ref.watch(databaseProvider)),
);

final offServiceProvider = Provider<OpenFoodFactsService>(
  (ref) => OpenFoodFactsService(),
);

/// Novos repositórios
final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => UserProfileRepository(ref.watch(databaseProvider)),
);

final weightRepositoryProvider = Provider<WeightRepository>(
  (ref) => WeightRepository(ref.watch(databaseProvider)),
);

final savedMealRepositoryProvider = Provider<SavedMealRepository>(
  (ref) => SavedMealRepository(ref.watch(databaseProvider)),
);

final favoriteRepositoryProvider = Provider<FavoriteRepository>(
  (ref) => FavoriteRepository(ref.watch(databaseProvider)),
);

final recentFoodRepositoryProvider = Provider<RecentFoodRepository>(
  (ref) => RecentFoodRepository(ref.watch(databaseProvider)),
);

/// Emite um valor imediatamente e depois a cada [every].
///
/// O Drift já oferece `.watch()` para consultas reativas; este helper cobre as
/// consultas que hoje são `Future` (perfil, peso, favoritos etc.) sem deixar a
/// primeira tela presa em `loading`.
Stream<T> _poll<T>(
  Future<T> Function() load, {
  Duration every = const Duration(seconds: 2),
}) async* {
  yield await load();
  yield* Stream<void>.periodic(every).asyncMap((_) => load());
}

/// Perfil do usuário (onboarding) — reativo.
final userProfileProvider = StreamProvider<UserProfileData?>((ref) {
  return _poll(() => ref.watch(databaseProvider).getUserProfile());
});

/// Metas calculadas do usuário (vêm do perfil se completo, senão defaults).
final calculatedGoalsProvider = Provider<AsyncValue<NutritionGoals>>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.whenData((profile) {
    if (profile != null &&
        profile.kcal != null &&
        profile.protein != null &&
        profile.carbs != null &&
        profile.fat != null) {
      return NutritionGoals(
        kcal: profile.kcal!,
        protein: profile.protein!,
        carbs: profile.carbs!,
        fat: profile.fat!,
      );
    }
    return NutritionGoals.defaults;
  });
});

/// Histórico de peso.
final weightLogsProvider = StreamProvider<List<WeightLog>>((ref) {
  final repo = ref.watch(weightRepositoryProvider);
  return _poll(() => repo.getAll());
});

/// Peso de hoje.
final todayWeightProvider = FutureProvider<double?>((ref) async {
  final repo = ref.watch(weightRepositoryProvider);
  final log = await repo.getToday();
  return log?.weight;
});

/// Refeições salvas.
final savedMealsProvider = StreamProvider<List<SavedMeal>>((ref) {
  final repo = ref.watch(savedMealRepositoryProvider);
  return _poll(() => repo.getAll());
});

/// Favoritos.
final favoritesProvider = StreamProvider<List<Favorite>>((ref) {
  final repo = ref.watch(favoriteRepositoryProvider);
  return _poll(() => repo.getAll());
});

/// Verifica se um alimento é favorito.
final isFavoriteProvider = Provider.family<Future<bool>, int>((ref, foodId) {
  final repo = ref.watch(favoriteRepositoryProvider);
  return repo.isFavorite(foodId);
});

/// Alimentos recentes.
final recentFoodsProvider = StreamProvider<List<RecentFood>>((ref) {
  final repo = ref.watch(recentFoodRepositoryProvider);
  return _poll(() => repo.getAll(limit: 10));
});

/// Recentes resolvidos para [Food] (para exibir nome/categoria/macros).
final recentFoodsDetailedProvider = FutureProvider<List<Food>>((ref) async {
  final recents = ref.watch(recentFoodsProvider).value ?? const <RecentFood>[];
  final repo = ref.watch(foodRepositoryProvider);
  final foods = <Food>[];
  for (final recent in recents) {
    final food = await repo.byId(recent.foodId);
    if (food != null) foods.add(food);
  }
  return foods;
});

/// Favoritos resolvidos para [Food].
final favoriteFoodsProvider = FutureProvider<List<Food>>((ref) async {
  final favorites = ref.watch(favoritesProvider).value ?? const <Favorite>[];
  final repo = ref.watch(foodRepositoryProvider);
  final foods = <Food>[];
  for (final favorite in favorites) {
    final food = await repo.byId(favorite.foodId);
    if (food != null) foods.add(food);
  }
  return foods;
});

/// Entradas dos últimos 30 dias (gráficos da aba Progresso).
final progressEntriesProvider =
    StreamProvider<List<DiaryEntry>>((ref) {
  final today = startOfDay(DateTime.now());
  final from = today.subtract(const Duration(days: 29));
  return ref.watch(diaryRepositoryProvider).watchRange(from, nextDay(today));
});

/// Dia selecionado no diário.
class SelectedDate extends Notifier<DateTime> {
  @override
  DateTime build() {
    // O ciclo de vida do app é observado pelo HomeShell (abaixo) que chama
    // refreshToday() ao voltar do background.
    return startOfDay(DateTime.now());
  }

  void select(DateTime date) => state = startOfDay(date);

  void shift(int days) =>
      state = DateTime(state.year, state.month, state.day + days);

  /// Recalcula "hoje" (útil ao voltar do background).
  void refreshToday() => state = startOfDay(DateTime.now());
}

final selectedDateProvider =
    NotifierProvider<SelectedDate, DateTime>(SelectedDate.new);

/// Registros do dia selecionado, reativos ao banco local.
final dayEntriesProvider = StreamProvider<List<DiaryEntry>>((ref) {
  final day = ref.watch(selectedDateProvider);
  return ref.watch(diaryRepositoryProvider).watchDay(day);
});

/// Metas diárias — usa as metas calculadas do perfil se disponíveis.
final goalsProvider = StreamProvider<NutritionGoals>((ref) {
  // Tenta usar metas calculadas do perfil
  final calculated = ref.watch(calculatedGoalsProvider);
  if (calculated is AsyncData<NutritionGoals>) {
    return Stream.value(calculated.value);
  }
  // Fallback para metas salvas no banco (Goals table)
  return ref.watch(goalsRepositoryProvider).watch();
});

/// Repositório de água.
final waterRepositoryProvider = Provider<WaterRepository>(
  (ref) => WaterRepository(ref.watch(databaseProvider)),
);

/// Consumo de água de hoje.
final todayWaterProvider = StreamProvider<double>((ref) {
  final repo = ref.watch(waterRepositoryProvider);
  return _poll(() => repo.getTodayAmount());
});

/// Registros de água de hoje (mais recentes primeiro), usados para desfazer.
final todayWaterLogsProvider = StreamProvider<List<WaterLog>>((ref) {
  final repo = ref.watch(waterRepositoryProvider);
  return _poll(() => repo.getTodayLogs());
});

/// Logs de água (últimos 30 dias para gráficos).
final waterLogsProvider = StreamProvider<List<WaterLog>>((ref) {
  final repo = ref.watch(waterRepositoryProvider);
  return _poll(() => repo.getRange(
    startOfDay(DateTime.now()).subtract(const Duration(days: 29)),
    DateTime.now(),
  ));
});

/// Serviço de backup.
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    ref.watch(databaseProvider),
    ref.watch(diaryRepositoryProvider),
    ref.watch(savedMealRepositoryProvider),
    ref.watch(userProfileRepositoryProvider),
    ref.watch(weightRepositoryProvider),
  );
});

/// Serviço de notificações.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});