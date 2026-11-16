import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/text.dart';
import '../../data/db/database.dart';

class AddFoodState {
  const AddFoodState({
    this.query = '',
    this.results = const [],
    this.selected,
    this.servings = const [],
    this.grams = 100,
    this.loading = false,
    this.restoredDraft = false,
    this.saving = false,
  });

  final String query;
  final List<Food> results;
  final Food? selected;
  final List<FoodServing> servings;
  final double grams;
  final bool loading;
  final bool restoredDraft;
  final bool saving;

  static const _unset = Object();

  AddFoodState copyWith({
    String? query,
    List<Food>? results,
    Object? selected = _unset,
    List<FoodServing>? servings,
    double? grams,
    bool? loading,
    bool? restoredDraft,
    bool? saving,
  }) {
    return AddFoodState(
      query: query ?? this.query,
      results: results ?? this.results,
      selected:
          identical(selected, _unset) ? this.selected : selected as Food?,
      servings: servings ?? this.servings,
      grams: grams ?? this.grams,
      loading: loading ?? this.loading,
      restoredDraft: restoredDraft ?? this.restoredDraft,
      saving: saving ?? this.saving,
    );
  }
}

/// Controla o fluxo "adicionar alimento" e persiste um rascunho a cada
/// alteração — a garantia de que matar o app não perde o preenchimento.
class AddFoodController extends Notifier<AddFoodState> {
  Timer? _debounce;
  Timer? _draftDebounce;
  int _searchToken = 0;
  String _draftKey = '';
  DateTime _day = startOfDay(DateTime.now());
  String _meal = 'lunch';

  @override
  AddFoodState build() {
    ref.onDispose(() {
      _debounce?.cancel();
      _draftDebounce?.cancel();
    });
    return const AddFoodState();
  }

  Future<void> init({required DateTime day, required String meal}) async {
    // Adia para depois do build inicial, evitando "Tried to modify a provider
    // while the widget tree was building" no modo debug.
    await Future<void>.delayed(Duration.zero);

    _day = startOfDay(day);
    _meal = meal;
    _draftKey = 'add_food|${dayKey(_day)}|$meal';

    // Sempre começa limpo; o rascunho (se existir) repõe o estado abaixo.
    state = const AddFoodState();

    final raw = await ref.read(draftRepositoryProvider).load(_draftKey);
    if (raw == null) return;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final foodId = (map['foodId'] as num?)?.toInt();
      final query = (map['query'] as String?) ?? '';
      final grams = (map['grams'] as num?)?.toDouble() ?? 100;

      Food? food;
      var servings = const <FoodServing>[];
      if (foodId != null) {
        food = await ref.read(foodRepositoryProvider).byId(foodId);
        if (food != null) {
          servings = await ref.read(foodRepositoryProvider).servingsFor(food.id);
        }
      }

      state = state.copyWith(
        query: query,
        grams: grams,
        selected: food,
        servings: servings,
        results: food == null ? const [] : [food],
        restoredDraft: true,
      );

      if (food == null && query.isNotEmpty) {
        await _runSearch(query);
      }
    } catch (_) {
      // Rascunho corrompido: segue com formulário limpo.
    }
  }

  void setQuery(String query) {
    state = state.copyWith(query: query, selected: null, results: const []);
    _persistDraftDebounced();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    final token = ++_searchToken;
    state = state.copyWith(loading: true);
    final results = await ref.read(foodRepositoryProvider).search(query);
    if (token != _searchToken) return;
    state = state.copyWith(results: results, loading: false);
  }

  Future<void> select(Food food) async {
    final servings = await ref.read(foodRepositoryProvider).servingsFor(food.id);

    // Padrão: 100 g; se houver medida "unidade", usa ela (ex.: 1 ovo = 50 g).
    var defaultGrams = 100.0;
    for (final serving in servings) {
      if (serving.label.toLowerCase().contains('unidade')) {
        defaultGrams = serving.grams;
        break;
      }
    }
    // Produto escaneado com uma porção declarada (ex.: lata de 350 ml).
    if (defaultGrams == 100.0 && food.source == 'off' && servings.length == 1) {
      defaultGrams = servings.first.grams;
    }

    state = state.copyWith(
      selected: food,
      servings: servings,
      grams: defaultGrams,
      results: [food],
    );
    await _persistDraft();
  }

  void setGrams(double grams) {
    state = state.copyWith(grams: grams);
    _persistDraftDebounced();
  }

  void backToSearch() {
    state = state.copyWith(selected: null, results: const []);
    if (state.query.isNotEmpty) _runSearch(state.query);
  }

  Future<Food> createCustomFood({
    required String name,
    required double kcal100,
    required double protein100,
    required double carbs100,
    required double fat100,
  }) async {
    final food = await ref.read(foodRepositoryProvider).createCustomFood(
          name: name,
          kcal100: kcal100,
          protein100: protein100,
          carbs100: carbs100,
          fat100: fat100,
        );
    await select(food);
    return food;
  }

  Future<void> _persistDraft() async {
    if (_draftKey.isEmpty) return;
    final payload = jsonEncode({
      'foodId': state.selected?.id,
      'query': state.query,
      'grams': state.grams,
    });
    await ref.read(draftRepositoryProvider).save(_draftKey, payload);
  }

  void _persistDraftDebounced() {
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 200), _persistDraft);
  }

  Future<void> addToDiary({double? grams}) async {
    if (state.saving) return;
    final food = state.selected;
    final amount = grams ?? state.grams;
    if (food == null || amount <= 0) return;

    state = state.copyWith(saving: true);

    try {
      await ref.read(diaryRepositoryProvider).addEntry(
            day: _day,
            meal: _meal,
            food: food,
            grams: amount,
          );
      await ref.read(recentFoodRepositoryProvider).add(food.id);
      ref.invalidate(recentFoodsProvider);
      ref.invalidate(recentFoodsDetailedProvider);
      await ref.read(draftRepositoryProvider).clear(_draftKey);
      state = const AddFoodState();
    } finally {
      state = state.copyWith(saving: false);
    }
  }
}

final addFoodControllerProvider =
    NotifierProvider<AddFoodController, AddFoodState>(AddFoodController.new);
