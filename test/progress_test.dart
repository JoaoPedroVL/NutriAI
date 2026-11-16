import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutria/app/app.dart';
import 'package:nutria/app/providers.dart';
import 'package:nutria/data/db/database.dart';
import 'package:nutria/data/db/seed.dart';

void main() {
  testWidgets('aba Progresso mostra peso, gráficos e resumo', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    await SeedService(db).ensureSeeded();
    await db.saveUserProfile(
      UserProfileData(
        id: 1,
        sex: 'feminino',
        age: 30,
        weight: 68,
        height: 165,
        activityLevel: 'moderado',
        goal: 'perder',
        kcal: 1800,
        protein: 120,
        carbs: 200,
        fat: 55,
        updatedAt: DateTime.now(),
      ),
    );
    await db.upsertWeightLog(
      DateTime.now().subtract(const Duration(days: 3)),
      69.4,
    );
    await db.upsertWeightLog(DateTime.now(), 68.2);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const NutriaApp(),
      ),
    );

    for (var i = 0; i < 60 && find.text('Proteína').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.tap(find.text('Progresso'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Peso atual'), findsOneWidget);
    expect(find.text('Registrar peso de hoje'), findsOneWidget);
    expect(find.text('Últimos 7 dias'), findsOneWidget);
    expect(find.text('Média (7 dias)'), findsOneWidget);
    expect(find.text('Dias na meta'), findsOneWidget);

    await tester.tap(find.text('30 d'));
    await tester.pump();
    expect(find.text('Últimos 30 dias'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  });
}
