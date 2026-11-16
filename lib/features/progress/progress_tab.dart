import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design_tokens.dart';
import '../../core/text.dart';
import '../../core/theme.dart';
import '../../core/user_profile.dart';
import '../../data/db/database.dart';
import '../../shared/widgets/app_card.dart';
import '../onboarding/onboarding_screen.dart';

String _weekday(DateTime date) {
  const labels = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
  return labels[(date.weekday - 1).clamp(0, 6)];
}

/// Aba "Progresso": peso, calorias e resumo dos últimos dias.
class ProgressTab extends ConsumerWidget {
  const ProgressTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final weights = ref.watch(weightLogsProvider);
    final entries = ref.watch(progressEntriesProvider);
    final goals = ref.watch(goalsProvider);

    if (profile.isLoading && !profile.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = profile.value;
    if (data == null) {
      return _NoProfile(onStart: () => _openOnboarding(context));
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userProfileProvider);
        ref.invalidate(weightLogsProvider);
        ref.invalidate(progressEntriesProvider);
        ref.invalidate(goalsProvider);
      },
      child: _ProgressBody(
        profile: data,
        weights: weights.value ?? const <WeightLog>[],
        entries: entries.value ?? const <DiaryEntry>[],
        goals: goals.value ?? NutritionGoals.defaults,
        onOpenOnboarding: () => _openOnboarding(context),
      ),
    );
  }

  static Future<void> _openOnboarding(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const OnboardingScreen(isEditing: true),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.onEditProfile});

  final VoidCallback onEditProfile;

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
              Text('Progresso', style: theme.textTheme.headlineMedium),
              SizedBox(height: AppSpacing.xs),
              Text(
                'Acompanhe sua evolução',
                style: theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Editar perfil',
          onPressed: onEditProfile,
          icon: Icon(Icons.edit_outlined, color: context.colors.green),
        ),
      ],
    );
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

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final _Stats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Média (7 dias)',
            value: '${stats.averageKcal.round()} kcal',
            icon: Icons.local_fire_department_rounded,
            color: context.colors.green,
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(
            label: 'Dias na meta',
            value: '${stats.daysOnGoal}/${stats.recordedDays}',
            icon: Icons.check_circle_outline_rounded,
            color: context.colors.protein,
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(
            label: 'Sequência',
            value: '${stats.streak} ${stats.streak == 1 ? 'dia' : 'dias'}',
            icon: Icons.bolt_rounded,
            color: context.colors.coral,
          ),
        ),
      ],
    );
  }
}

class _NoProfile extends StatelessWidget {
  const _NoProfile({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: context.colors.greenSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.insights_rounded,
                  size: 44,
                  color: context.colors.green,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Seu progresso começa aqui',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Configure seu perfil para calcular metas e acompanhar peso, '
                'calorias e sequência de dias.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.colors.muted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.tune_rounded, size: 20),
                label: const Text('Configurar meu perfil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBody extends ConsumerWidget {
  const _ProgressBody({
    required this.profile,
    required this.weights,
    required this.entries,
    required this.goals,
    required this.onOpenOnboarding,
  });

  final UserProfileData profile;
  final List<WeightLog> weights;
  final List<DiaryEntry> entries;
  final NutritionGoals goals;
  final VoidCallback onOpenOnboarding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = startOfDay(DateTime.now());
    final sortedWeights = [...weights]..sort((a, b) => a.day.compareTo(b.day));
    final totals = _totalsByDay(entries);
    final stats = _buildStats(today, totals);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: [
        _ProgressHeader(
          onEditProfile: onOpenOnboarding,
        ),
        SizedBox(height: AppSpacing.lg),
        _WeightCard(
          profileWeight: profile.weight,
          latestWeight: sortedWeights.isEmpty ? null : sortedWeights.last.weight,
          firstWeight: sortedWeights.isEmpty ? null : sortedWeights.first.weight,
          onRegister: () => _showWeightSheet(context, ref),
        ),
        SizedBox(height: AppSpacing.xl),
        _SectionHeaderWithSpacing(title: 'Evolução do peso'),
        _WeightChart(
          logs: sortedWeights,
          onRegister: () => _showWeightSheet(context, ref),
        ),
        SizedBox(height: AppSpacing.xl),
        _SectionHeaderWithSpacing(title: 'Calorias'),
        _CaloriesCard(
          totals: totals,
          goal: goals.kcal,
        ),
        SizedBox(height: AppSpacing.xl),
        _SectionHeaderWithSpacing(title: 'Resumo'),
        _StatsRow(stats: stats),
      ],
    );
  }

  Map<String, double> _totalsByDay(List<DiaryEntry> list) {
    final map = <String, double>{};
    for (final entry in list) {
      final key = dayKey(entry.day);
      map[key] = (map[key] ?? 0) + entry.kcal;
    }
    return map;
  }

  _Stats _buildStats(DateTime today, Map<String, double> totals) {
    var average = 0.0;
    var averageDays = 0;
    var onGoal = 0;
    var recorded = 0;

    for (var i = 0; i < 30; i++) {
      final day = today.subtract(Duration(days: i));
      final kcal = totals[dayKey(day)] ?? 0;
      if (kcal <= 0) continue;
      recorded++;
      if ((kcal - goals.kcal).abs() <= goals.kcal * 0.1) onGoal++;
      if (i < 7) {
        average += kcal;
        averageDays++;
      }
    }

    var streak = 0;
    for (var i = 0; i < 30; i++) {
      final day = today.subtract(Duration(days: i));
      final kcal = totals[dayKey(day)] ?? 0;
      if (kcal > 0) {
        streak++;
      } else if (i == 0) {
        // Hoje ainda pode ser preenchido; a sequência de ontem continua válida.
        continue;
      } else {
        break;
      }
    }

    return _Stats(
      averageKcal: averageDays == 0 ? 0 : average / averageDays,
      daysOnGoal: onGoal,
      recordedDays: recorded,
      streak: streak,
    );
  }

  Future<void> _showWeightSheet(BuildContext context, WidgetRef ref) async {
    final latest = weights.isEmpty ? profile.weight : weights.first.weight;
    final value = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WeightSheet(initialWeight: latest),
    );
    if (value == null) return;
    await ref.read(weightRepositoryProvider).upsert(DateTime.now(), value);
    ref.invalidate(weightLogsProvider);
  }
}

