import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/food_style.dart';
import '../../core/meals.dart';
import '../../core/text.dart';
import '../../core/theme.dart';
import '../../data/db/database.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/food_avatar.dart';
import '../add_food/add_food_screen.dart';
import '../barcode/barcode_scan_screen.dart';

class FoodsTab extends ConsumerStatefulWidget {
  const FoodsTab({super.key});

  @override
  ConsumerState<FoodsTab> createState() => _FoodsTabState();
}

class _FoodsTabState extends ConsumerState<FoodsTab> {
  final _search = TextEditingController();
  Timer? _debounce;
  StreamSubscription<List<Food>>? _subscription;
  String _query = '';
  String _category = 'Todos';
  List<Food> _results = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subscription?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _subscribe() {
    _subscription?.cancel();
    setState(() => _loading = true);
    _subscription = ref
        .read(foodRepositoryProvider)
        .watchList(
          query: _query,
          category: _category == 'Todos' ? null : _category,
          limit: 300,
        )
        .listen((foods) {
      if (!mounted) return;
      setState(() {
        _results = foods;
        _loading = false;
      });
    });
  }

  void _onQueryChanged(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), _subscribe);
    setState(() {});
  }

  void _selectCategory(String category) {
    setState(() => _category = category);
    _subscribe();
  }

  Future<void> _openFood(Food food) async {
    final day = ref.read(selectedDateProvider);
    final meal = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MealPickerSheet(food: food),
    );
    if (meal == null || !mounted) return;
    await openAddFood(context, day: day, meal: meal, food: food);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alimentos', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  'Tabela TACO 4ª edição · valores por 100 g/ml',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: context.colors.muted),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Buscar arroz, frango, banana…',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpar',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    _search.clear();
                                    _onQueryChanged('');
                                  },
                                ),
                        ),
                        onChanged: _onQueryChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ScanButton(
                      onTap: () => openBarcodeScanner(
                        context,
                        day: ref.read(selectedDateProvider),
                        meal: defaultMealFor(DateTime.now()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: kCategoryFilters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = kCategoryFilters[index];
                final selected = category == _category;
                return GestureDetector(
                  onTap: () => _selectCategory(category),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                    decoration: BoxDecoration(
                      color:
                          selected ? context.colors.green : context.colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: selected ? null : kSoftShadow,
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.5,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? context.colors.onGreen : context.colors.muted,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? _EmptyState(query: _query)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount: _results.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          if (index == _results.length) {
                            return _CustomFoodCard(
                              onTap: () => openAddFood(
                                context,
                                day: ref.read(selectedDateProvider),
                                meal: defaultMealFor(DateTime.now()),
                                startCustom: true,
                              ),
                            );
                          }
                          final food = _results[index];
                          return _FoodRow(
                            food: food,
                            onTap: () => _openFood(food),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Icon(
        Icons.qr_code_scanner_rounded,
        color: context.colors.green,
        size: 24,
      ),
    );
  }
}

class _FoodRow extends ConsumerWidget {
  const _FoodRow({required this.food, required this.onTap});

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
                  'P ${food.protein100.toStringAsFixed(1)} '
                  '· C ${food.carbs100.toStringAsFixed(1)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: context.colors.muted),
                ),
              ],
            ),
          ),
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
              size: 21,
              color: isFavorite ? context.colors.carbs : context.colors.muted,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                food.kcal100.toStringAsFixed(0),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                'kcal/100 ${unitForCategory(food.category)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: context.colors.muted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomFoodCard extends StatelessWidget {
  const _CustomFoodCard({required this.onTap});

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
                Text('Criar alimento', style: theme.textTheme.titleSmall),
                Text(
                  'Informe os valores por 100 g',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: context.colors.muted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.colors.green),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              query.isEmpty
                  ? 'Nenhum alimento nesta categoria'
                  : 'Nada encontrado para “$query”',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Tente outro termo ou crie um alimento personalizado.',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealPickerSheet extends StatelessWidget {
  const _MealPickerSheet({required this.food});

  final Food food;

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
        children: [
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: context.colors.line,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              FoodAvatar(category: food.category, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Text(food.name, style: theme.textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Adicionar em qual refeição?',
                style: theme.textTheme.titleSmall),
          ),
          const SizedBox(height: 10),
          for (final meal in kMeals)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () => Navigator.of(context).pop(meal.id),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Icon(meal.icon, color: context.colors.green, size: 21),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(meal.label,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: context.colors.muted),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}