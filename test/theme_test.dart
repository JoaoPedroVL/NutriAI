import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutria/app/app.dart';
import 'package:nutria/app/providers.dart';
import 'package:nutria/core/theme.dart';
import 'package:nutria/data/db/database.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppDatabase> _pumpApp(WidgetTester tester, {ThemeMode mode = ThemeMode.light}) async {
  SharedPreferences.setMockInitialValues({'theme_mode': mode.index});
  tester.view.physicalSize = const Size(360 * 3, 1500 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final db = AppDatabase(NativeDatabase.memory());
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
      overrides: [
        databaseProvider.overrideWithValue(db),
        seedProvider.overrideWith((ref) async {}),
      ],
      child: const NutriaApp(),
    ),
  );

  for (var i = 0; i < 80 && find.text('Proteína').evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  // Deixa a animação de troca de tema terminar.
  await tester.pump(const Duration(milliseconds: 400));
  return db;
}

void main() {
  test('paletas clara e escura têm contraste de texto', () {
    double luminance(Color c) => c.computeLuminance();
    double contrast(Color a, Color b) {
      final l1 = luminance(a), l2 = luminance(b);
      final hi = l1 > l2 ? l1 : l2;
      final lo = l1 > l2 ? l2 : l1;
      return (hi + 0.05) / (lo + 0.05);
    }

    expect(contrast(NutriaColors.light.ink, NutriaColors.light.cream), greaterThan(7));
    expect(contrast(NutriaColors.dark.ink, NutriaColors.dark.cream), greaterThan(7));
    expect(contrast(NutriaColors.dark.muted, NutriaColors.dark.cream), greaterThan(4.5));
    expect(contrast(NutriaColors.dark.green, NutriaColors.dark.cream), greaterThan(4.5));
    expect(contrast(NutriaColors.dark.water, NutriaColors.dark.surface), greaterThan(4.5));
  });

  testWidgets('modo escuro aplica superfícies e texto do tema escuro', (tester) async {
    final db = await _pumpApp(tester, mode: ThemeMode.dark);

    final context = tester.element(find.text('Proteína').first);
    final theme = Theme.of(context);
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, NutriaColors.dark.cream);
    expect(theme.cardTheme.color, NutriaColors.dark.surface);

    final body = theme.textTheme.bodyMedium!;
    expect(body.color, NutriaColors.dark.ink);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    addTearDown(db.close);
  });

  testWidgets('cartão de água fica no diário e soma 250 ml', (tester) async {
    final db = await _pumpApp(tester);

    expect(find.text('Água'), findsOneWidget);
    expect(find.textContaining('0 ml de 2.000 ml'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '250 ml'));
    for (var i = 0; i < 40 && find.textContaining('250 ml de 2.000 ml').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.textContaining('250 ml de 2.000 ml'), findsOneWidget);
    expect(await db.getTodayWaterAmount(), 250);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
    addTearDown(db.close);
  });
}