class _WeightCard extends StatelessWidget {
  const _WeightCard({
    required this.profileWeight,
    required this.latestWeight,
    required this.firstWeight,
    required this.onRegister,
  });

  final double? profileWeight;
  final double? latestWeight;
  final double? firstWeight;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = (latestWeight != null && firstWeight != null)
        ? latestWeight! - firstWeight!
        : null;

    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: context.colors.greenSoft,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(
                  Icons.monitor_weight_outlined,
                  color: context.colors.green,
                  size: AppIconSize.lg,
                ),
              ),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Peso atual',
                      style: theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      latestWeight == null
                          ? (profileWeight == null
                              ? 'Não registrado'
                              : '${_kg(profileWeight!)} kg')
                          : '${_kg(latestWeight!)} kg',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.colors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (delta != null && delta.abs() >= 0.05)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: delta < 0
                        ? context.colors.greenSoft
                        : context.colors.coralSoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${delta < 0 ? '−' : '+'}${_kg(delta.abs())} kg',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: delta < 0 ? context.colors.green : context.colors.coral,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: Semantics(
              button: true,
              label: 'Registrar peso de hoje',
              child: OutlinedButton.icon(
                onPressed: onRegister,
                icon: const Icon(Icons.add_rounded, size: AppIconSize.md),
                label: const Text('Registrar peso de hoje'),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.fromHeight(AppTouchTarget.minSize),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _kg(double value) => value
      .toStringAsFixed(1)
      .replaceAll('.', ',')
      .replaceAll(RegExp(r',0$'), '');
}

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.logs, required this.onRegister});

  final List<WeightLog> logs;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return _EmptyCard(
        icon: Icons.monitor_weight_outlined,
        title: 'Sem registros de peso',
        message: 'Registre seu peso para ver a evolução ao longo do tempo.',
        action: FilledButton.icon(
          onPressed: onRegister,
          icon: const Icon(Icons.add_rounded, size: AppIconSize.md),
          label: const Text('Registrar agora'),
        ),
      );
    }

    final recent = logs.length > 30 ? logs.sublist(logs.length - 30) : logs;
    final spots = <FlSpot>[
      for (var i = 0; i < recent.length; i++)
        FlSpot(i.toDouble(), recent[i].weight),
    ];
    final values = recent.map((e) => e.weight);
    final minY = values.reduce((a, b) => a < b ? a : b) - 1;
    final maxY = values.reduce((a, b) => a > b ? a : b) + 1;

    return AppCard(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: SizedBox(
        height: AppChart.height,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (recent.length - 1).toDouble(),
            minY: minY.floorToDouble(),
            maxY: maxY.ceilToDouble(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: context.colors.line, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: 1,
                  getTitlesWidget: (value, _) => Text(
                    value.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 10,
                      color: context.colors.muted,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  interval: 1,
                  getTitlesWidget: (value, _) {
                    final index = value.round();
                    if (index < 0 || index >= recent.length) {
                      return const SizedBox.shrink();
                    }
                    final show = recent.length <= 7 ||
                        index == 0 ||
                        index == recent.length - 1 ||
                        index == recent.length ~/ 2;
                    if (!show) return const SizedBox.shrink();
                    final date = recent[index].day;
                    return Text(
                      '${date.day}/${date.month}',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.colors.muted,
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: recent.length > 2,
                curveSmoothness: 0.2,
                barWidth: 3,
                color: context.colors.green,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: recent.length <= 15,
                  getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                    radius: 3.5,
                    color: context.colors.green,
                    strokeWidth: 2,
                    strokeColor: context.colors.surface,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: context.colors.green.withValues(alpha: 0.10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaloriesCard extends StatefulWidget {
  const _CaloriesCard({required this.totals, required this.goal});

  final Map<String, double> totals;
  final double goal;

  @override
  State<_CaloriesCard> createState() => _CaloriesCardState();
}

class _CaloriesCardState extends State<_CaloriesCard> {
  int _range = 7;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = [
      for (var i = _range - 1; i >= 0; i--)
        startOfDay(DateTime.now()).subtract(Duration(days: i)),
    ];
    final values = [for (final d in days) widget.totals[dayKey(d)] ?? 0];
    final rawMax =
        [widget.goal, ...values].reduce((a, b) => a > b ? a : b) * 1.12;
    final interval = rawMax > 2500
        ? 1000.0
        : rawMax > 1200
            ? 500.0
            : 250.0;
    final maxValue = (rawMax / interval).ceil() * interval;

    return AppCard(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CaloriesHeader(range: _range, onRangeChanged: (v) => setState(() => _range = v)),
          SizedBox(height: AppSpacing.lg),
          _CaloriesChart(
            days: days,
            values: values,
            goal: widget.goal,
            maxValue: maxValue,
            interval: interval,
            range: _range,
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            'Barras vermelhas passaram da meta de ${widget.goal.round()} kcal.',
            style: theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
          ),
        ],
      ),
    );
  }
}

class _CaloriesHeader extends StatelessWidget {
  const _CaloriesHeader({
    required this.range,
    required this.onRangeChanged,
  });

  final int range;
  final ValueChanged<int> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            range == 7 ? 'Últimos 7 dias' : 'Últimos 30 dias',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        _RangeToggle(value: range, onChanged: onRangeChanged),
      ],
    );
  }
}

class _CaloriesChart extends StatelessWidget {
  const _CaloriesChart({
    required this.days,
    required this.values,
    required this.goal,
    required this.maxValue,
    required this.interval,
    required this.range,
  });

  final List<DateTime> days;
  final List<double> values;
  final double goal;
  final double maxValue;
  final double interval;
  final int range;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppChart.height,
      child: BarChart(
        BarChartData(
          maxY: maxValue,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: context.colors.line, strokeWidth: 1),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: goal,
                color: context.colors.coral,
                strokeWidth: 2,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: EdgeInsets.only(right: AppSpacing.xs, bottom: AppSpacing.xs),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.colors.coral,
                  ),
                  labelResolver: (_) => 'meta',
                ),
              ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: interval,
                getTitlesWidget: (value, _) => Text(
                  value >= 1000
                      ? '${(value / 1000).toStringAsFixed(1)}k'
                      : value.round().toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: context.colors.muted,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (value, _) {
                  final index = value.round();
                  if (index < 0 || index >= days.length) {
                    return const SizedBox.shrink();
                  }
                  if (range == 30 &&
                      index != 0 &&
                      index != days.length - 1 &&
                      index % 7 != 0) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    range == 7
                        ? _weekday(days[index])
                        : '${days[index].day}/${days[index].month}',
                    style: TextStyle(
                      fontSize: 9,
                      color: context.colors.muted,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < days.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i],
                    width: range == 7 ? 16 : 5,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                    color: values[i] > goal * 1.05
                        ? context.colors.coral
                        : context.colors.green,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: value == 7 ? 'Últimos 7 dias selecionados' : 'Últimos 30 dias selecionados',
      button: true,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: context.colors.cream,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in const [7, 30])
              _RangeToggleOption(
                value: option,
                selected: value == option,
                onTap: () => onChanged(option),
              ),
          ],
        ),
      ),
    );
  }
}

