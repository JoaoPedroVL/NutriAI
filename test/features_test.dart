import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutria/data/db/database.dart';
import 'package:nutria/data/db/seed.dart';
import 'package:nutria/data/repositories/diary_repository.dart';
import 'package:nutria/data/repositories/favorite_repository.dart';
import 'package:nutria/data/repositories/recent_food_repository.dart';
import 'package:nutria/data/repositories/saved_meal_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await SeedService(db).ensureSeeded();
  });

  tearDown(() async {
    await db.close();
  });

  test('copiar de ontem respeita refeição e dia', () async {
    final diary = DiaryRepository(db);
    final food = (await db.select(db.foods).get()).first;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final today = DateTime.now();

    await diary.addEntry(
      day: yesterday,
      meal: 'lunch',
      food: food,
      grams: 100,
    );
    await diary.addEntry(
      day: yesterday,
      meal: 'dinner',
      food: food,
      grams: 50,
    );

    final copied = await diary.copyMeal(
      fromDay: yesterday,
      toDay: today,
      meal: 'lunch',
    );

    expect(copied, 1);
    final todayEntries = await diary.watchDay(today).first;
    expect(todayEntries, hasLength(1));
    expect(todayEntries.single.meal, 'lunch');
    expect(todayEntries.single.foodName, food.name);
  });

  test('refeição salva é reaplicada com os macros originais', () async {
    final diary = DiaryRepository(db);
    final saved = SavedMealRepository(db);
    final food = (await db.select(db.foods).get()).first;

    await diary.addEntry(
      day: DateTime.now(),
      meal: 'breakfast',
      food: food,
      grams: 120,
    );
    final entries = await diary.watchDay(DateTime.now()).first;

    final id = await saved.saveFromEntries(
      name: 'Café padrão',
      meal: 'breakfast',
      entries: entries,
    );
    final applied = await saved.applyToDay(
      savedMealId: id,
      day: DateTime.now().subtract(const Duration(days: 4)),
    );

    expect(applied, 1);
    final newDay = await diary
        .watchDay(DateTime.now().subtract(const Duration(days: 4)))
        .first;
    expect(newDay, hasLength(1));
    expect(newDay.single.kcal, closeTo(entries.single.kcal, 0.001));
    expect(newDay.single.grams, 120);
  });

  test('favoritos e recentes são persistidos', () async {
    final favorites = FavoriteRepository(db);
    final recents = RecentFoodRepository(db);
    final food = (await db.select(db.foods).get()).first;

    expect(await favorites.isFavorite(food.id), isFalse);
    await favorites.toggle(food.id);
    expect(await favorites.isFavorite(food.id), isTrue);
    expect(await favorites.getAll(), hasLength(1));

    await favorites.toggle(food.id);
    expect(await favorites.isFavorite(food.id), isFalse);

    await recents.add(food.id);
    await recents.add(food.id);
    final list = await recents.getAll();
    expect(list, hasLength(1));
    expect(list.single.foodId, food.id);
  });

  test('perfil salvo alimenta metas calculadas', () async {
    await db.saveUserProfile(
      UserProfileData(
        id: 1,
        sex: 'feminino',
        age: 28,
        weight: 62,
        height: 165,
        activityLevel: 'leve',
        goal: 'perder',
        kcal: 1700,
        protein: 124,
        carbs: 180,
        fat: 55,
        updatedAt: DateTime.now(),
      ),
    );

    final profile = await db.getUserProfile();
    expect(profile?.kcal, 1700);
    expect(profile?.goal, 'perder');
  });

  test('peso do dia é substituído em vez de duplicado', () async {
    final today = DateTime.now();
    await db.upsertWeightLog(today, 70.2);
    await db.upsertWeightLog(today, 69.8);

    final logs = await db.getWeightLogs();
    expect(logs, hasLength(1));
    expect(logs.single.weight, 69.8);
  });
}
