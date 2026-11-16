import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/defaults.dart';
import '../../core/food_style.dart';
import '../../core/meals.dart';
import '../../core/text.dart';
import '../../core/theme.dart';
import '../../app/providers.dart';
import '../../data/db/database.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/food_avatar.dart';
import '../../shared/widgets/metric_tile.dart';
import 'add_food_controller.dart';

/// Abre o fluxo de adicionar alimento em uma rota própria.
///
/// [food] pula a busca e vai direto para a porção; [startCustom] abre
/// direto o formulário de alimento personalizado.
Future<void> openAddFood(
  BuildContext context, {
  required DateTime day,
  required String meal,
  Food? food,
  bool startCustom = false,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AddFoodScreen(
        day: day,
        meal: meal,
        initialFood: food,
        startCustom: startCustom,
      ),
    ),
  );
}

class AddFoodScreen extends ConsumerStatefulWidget {
  const AddFoodScreen({
    super.key,
    required this.day,
    required this.meal,
    this.initialFood,
    this.startCustom = false,
  });

  final DateTime day;
  final String meal;
  final Food? initialFood;
  final bool startCustom;

  @override
  ConsumerState<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends ConsumerState<AddFoodScreen> {
  final _search = TextEditingController();
  bool _bootstrapping = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final notifier = ref.read(addFoodControllerProvider.notifier);
    await notifier.init(day: widget.day, meal: widget.meal);
    if (!mounted) return;

    if (widget.initialFood case final food?) {
      await notifier.select(food);
    }
    if (!mounted) return;
    setState(() => _bootstrapping = false);

    if (widget.startCustom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _createCustomFood(context);
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AddFoodState>(addFoodControllerProvider, (previous, next) {
      if (_search.text != next.query) {
        _search.value = TextEditingValue(
          text: next.query,
          selection: TextSelection.collapsed(offset: next.query.length),
        );
      }
    });

    final state = ref.watch(addFoodControllerProvider);
    final amount = state.selected != null && !_bootstrapping;

    return Scaffold(
      appBar: AppBar(
        title: Text(amount ? 'Porção' : 'Adicionar alimento'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: context.colors.greenSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(mealFor(widget.meal).icon,
                        size: 14, color: context.colors.green),
                    const SizedBox(width: 5),
                    Text(
                      mealLabelFor(widget.meal),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: context.colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _bootstrapping
          ? const Center(child: CircularProgressIndicator())
          : state.selected == null
              ? _buildSearch(context, state)
              : _buildAmount(context, state),
    );
  }

  Widget _buildSearch(BuildContext context, AddFoodState state) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (state.restoredDraft)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.colors.greenSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.restore_rounded,
                    size: 17, color: context.colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rascunho restaurado — continue de onde parou.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: context.colors.greenDark),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: TextField(
            controller: _search,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Ex.: arroz, frango, feijão…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: state.query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _search.clear();
                        ref
                            .read(addFoodControllerProvider.notifier)
                            .setQuery('');
                      },
                    ),
            ),
            onChanged: (value) =>
                ref.read(addFoodControllerProvider.notifier).setQuery(value),
          ),
        ),
        Expanded(
          child: state.loading && state.results.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  children: [
                    if (state.query.isEmpty) ...[
                      const _QuickPicks(),
                      if (state.results.isEmpty) const SizedBox(height: 4),
                    ],
                    for (final food in state.results) ...[
                      _FoodTile(
                        food: food,
                        onTap: () => ref
                            .read(addFoodControllerProvider.notifier)
                            .select(food),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 4),
                    _CustomFoodLauncher(
                      onTap: () => _createCustomFood(context),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildAmount(BuildContext context, AddFoodState state) {
    final food = state.selected!;
    return _AmountView(
      key: ValueKey('amount-${food.id}'),
      food: food,
      servings: state.servings,
      initialGrams: state.grams,
      onGramsChanged: (grams) =>
          ref.read(addFoodControllerProvider.notifier).setGrams(grams),
      onBack: () =>
          ref.read(addFoodControllerProvider.notifier).backToSearch(),
      onAdd: (grams) async {
        await ref
            .read(addFoodControllerProvider.notifier)
            .addToDiary(grams: grams);
        if (context.mounted) Navigator.of(context).pop();
      },
      saving: state.saving,
    );
  }

  Future<void> _createCustomFood(BuildContext context) async {
    await showDialog<Food>(
      context: context,
      builder: (_) => const _CustomFoodDialog(),
    );
  }
}

class _FoodTile extends ConsumerWidget {
  const _FoodTile({required this.food, required this.onTap});

  final Food food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final favorites = ref.watch(favoritesProvider).value ?? const <Favorite>[];
    final isFavorite = favorites.any((f) => f.foodId == food.id);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          FoodAvatar(category: food.category, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  '${shortCategory(food.category)} · '
                  '${food.kcal100.toStringAsFixed(0)} '
                  'kcal/100 ${unitForCategory(food.category)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: context.colors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: isFavorite ? 'Remover dos favoritos' : 'Favoritar',
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              await ref.read(favoriteRepositoryProvider).toggle(food.id);
              ref.invalidate(favoritesProvider);
              ref.invalidate(favoriteFoodsProvider);
            },
            icon: Icon(
              isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              size: 22,
              color: isFavorite ? context.colors.carbs : context.colors.muted,
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.colors.muted),
        ],
      ),
    );
  }
}