class _RangeToggleOption extends StatelessWidget {
  const _RangeToggleOption({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: AnimatedContainer(
          duration: AppAnimation.fast,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? context.colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            '$value d',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? context.colors.green : context.colors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $value',
      child: AppCard(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: color, size: AppIconSize.md),
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              value,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.colors.muted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$title. $message',
      child: AppCard(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          children: [
            Icon(icon, size: AppIconSize.xl, color: context.colors.muted),
            SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _WeightSheet extends StatefulWidget {
  const _WeightSheet({this.initialWeight});

  final double? initialWeight;

  @override
  State<_WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends State<_WeightSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialWeight == null
        ? ''
        : widget.initialWeight!.toStringAsFixed(1).replaceAll('.', ','),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = parseNumber(_controller.text);
    if (value == null || value < 20 || value > 400) {
      setState(() => _error = 'Informe um peso válido (20–400 kg).');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
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
            const SizedBox(height: 18),
            Text(
              'Registrar peso de hoje',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Um registro por dia. O valor de hoje substitui o anterior.',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              autofocus: true,
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: '0,0',
                suffixText: 'kg',
                errorText: _error,
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              child: const Text('Salvar peso'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stats {
  const _Stats({
    required this.averageKcal,
    required this.daysOnGoal,
    required this.recordedDays,
    required this.streak,
  });

  final double averageKcal;
  final int daysOnGoal;
  final int recordedDays;
  final int streak;
}