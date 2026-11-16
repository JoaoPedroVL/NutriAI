import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design_tokens.dart';
import '../../core/defaults.dart';
import '../../core/meals.dart';
import '../../core/text.dart';
import '../../core/theme.dart';
import '../../data/db/database.dart';
import '../../data/repositories/diary_repository.dart';
import '../../data/repositories/goals_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/calorie_ring.dart';
import '../../shared/widgets/food_avatar.dart';
import '../../shared/widgets/macro_stat.dart';
import '../../shared/widgets/metric_tile.dart';
import '../add_food/add_food_screen.dart';
import '../barcode/barcode_scan_screen.dart';
import '../goals/goals_dialog.dart';

class DiaryTab extends ConsumerWidget {
  const DiaryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final entriesAsync = ref.watch(dayEntriesProvider);
    final goals = ref.watch(goalsProvider).value ?? NutritionGoals.defaults;

    return SafeArea(
      bottom: false,
      child: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Não foi possível carregar o diário.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.coral, fontSize: 14),
          ),
        ),
        data: (entries) => _DiaryBody(
          entries: entries,
          goals: goals,
          date: date,
        ),
      ),
    );
  }
}

class _DiaryBody extends StatelessWidget {
  const _DiaryBody({
    required this.entries,
    required this.goals,
    required this.date,
  });

  final List<DiaryEntry> entries;
  final NutritionGoals goals;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final totals = DayTotals.from(entries);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: [
        const _Header(),
        SizedBox(height: AppSpacing.lg),
        _DateBar(date: date),
        SizedBox(height: AppSpacing.lg),
        _SummaryCard(totals: totals, goals: goals),
        SizedBox(height: AppSpacing.md),
        _QuickActions(date: date),
        SizedBox(height: AppSpacing.md),
        _SearchLauncher(date: date),
        SizedBox(height: AppSpacing.md),
        const _WaterCard(),
        SizedBox(height: AppSpacing.xxl),
        _SectionHeaderWithSpacing(title: 'Refeições'),
        ..._buildMealCards(),
      ],
    );
  }

  List<Widget> _buildMealCards() {
    final widgets = <Widget>[];
    for (final meal in kMeals) {
      widgets.add(_MealCard(
        meal: meal,
        entries: entries.where((e) => e.meal == meal.id).toList(),
        date: date,
      ));
      widgets.add(SizedBox(height: AppSpacing.md));
    }
    return widgets;
  }
}

class _SectionHeaderWithSpacing extends StatelessWidget {
  const _SectionHeaderWithSpacing({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: SectionHeader(title: title),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.eco_rounded,
                      size: AppIconSize.sm, color: context.colors.green),
                  SizedBox(width: AppSpacing.xs),
                  Text(
                    'NutriAI',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.colors.green,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.lg),
              Text(
                'Olá! 👋',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: context.colors.muted),
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                'O que vamos\ncomer hoje?',
                style: theme.textTheme.displaySmall,
              ),
            ],
          ),
        ),
        Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.colors.greenSoft,
            shape: BoxShape.circle,
            border: Border.all(color: context.colors.surface, width: 2),
          ),
          child: Text('🥗', style: TextStyle(fontSize: 24)),
        ),
      ],
    );
  }
}