class _QuickPicks extends ConsumerWidget {
  const _QuickPicks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteFoodsProvider).value ?? const <Food>[];
    final recents = ref.watch(recentFoodsDetailedProvider).value ?? const <Food>[];
    final recentIds = favorites.map((f) => f.id).toSet();
    final visibleRecents =
        recents.where((f) => !recentIds.contains(f.id)).take(5).toList();

    if (favorites.isEmpty && visibleRecents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (favorites.isNotEmpty) ...[
          const _PicksHeader(
            icon: Icons.star_rounded,
            label: 'Favoritos',
          ),
          for (final food in favorites.take(4)) ...[
            _FoodTile(
              food: food,
              onTap: () => ref
                  .read(addFoodControllerProvider.notifier)
                  .select(food),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
        ],
        if (visibleRecents.isNotEmpty) ...[
          const _PicksHeader(
            icon: Icons.history_rounded,
            label: 'Recentes',
          ),
          for (final food in visibleRecents) ...[
            _FoodTile(
              food: food,
              onTap: () => ref
                  .read(addFoodControllerProvider.notifier)
                  .select(food),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}

class _PicksHeader extends StatelessWidget {
  const _PicksHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.colors.green),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.colors.greenDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomFoodLauncher extends StatelessWidget {
  const _CustomFoodLauncher({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      color: context.colors.greenSoft,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.add_rounded, color: context.colors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Criar alimento personalizado',
                    style: theme.textTheme.titleSmall),
                Text(
                  'Informe os valores por 100 g',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: context.colors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountView extends StatefulWidget {
  const _AmountView({
    super.key,
    required this.food,
    required this.servings,
    required this.initialGrams,
    required this.onGramsChanged,
    required this.onAdd,
    required this.onBack,
    this.saving = false,
  });

  final Food food;
  final List<FoodServing> servings;
  final double initialGrams;
  final ValueChanged<double> onGramsChanged;
  final void Function(double grams) onAdd;
  final VoidCallback onBack;
  final bool saving;

  @override
  State<_AmountView> createState() => _AmountViewState();
}

class _AmountViewState extends State<_AmountView> {
  late final TextEditingController _grams;
  late double _value;
  String? _validationError;

  static const _quickGrams = [50.0, 100.0, 150.0, 200.0];

  @override
  void initState() {
    super.initState();
    _value = widget.initialGrams;
    _grams = TextEditingController(text: formatGrams(_value));
  }

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  void _setValue(double grams) {
    setState(() {
      _value = grams;
      _validationError = null;
    });
    widget.onGramsChanged(grams);
    final text = formatGrams(grams);
    _grams.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final food = widget.food;
    final factor = _value / 100.0;
    final unit = unitForCategory(food.category);
    final canAdd = _value > 0 && _value <= kMaxGrams && !widget.saving;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              FoodAvatar(category: food.category, size: 58),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(food.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      '${shortCategory(food.category)} · '
                      'por 100 $unit',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: context.colors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onBack,
                tooltip: 'Voltar para a busca',
                icon: const Icon(Icons.close_rounded),
                color: context.colors.muted,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'kcal',
                value: (food.kcal100 * factor).toStringAsFixed(0),
                color: context.colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricTile(
                label: 'Proteína',
                value: '${(food.protein100 * factor).toStringAsFixed(1)} g',
                color: context.colors.protein,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricTile(
                label: 'Carbo',
                value: '${(food.carbs100 * factor).toStringAsFixed(1)} g',
                color: context.colors.carbs,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricTile(
                label: 'Gordura',
                value: '${(food.fat100 * factor).toStringAsFixed(1)} g',
                color: context.colors.fat,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quantidade', style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              TextField(
                controller: _grams,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: theme.textTheme.headlineMedium,
                decoration: InputDecoration(
                  suffixText: unit,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  errorText: _validationError,
                ),
                onChanged: (text) {
                  final parsed = parseNumber(text);
                  setState(() {
                    if (parsed != null && parsed > 0 && parsed <= kMaxGrams) {
                      _value = parsed;
                      _validationError = null;
                      widget.onGramsChanged(parsed);
                    } else if (parsed == null) {
                      // Deixa o valor antigo e mostra erro se o campo não
                      // estiver vazio.
                      _validationError = text.trim().isEmpty
                          ? null
                          : 'Digite um número válido.';
                    } else if (parsed <= 0) {
                      _validationError = 'A quantidade deve ser maior que zero.';
                    } else {
                      _validationError =
                          'Máximo de ${formatGrams(kMaxGrams)} $unit por lançamento.';
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final grams in _quickGrams)
                    _AmountChip(
                      label: '${formatGrams(grams)} $unit',
                      selected: (_value - grams).abs() < 0.01,
                      onTap: () => _setValue(grams),
                    ),
                ],
              ),
              if (widget.servings.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Medidas caseiras',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: context.colors.muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final serving in widget.servings)
                      _AmountChip(
                        label: servingDisplayLabel(
                          serving.label,
                          serving.grams,
                          food.category,
                        ),
                        selected: (_value - serving.grams).abs() < 0.01,
                        onTap: () => _setValue(serving.grams),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed:
              canAdd ? () => widget.onAdd(_value) : null,
          icon: widget.saving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: context.colors.onGreen,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 20),
          label: Text(widget.saving ? 'Salvando…' : 'Adicionar ao diário'),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Fonte: ${sourceLabel(food.source)}',
            style: theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
          ),
        ),
      ],
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? context.colors.green : context.colors.cream,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? context.colors.onGreen : context.colors.muted,
          ),
        ),
      ),
    );
  }
}

class _CustomFoodDialog extends ConsumerStatefulWidget {
  const _CustomFoodDialog();

  @override
  ConsumerState<_CustomFoodDialog> createState() => _CustomFoodDialogState();
}

class _CustomFoodDialogState extends ConsumerState<_CustomFoodDialog> {
  final _name = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _kcal.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  double? _validateAndParse(TextEditingController controller, String label) {
    final value = parseNumber(controller.text);
    if (value == null) {
      _error = '$label: valor inválido.';
      return null;
    }
    if (value < 0 || value > kMaxKcalPer100) {
      _error = '$label: deve ser entre 0 e ${kMaxKcalPer100.toStringAsFixed(0)}.';
      return null;
    }
    return value;
  }

  Future<void> _save() async {
    _error = null;
    final name = _name.text.trim();
    if (name.isEmpty) {
      _error = 'Nome é obrigatório.';
      setState(() {});
      return;
    }

    final kcal = _validateAndParse(_kcal, 'kcal');
    final protein = _validateAndParse(_protein, 'Proteína');
    final carbs = _validateAndParse(_carbs, 'Carboidrato');
    final fat = _validateAndParse(_fat, 'Gordura');

    if (kcal == null || protein == null || carbs == null || fat == null) {
      setState(() {});
      return;
    }

    setState(() => _saving = true);

    try {
      final food = await ref.read(addFoodControllerProvider.notifier).createCustomFood(
            name: name,
            kcal100: kcal,
            protein100: protein,
            carbs100: carbs,
            fat100: fat,
          );
      if (!mounted) return;
      Navigator.of(context).pop(food);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Erro ao criar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Novo alimento'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: context.colors.coral),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 140,
              decoration: const InputDecoration(
                labelText: 'Nome',
                counterText: '',
              ),
            ),
            _NumberField(controller: _kcal, label: 'kcal por 100 g'),
            _NumberField(controller: _protein, label: 'Proteína (g/100 g)'),
            _NumberField(controller: _carbs, label: 'Carboidrato (g/100 g)'),
            _NumberField(controller: _fat, label: 'Gordura (g/100 g)'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Criando…' : 'Criar'),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }
}