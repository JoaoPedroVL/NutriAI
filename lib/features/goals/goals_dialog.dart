import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/text.dart';
import '../../core/theme.dart';
import '../../data/repositories/goals_repository.dart';

class GoalsDialog extends ConsumerStatefulWidget {
  const GoalsDialog({super.key});

  @override
  ConsumerState<GoalsDialog> createState() => _GoalsDialogState();
}

class _GoalsDialogState extends ConsumerState<GoalsDialog> {
  late final TextEditingController _kcal;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  String? _error;

  @override
  void initState() {
    super.initState();
    final goals = ref.read(goalsProvider).value ?? NutritionGoals.defaults;
    _kcal = TextEditingController(text: goals.kcal.toStringAsFixed(0));
    _protein = TextEditingController(text: goals.protein.toStringAsFixed(0));
    _carbs = TextEditingController(text: goals.carbs.toStringAsFixed(0));
    _fat = TextEditingController(text: goals.fat.toStringAsFixed(0));
  }

  @override
  void dispose() {
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
    if (value <= 0) {
      _error = '$label: deve ser maior que zero.';
      return null;
    }
    return value;
  }

  Future<void> _save() async {
    _error = null;
    final kcal = _validateAndParse(_kcal, 'Calorias');
    final protein = _validateAndParse(_protein, 'Proteína');
    final carbs = _validateAndParse(_carbs, 'Carboidrato');
    final fat = _validateAndParse(_fat, 'Gordura');

    if (kcal == null || protein == null || carbs == null || fat == null) {
      setState(() {});
      return;
    }

    final profile = await ref.read(userProfileRepositoryProvider).get();
    if (profile != null) {
      await ref.read(userProfileRepositoryProvider).updatePartial(
            kcal: kcal,
            protein: protein,
            carbs: carbs,
            fat: fat,
          );
      ref.invalidate(userProfileProvider);
    } else {
      await ref.read(goalsRepositoryProvider).save(
            NutritionGoals(
              kcal: kcal,
              protein: protein,
              carbs: carbs,
              fat: fat,
            ),
          );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Metas diárias'),
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
            _field(_kcal, 'Calorias (kcal)'),
            _field(_protein, 'Proteína (g)'),
            _field(_carbs, 'Carboidrato (g)'),
            _field(_fat, 'Gordura (g)'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }
}
