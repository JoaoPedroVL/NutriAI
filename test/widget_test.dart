import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutria/app/app.dart';
import 'package:nutria/app/providers.dart';
import 'package:nutria/data/db/database.dart';
import 'package:nutria/data/db/seed.dart';

void main() {
  testWidgets('abre no diário com metas e refeições', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 1500 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    await SeedService(db).ensureSeeded();
    await db.saveUserProfile(
      UserProfileData(
        id: 1,
        sex: 'masculino',
        age: 30,
        weight: 75,
        height: 175,
        activityLevel: 'moderado',
        goal: 'manter',
        kcal: 2500,
        protein: 150,
        carbs: 250,
        fat: 60,
        updatedAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const NutriaApp(),
      ),
    );

    for (var i = 0; i < 60 && find.text('Proteína').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Nutria'), findsOneWidget);
    expect(find.text('Proteína'), findsOneWidget);
    expect(find.text('Almoço'), findsOneWidget);
    expect(find.text('Adicionar'), findsOneWidget);

    // Desmonta a árvore e deixa o drift fechar os streams (timer de 0 ms).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  });
}
