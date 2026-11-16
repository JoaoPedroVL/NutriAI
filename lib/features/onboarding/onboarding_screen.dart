import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/user_profile.dart';
import '../../core/theme.dart';
import '../../data/db/database.dart' show UserProfileData;

/// Tela de onboarding exibida na primeira abertura do app e ao editar o perfil.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.isEditing = false});

  /// Quando `true`, salva e volta para a tela anterior em vez de entrar no app.
  final bool isEditing;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController =
      PageController(initialPage: widget.isEditing ? 1 : 0);
  late int _currentPage = widget.isEditing ? 1 : 0;

  // Dados do formulário
  String? _sex;
  int? _age;
  double? _weight;
  int? _height;
  String? _activityLevel;
  String? _goal;

  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      title: 'Bem-vindo ao Nutria',
      subtitle: 'Vamos configurar seu perfil para calcular suas metas personalizadas.',
      icon: Icons.restaurant_menu,
    ),
    _OnboardingPage(
      title: 'Dados Pessoais',
      subtitle: 'Precisamos de algumas informações para calcular seu gasto calórico.',
      icon: Icons.person,
    ),
    _OnboardingPage(
      title: 'Estilo de Vida',
      subtitle: 'Qual seu nível de atividade física no dia a dia?',
      icon: Icons.directions_run,
    ),
    _OnboardingPage(
      title: 'Seu Objetivo',
      subtitle: 'O que você deseja alcançar com o Nutria?',
      icon: Icons.flag,
    ),
    _OnboardingPage(
      title: 'Suas Metas',
      subtitle: 'Aqui estão suas metas calculadas. Você pode ajustar se quiser.',
      icon: Icons.tune,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider).value;
    if (profile == null) return;
    _sex = profile.sex;
    _age = profile.age;
    _weight = profile.weight;
    _height = profile.height;
    _activityLevel = profile.activityLevel;
    _goal = profile.goal;
    if (profile.age != null) _ageController.text = '${profile.age}';
    if (profile.weight != null) {
      _weightController.text =
          profile.weight!.toStringAsFixed(1).replaceAll('.', ',');
    }
    if (profile.height != null) _heightController.text = '${profile.height}';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_validateCurrentPage()) {
      if (_currentPage < _pages.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 1: // Dados pessoais
        if (_sex == null) {
          _showError('Selecione seu sexo biológico');
          return false;
        }
        if (_age == null || _weight == null || _height == null) {
          _showError('Preencha todos os campos');
          return false;
        }
        if (_age! < 14 || _age! > 100) {
          _showError('Informe uma idade entre 14 e 100 anos');
          return false;
        }
        if (_weight! < 30 || _weight! > 300) {
          _showError('Informe um peso entre 30 e 300 kg');
          return false;
        }
        if (_height! < 120 || _height! > 230) {
          _showError('Informe uma altura entre 120 e 230 cm');
          return false;
        }
        return true;
      case 2: // Atividade
        if (_activityLevel == null) {
          _showError('Selecione seu nível de atividade');
          return false;
        }
        return true;
      case 3: // Objetivo
        if (_goal == null) {
          _showError('Selecione seu objetivo');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: context.colors.coral),
    );
  }

  Future<void> _calculateAndSaveGoals() async {
    if (!_validateCurrentPage()) return;
    if (_sex == null ||
        _age == null ||
        _weight == null ||
        _height == null ||
        _activityLevel == null ||
        _goal == null) {
      _showError('Complete todos os passos para continuar');
      return;
    }

    final activityLevel = ActivityLevel.fromString(_activityLevel!);
    final goal = Goal.fromString(_goal!);

    final goals = GoalCalculator.calculateAll(
      sex: _sex!,
      age: _age!,
      weight: _weight!,
      height: _height!,
      activityLevel: activityLevel,
      goal: goal,
    );

    final profile = UserProfileData(
      id: 1,
      sex: _sex!,
      age: _age!,
      weight: _weight!,
      height: _height!,
      activityLevel: _activityLevel!,
      goal: _goal!,
      kcal: goals.kcal,
      protein: goals.protein,
      carbs: goals.carbs,
      fat: goals.fat,
      updatedAt: DateTime.now(),
    );

    await ref.read(userProfileRepositoryProvider).save(profile);
    if (!mounted) return;
    ref.invalidate(userProfileProvider);
    if (widget.isEditing) {
      Navigator.of(context).pop();
    }
    // Sem edição, a tela raiz observa o perfil e troca para o app sozinha.
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.cream,
      body: SafeArea(
        child: Column(
          children: [
            // Indicador de progresso
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: List.generate(_pages.length, (index) {
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 4,
                      margin: EdgeInsets.symmetric(horizontal: index == 0 ? 0 : 4),
                      decoration: BoxDecoration(
                        color: index <= _currentPage
                            ? context.colors.green
                            : context.colors.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Conteúdo das páginas
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildWelcomePage(),
                  _buildPersonalDataPage(),
                  _buildActivityPage(),
                  _buildGoalPage(),
                  _buildGoalsPreviewPage(),
                ],
              ),
            ),

            // Botões de navegação
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousPage,
                        child: const Text('Voltar'),
                      ),
                    )
                  else
                    const Expanded(child: SizedBox.shrink()),
                  if (_currentPage > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _currentPage == _pages.length - 1
                          ? _calculateAndSaveGoals
                          : _nextPage,
                      child: Text(_currentPage == _pages.length - 1
                          ? 'Começar'
                          : 'Avançar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: context.colors.greenSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.restaurant_menu, size: 60, color: context.colors.green),
          ),
          const SizedBox(height: 32),
          Text(
            'Bem-vindo ao Nutria',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: context.colors.ink,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Seu diário de alimentação inteligente.\nRegistre, acompanhe e evolua.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.colors.muted,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalDataPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sobre você', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Esses dados são usados para calcular seu gasto calórico basal (Mifflin-St Jeor).',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: context.colors.muted),
          ),
          const SizedBox(height: 24),

          // Sexo
          Text('Sexo biológico',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SexOption(
                  label: 'Masculino',
                  icon: Icons.male,
                  selected: _sex == 'masculino',
                  onTap: () => setState(() => _sex = 'masculino'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SexOption(
                  label: 'Feminino',
                  icon: Icons.female,
                  selected: _sex == 'feminino',
                  onTap: () => setState(() => _sex = 'feminino'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Idade e Peso
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  label: 'Idade',
                  controller: _ageController,
                  hint: 'anos',
                  onChanged: (v) => _age = int.tryParse(v),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberField(
                  label: 'Peso',
                  controller: _weightController,
                  hint: 'kg',
                  onChanged: (v) =>
                      _weight = double.tryParse(v.replaceAll(',', '.')),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d,]')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NumberField(
            label: 'Altura',
            controller: _heightController,
            hint: 'cm',
            onChanged: (v) => _height = int.tryParse(v),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityPage() {
    final levels = ActivityLevel.values;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nível de atividade', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Selecione a opção que melhor descreve sua rotina.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.muted),
          ),
          const SizedBox(height: 24),
          ...levels.map((level) => _ActivityOption(
            level: level,
            selected: _activityLevel == level.name,
            onTap: () => setState(() => _activityLevel = level.name),
          )),
        ],
      ),
    );
  }

  Widget _buildGoalPage() {
    final goals = Goal.values;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Qual seu objetivo?', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Isso define o ajuste calórico nas suas metas.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.muted),
          ),
          const SizedBox(height: 24),
          ...goals.map((goal) => _GoalOption(
            goal: goal,
            selected: _goal == goal.name,
            onTap: () => setState(() => _goal = goal.name),
          )),
        ],
      ),
    );
  }

  Widget _buildGoalsPreviewPage() {
    if (_sex == null || _age == null || _weight == null || _height == null ||
        _activityLevel == null || _goal == null) {
      return const Center(child: Text('Complete os passos anteriores'));
    }

    final activityLevel = ActivityLevel.fromString(_activityLevel!);
    final goal = Goal.fromString(_goal!);
    final goals = GoalCalculator.calculateAll(
      sex: _sex!,
      age: _age!,
      weight: _weight!,
      height: _height!,
      activityLevel: activityLevel,
      goal: goal,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Suas metas calculadas', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Baseado na fórmula de Mifflin-St Jeor × fator de atividade + ajuste do objetivo.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.muted),
          ),
          const SizedBox(height: 24),

          _GoalPreviewCard(
            label: 'Calorias',
            value: goals.kcal.toStringAsFixed(0),
            unit: 'kcal',
            color: context.colors.green,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _GoalPreviewCard(
                  label: 'Proteína',
                  value: goals.protein.toStringAsFixed(1),
                  unit: 'g',
                  color: context.colors.protein,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GoalPreviewCard(
                  label: 'Carboidrato',
                  value: goals.carbs.toStringAsFixed(1),
                  unit: 'g',
                  color: context.colors.carbs,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _GoalPreviewCard(
            label: 'Gordura',
            value: goals.fat.toStringAsFixed(1),
            unit: 'g',
            color: context.colors.fat,
          ),

          const SizedBox(height: 24),
          Text(
            'Você pode ajustar esses valores na aba Perfil depois.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final String title;
  final String subtitle;
  final IconData icon;

  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _SexOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SexOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: selected ? context.colors.greenSoft : context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? context.colors.green : context.colors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: selected ? context.colors.green : context.colors.muted),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: selected ? context.colors.green : context.colors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final List<TextInputFormatter>? inputFormatters;

  const _NumberField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            suffixText: hint,
          ),
        ),
      ],
    );
  }
}

class _ActivityOption extends StatelessWidget {
  final ActivityLevel level;
  final bool selected;
  final VoidCallback onTap;

  const _ActivityOption({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? context.colors.greenSoft : context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? context.colors.green : context.colors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected ? context.colors.green : context.colors.line,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.directions_run,
                  color: selected ? context.colors.onGreen : context.colors.muted,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected ? context.colors.green : context.colors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      level.description,
                      style: theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: context.colors.green, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalOption extends StatelessWidget {
  final Goal goal;
  final bool selected;
  final VoidCallback onTap;

  const _GoalOption({
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? context.colors.greenSoft : context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? context.colors.green : context.colors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected ? context.colors.green : context.colors.line,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  goal == Goal.perder
                      ? Icons.trending_down
                      : goal == Goal.manter
                          ? Icons.balance
                          : Icons.trending_up,
                  color: selected ? context.colors.onGreen : context.colors.muted,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected ? context.colors.green : context.colors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      goal.description,
                      style: theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: context.colors.green, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalPreviewCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _GoalPreviewCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color.withValues(alpha: 0.7),
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