import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutria/app/app.dart';
import 'package:nutria/app/providers.dart';
import 'package:nutria/data/db/database.dart';
import 'package:nutria/data/db/seed.dart';

void main() {
  testWidgets('primeira abertura pede onboarding e salva o perfil',
      (tester) async {
    tester.view.physicalSize = const Size(430 * 3, 1000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    await SeedService(db).ensureSeeded();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const NutriaApp(),
      ),
    );

    for (var i = 0;
        i < 40 && find.text('Bem-vindo ao Nutria').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Bem-vindo ao Nutria'), findsOneWidget);

    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masculino'));
    await tester.pump();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '32');
    await tester.enterText(fields.at(1), '78');
    await tester.enterText(fields.at(2), '178');
    await tester.pump();

    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Moderado'));
    await tester.pump();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manter peso'));
    await tester.pump();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();

    expect(find.text('Suas metas calculadas'), findsOneWidget);

    await tester.tap(find.text('Começar'));
    for (var i = 0; i < 40 && find.text('Nutria').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final profile = await db.getUserProfile();
    expect(profile, isNotNull);
    expect(profile!.age, 32);
    expect(profile.weight, 78);
    expect(profile.height, 178);
    expect(profile.goal, 'manter');
    expect(profile.kcal, greaterThan(0));
    expect(profile.protein, greaterThan(0));

    expect(find.text('Nutria'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  });
}