class _DateBar extends ConsumerWidget {
  const _DateBar({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(selectedDateProvider.notifier);
    final theme = Theme.of(context);
    final formatted = '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: kSoftShadow,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => notifier.shift(-1),
            icon: const Icon(Icons.chevron_left_rounded),
            color: context.colors.muted,
            tooltip: 'Dia anterior',
          ),
          Expanded(
            child: Column(
              children: [
                Text(prettyDate(date), style: theme.textTheme.titleSmall),
                Text(
                  formatted,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: context.colors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => notifier.shift(1),
            icon: const Icon(Icons.chevron_right_rounded),
            color: context.colors.muted,
            tooltip: 'Próximo dia',
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totals, required this.goals});

  final DayTotals totals;
  final NutritionGoals goals;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CalorieRing(value: totals.kcal, goal: goals.kcal),
          SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              children: [
                MacroStat(
                  label: 'Proteína',
                  value: totals.protein,
                  goal: goals.protein,
                  color: context.colors.protein,
                ),
                SizedBox(height: AppSpacing.lg),
                MacroStat(
                  label: 'Carboidrato',
                  value: totals.carbs,
                  goal: goals.carbs,
                  color: context.colors.carbs,
                ),
                SizedBox(height: AppSpacing.lg),
                MacroStat(
                  label: 'Gordura',
                  value: totals.fat,
                  goal: goals.fat,
                  color: context.colors.fat,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final meal = defaultMealFor(DateTime.now());
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.add_rounded,
            label: 'Adicionar',
            filled: true,
            onTap: () => openAddFood(context, day: date, meal: meal),
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: _QuickAction(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Escanear',
            onTap: () => openBarcodeScanner(
              context,
              day: date,
              meal: meal,
            ),
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: _QuickAction(
            icon: Icons.flag_rounded,
            label: 'Metas',
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => const GoalsDialog(),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: AppCard(
        onTap: onTap,
        color: filled ? context.colors.green : context.colors.surface,
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          children: [
            Icon(
              icon,
              size: AppIconSize.lg,
              color: filled ? context.colors.onGreen : context.colors.green,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: filled ? context.colors.onGreen : context.colors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cartão compacto de água, junto das refeições do diário.
class _WaterCard extends ConsumerWidget {
  const _WaterCard();

  static const _cupMl = 250.0;
  static const _goalMl = 2000.0;
  static const _cups = 8;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(todayWaterProvider);
    ref.invalidate(todayWaterLogsProvider);
  }

  Future<void> _add(WidgetRef ref, double ml) async {
    await ref.read(waterRepositoryProvider).addLog(ml);
    await _refresh(ref);
  }

  Future<void> _undo(WidgetRef ref, int id) async {
    await ref.read(waterRepositoryProvider).deleteLog(id);
    await _refresh(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final amount = ref.watch(todayWaterProvider).value ?? 0.0;
    final logs = ref.watch(todayWaterLogsProvider).value ?? const [];
    final filled = (amount / _cupMl).floor().clamp(0, _cups);
    final progress = (amount / _goalMl).clamp(0.0, 1.0);
    final percent = (progress * 100).round();

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.waterSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.water_drop_rounded,
                  color: colors.water,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Água', style: theme.textTheme.titleMedium),
                    Text(
                      '${amount.toStringAsFixed(0)} ml de 2.000 ml '
                      '• 8 copos de 250 ml',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
              if (logs.isNotEmpty)
                IconButton(
                  tooltip: 'Desfazer último copo',
                  onPressed: () => _undo(ref, logs.first.id),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.undo_rounded, size: 20, color: colors.muted),
                ),
              Text(
                '$percent%',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.water,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < _cups; i++)
                Semantics(
                  button: true,
                  label: 'Beber ${(i + 1) * _cupMl.toInt()} ml',
                  child: GestureDetector(
                    onTap: () {
                      final delta = (i + 1) * _cupMl - amount;
                      if (delta > 0) _add(ref, delta);
                    },
                    child: Container(
                      width: 30,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i < filled ? colors.waterSoft : null,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        i < filled
                            ? Icons.local_drink_rounded
                            : Icons.local_drink_outlined,
                        size: 19,
                        color: i < filled
                            ? colors.water
                            : colors.muted.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colors.line,
              valueColor: AlwaysStoppedAnimation<Color>(colors.water),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _add(ref, _cupMl),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('250 ml'),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.water,
                  foregroundColor: colors.onWater,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  textStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _add(ref, _cupMl * 2),
                icon: const Icon(Icons.local_drink_outlined, size: 18),
                label: const Text('500 ml'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.water,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  side: BorderSide(color: colors.water.withValues(alpha: 0.55)),
                  textStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchLauncher extends StatelessWidget {
  const _SearchLauncher({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Buscar alimento',
      child: AppCard(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        onTap: () => openAddFood(
          context,
          day: date,
          meal: defaultMealFor(DateTime.now()),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: context.colors.muted),
            SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                'Buscar alimento...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: context.colors.muted),
              ),
            ),
            Container(
              padding: EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: context.colors.greenSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: AppIconSize.sm,
                color: context.colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealCard extends ConsumerWidget {
  const _MealCard({
    required this.meal,
    required this.entries,
    required this.date,
  });

  final Meal meal;
  final List<DiaryEntry> entries;
  final DateTime date;

  Future<void> _copyYesterday(BuildContext context, WidgetRef ref) async {
    final yesterday = date.subtract(const Duration(days: 1));
    final copied = await ref.read(diaryRepositoryProvider).copyMeal(
          fromDay: yesterday,
          toDay: date,
          meal: meal.id,
        );
    ref.invalidate(dayEntriesProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          copied == 0
              ? 'Nada registrado em ${meal.label.toLowerCase()} ontem.'
              : '$copied ${copied == 1 ? 'item copiado' : 'itens copiados'} '
                  'de ontem.',
        ),
      ),
    );
  }

  Future<void> _saveMeal(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _SaveMealDialog(defaultName: meal.label),
    );
    if (name == null || !context.mounted) return;

    await ref.read(savedMealRepositoryProvider).saveFromEntries(
          name: name,
          meal: meal.id,
          entries: entries,
        );
    ref.invalidate(savedMealsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('“$name” salva para reutilizar.')),
    );
  }

  Future<void> _openSavedMeals(BuildContext context, WidgetRef ref) async {
    final saved = await ref.read(savedMealRepositoryProvider).getAll();
    if (!context.mounted) return;
    if (saved.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nenhuma refeição salva ainda. Use o menu da refeição para salvar.',
          ),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<SavedMeal>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SavedMealsSheet(meals: saved),
    );
    if (selected == null || !context.mounted) return;

    final count = await ref.read(savedMealRepositoryProvider).applyToDay(
          savedMealId: selected.id,
          day: date,
          meal: meal.id,
        );
    ref.invalidate(dayEntriesProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$count ${count == 1 ? 'item adicionado' : 'itens adicionados'} '
          'de “${selected.name}”.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtotal = DayTotals.from(entries);
    final yesterday = date.subtract(const Duration(days: 1));

    return AppCard(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          _MealCardHeader(
            meal: meal,
            subtotal: subtotal,
            onCopyYesterday: () => _copyYesterday(context, ref),
            onOpenSavedMeals: () => _openSavedMeals(context, ref),
            onSaveCurrent: () => _saveMeal(context, ref),
            canSaveCurrent: entries.isNotEmpty,
            onAdd: () => openAddFood(
              context,
              day: date,
              meal: meal.id,
            ),
          ),
          if (entries.isEmpty)
            _MealEmptyState(
              onAdd: () => openAddFood(context, day: date, meal: meal.id),
              onCopyYesterday: () => _copyYesterday(context, ref),
              onRecents: () => openAddFood(context, day: date, meal: meal.id),
              hasYesterday: yesterday.isBefore(startOfDay(DateTime.now())),
            )
          else ...[
            SizedBox(height: AppSpacing.xs),
            for (final entry in entries) _EntryRow(entry: entry),
          ],
        ],
      ),
    );
  }
}

class _MealCardHeader extends StatelessWidget {
  const _MealCardHeader({
    required this.meal,
    required this.subtotal,
    required this.onCopyYesterday,
    required this.onOpenSavedMeals,
    required this.onSaveCurrent,
    required this.canSaveCurrent,
    required this.onAdd,
  });

  final Meal meal;
  final DayTotals subtotal;
  final VoidCallback onCopyYesterday;
  final VoidCallback onOpenSavedMeals;
  final VoidCallback onSaveCurrent;
  final bool canSaveCurrent;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: context.colors.greenSoft,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Icon(meal.icon, color: context.colors.green, size: AppIconSize.md),
        ),
        SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(meal.label, style: theme.textTheme.titleMedium),
              Text(
                '${subtotal.kcal.toStringAsFixed(0)} kcal',
                style: theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
              ),
            ],
          ),
        ),
        PopupMenuButton<_MealAction>(
          tooltip: 'Opções de ${meal.label}',
          icon: Icon(
            Icons.more_horiz_rounded,
            color: context.colors.muted,
            size: AppIconSize.sm,
          ),
          onSelected: (action) {
            switch (action) {
              case _MealAction.copyYesterday:
                onCopyYesterday();
              case _MealAction.savedMeals:
                onOpenSavedMeals();
              case _MealAction.saveCurrent:
                onSaveCurrent();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: _MealAction.copyYesterday,
              child: Text('Copiar de ontem'),
            ),
            const PopupMenuItem(
              value: _MealAction.savedMeals,
              child: Text('Usar refeição salva'),
            ),
            PopupMenuItem(
              value: _MealAction.saveCurrent,
              enabled: canSaveCurrent,
              child: const Text('Salvar refeição atual'),
            ),
          ],
        ),
        SizedBox(width: AppSpacing.xs),
        _AddButton(
          mealLabel: meal.label,
          onTap: onAdd,
        ),
      ],
    );
  }
}

enum _MealAction { copyYesterday, savedMeals, saveCurrent }

class _MealEmptyState extends StatelessWidget {
  const _MealEmptyState({
    required this.onAdd,
    required this.onCopyYesterday,
    required this.onRecents,
    required this.hasYesterday,
  });

  final VoidCallback onAdd;
  final VoidCallback onCopyYesterday;
  final VoidCallback onRecents;
  final bool hasYesterday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Refeição vazia. Adicione alimentos ou copie de ontem.',
      child: Container(
        margin: EdgeInsets.only(top: AppSpacing.md),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: context.colors.cream,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.colors.greenSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_rounded,
                size: AppIconSize.md,
                color: context.colors.green,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Nada por aqui ainda',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.ink,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Registre seu primeiro alimento e veja o resumo do dia ganhar vida.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.colors.muted,
                height: 1.4,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: AppIconSize.md),
                label: const Text('Adicionar alimento'),
                style: FilledButton.styleFrom(
                  minimumSize: Size.fromHeight(AppTouchTarget.minSize),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.xs,
              children: [
                TextButton.icon(
                  onPressed: hasYesterday ? onCopyYesterday : null,
                  icon: const Icon(Icons.content_copy_rounded, size: AppIconSize.sm),
                  label: const Text('Copiar de ontem'),
                  style: TextButton.styleFrom(
                    minimumSize: Size(AppTouchTarget.minSize, AppTouchTarget.minSize),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                TextButton.icon(
                  onPressed: onRecents,
                  icon: const Icon(Icons.history_rounded, size: AppIconSize.sm),
                  label: const Text('Recentes'),
                  style: TextButton.styleFrom(
                    minimumSize: Size(AppTouchTarget.minSize, AppTouchTarget.minSize),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveMealDialog extends StatefulWidget {
  const _SaveMealDialog({required this.defaultName});

  final String defaultName;

  @override
  State<_SaveMealDialog> createState() => _SaveMealDialogState();
}

class _SaveMealDialogState extends State<_SaveMealDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.defaultName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Salvar refeição'),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Nome da refeição'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final value = _name.text.trim();
            if (value.isEmpty) return;
            Navigator.of(context).pop(value);
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _SavedMealsSheet extends StatelessWidget {
  const _SavedMealsSheet({required this.meals});

  final List<SavedMeal> meals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.colors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: context.colors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Refeições salvas',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final meal in meals) ...[
                  AppCard(
                    onTap: () => Navigator.of(context).pop(meal),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.bookmark_rounded,
                            size: 20, color: context.colors.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            meal.name,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          mealLabelFor(meal.meal),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: context.colors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.mealLabel, required this.onTap});

  final String mealLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Adicionar em $mealLabel',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: context.colors.greenSoft,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(9),
              child: Icon(Icons.add_rounded, color: context.colors.green, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final DiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '${entry.foodName}, ${formatGrams(entry.grams)} ${unitForCategory(entry.category)}, ${entry.kcal.toStringAsFixed(0)} calorias',
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _showEditSheet(context, entry),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              FoodAvatar(category: entry.category, size: 42),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.foodName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      '${formatGrams(entry.grams)} '
                      '${unitForCategory(entry.category)} · '
                      'P ${entry.protein.toStringAsFixed(1)} · '
                      'C ${entry.carbs.toStringAsFixed(1)} · '
                      'G ${entry.fat.toStringAsFixed(1)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: context.colors.muted),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Text(
                '${entry.kcal.toStringAsFixed(0)} kcal',
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showEditSheet(BuildContext context, DiaryEntry entry) async {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditEntrySheet(entry: entry),
  );
}

class _EditEntrySheet extends ConsumerStatefulWidget {
  const _EditEntrySheet({required this.entry});

  final DiaryEntry entry;

  @override
  ConsumerState<_EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends ConsumerState<_EditEntrySheet> {
  late final TextEditingController _grams;
  late double _value;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _value = widget.entry.grams;
    _grams = TextEditingController(text: formatGrams(_value));
  }

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final parsed = parseNumber(_grams.text);
    if (parsed == null || parsed <= 0 || parsed > kMaxGrams) {
      setState(() {
        _validationError = parsed == null
            ? 'Digite um número válido.'
            : (parsed <= 0
                ? 'A quantidade deve ser maior que zero.'
                : 'Máximo de ${formatGrams(kMaxGrams)} ${unitForCategory(widget.entry.category)} por lançamento.');
      });
      return;
    }

    final saved = await ref
        .read(diaryRepositoryProvider)
        .updateGrams(widget.entry, parsed);

    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _validationError = 'Não foi possível atualizar.';
      });
    }
  }

  Future<void> _delete() async {
    await ref.read(diaryRepositoryProvider).deleteEntry(widget.entry.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;
    final factor = entry.grams <= 0 ? 0.0 : _value / entry.grams;
    final unit = unitForCategory(entry.category);

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xl + MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: context.colors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: context.colors.line,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  FoodAvatar(category: entry.category, size: 52),
                  SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Text(entry.foodName, style: theme.textTheme.titleLarge),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: 'kcal',
                      value: (entry.kcal * factor).toStringAsFixed(0),
                      color: context.colors.green,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: MetricTile(
                      label: 'Proteína',
                      value: '${(entry.protein * factor).toStringAsFixed(1)} g',
                      color: context.colors.protein,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: MetricTile(
                      label: 'Carbo',
                      value: '${(entry.carbs * factor).toStringAsFixed(1)} g',
                      color: context.colors.carbs,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: MetricTile(
                      label: 'Gordura',
                      value: '${(entry.fat * factor).toStringAsFixed(1)} g',
                      color: context.colors.fat,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _grams,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Quantidade',
                  suffixText: unit,
                  errorText: _validationError,
                ),
                onChanged: (text) {
                  final parsed = parseNumber(text);
                  setState(() {
                    if (parsed != null && parsed > 0 && parsed <= kMaxGrams) {
                      _value = parsed;
                      _validationError = null;
                    } else if (parsed == null) {
                      _validationError = text.trim().isEmpty
                          ? null
                          : 'Digite um número válido.';
                    } else if (parsed <= 0) {
                      _validationError = 'A quantidade deve ser maior que zero.';
                    } else {
                      _validationError = 'Máximo de ${formatGrams(kMaxGrams)} $unit por lançamento.';
                    }
                  });
                },
              ),
              SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  minimumSize: Size.fromHeight(AppTouchTarget.minSize),
                ),
                child: const Text('Salvar'),
              ),
              TextButton(
                onPressed: _delete,
                style: TextButton.styleFrom(
                  minimumSize: Size.fromHeight(AppTouchTarget.minSize),
                ),
                child: Text(
                  'Remover do diário',
                  style: TextStyle(color: context.colors.coral, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}