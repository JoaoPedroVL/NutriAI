import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

import '../../app/providers.dart';
import '../../core/app_info.dart';
import '../../core/theme.dart';
import '../../core/user_profile.dart';
import '../../data/db/database.dart' show UserProfileData;
import '../../data/services/notification_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/metric_tile.dart';
import '../goals/goals_dialog.dart';
import '../onboarding/onboarding_screen.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final goals = ref.watch(goalsProvider).value ?? NutritionGoals.defaults;
    final foods = ref.watch(_foodCountProvider).value;
    final entries = ref.watch(_entryCountProvider).value;
    final profile = ref.watch(userProfileProvider).value;
    final themeMode = ref.watch(themeModeProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          Text('Perfil', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Suas metas e preferências',
            style: theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
          ),
          const SizedBox(height: 18),
          _ProfileCard(foods: foods, entries: entries),
          const SizedBox(height: 22),
          SectionHeader(
            title: 'Seu perfil',
            action: 'Editar',
            onAction: () => _openOnboarding(context, ref),
          ),
          const SizedBox(height: 10),
          if (profile == null)
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    color: context.colors.green,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete seu perfil para calcular metas personalizadas.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: context.colors.muted),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _openOnboarding(context, ref),
                    child: const Text('Configurar agora'),
                  ),
                ],
              ),
            )
          else
            _UserProfileCard(profile: profile),
          const SizedBox(height: 22),
          SectionHeader(
            title: 'Metas diárias',
            action: 'Editar',
            onAction: () => showDialog<void>(
              context: context,
              builder: (_) => const GoalsDialog(),
            ),
          ),
          const SizedBox(height: 10),
          _GoalsCard(goals: goals),
          const SizedBox(height: 22),
          SectionHeader(title: 'Aparência'),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _ThemeModeTile(
                  currentMode: themeMode,
                  onChanged: (mode) =>
                      ref.read(themeModeProvider.notifier).setThemeMode(mode),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          SectionHeader(title: 'Notificações'),
          const SizedBox(height: 10),
          _NotificationsCard(),
          const SizedBox(height: 22),
          SectionHeader(title: 'Backup e Dados'),
          const SizedBox(height: 10),
          _BackupCard(),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Sobre o Nutria'),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: const [
                _InfoRow(
                  icon: Icons.shield_rounded,
                  title: 'Seus dados ficam com você',
                  subtitle: 'Tudo salvo no aparelho, sem conta e sem nuvem.',
                ),
                _InfoRow(
                  icon: Icons.menu_book_rounded,
                  title: 'Tabela TACO 4ª edição',
                  subtitle: 'Valores por 100 g de parte comestível.',
                ),
                _InfoRow(
                  icon: Icons.eco_rounded,
                  title: 'Nutria $appVersion',
                  subtitle: 'Diário de bolso, feito para não perder nada.',
                  showDivider: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final _foodCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT COUNT(*) AS c FROM foods',
        readsFrom: {db.foods},
      )
      .watchSingle()
      .map((row) => row.read<int>('c'));
});

final _entryCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT COUNT(*) AS c FROM diary_entries',
        readsFrom: {db.diaryEntries},
      )
      .watchSingle()
      .map((row) => row.read<int>('c'));
});

Future<void> _openOnboarding(BuildContext context, WidgetRef ref) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const OnboardingScreen(isEditing: true),
    ),
  );
  ref.invalidate(userProfileProvider);
}

/// Card do modo de tema (claro/escuro/sistema).
class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
    required this.currentMode,
    required this.onChanged,
  });

  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<ThemeMode>(
      groupValue: currentMode,
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
      child: Column(
        children: [
          for (final mode in ThemeMode.values)
            RadioListTile<ThemeMode>(
              title: Text(_modeLabel(mode)),
              value: mode,
              activeColor: context.colors.green,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              dense: true,
            ),
        ],
      ),
    );
  }

  String _modeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '☀️ Claro';
      case ThemeMode.dark:
        return '🌙 Escuro';
      case ThemeMode.system:
        return '📱 Sistema';
    }
  }
}

/// Card de notificações.
class _NotificationsCard extends ConsumerWidget {
  const _NotificationsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notificationService = ref.watch(notificationServiceProvider);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.proteinSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.notifications_rounded, color: context.colors.protein, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lembretes', style: theme.textTheme.titleMedium),
                    Text(
                      'Configure avisos para refeições, peso e água',
                      style: theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Lembretes de refeições'),
            subtitle: const Text('Receba avisos nos horários das refeições'),
            value: true,
            onChanged: (value) async {
              if (value) {
                await notificationService.rescheduleAll(
                  profile: UserProfile(
                    sex: 'masculino',
                    age: 25,
                    weight: 70,
                    height: 175,
                    activityLevel: 'moderado',
                    goal: 'manter',
                    kcal: 2000,
                    protein: 150,
                    carbs: 250,
                    fat: 65,
                  ),
                  goals: NutritionGoals.defaults,
                  mealSettings: {
                    'Café da manhã': const MealReminderSettings(id: 1, hour: 8, minute: 0),
                    'Almoço': const MealReminderSettings(id: 2, hour: 12, minute: 30),
                    'Jantar': const MealReminderSettings(id: 3, hour: 19, minute: 30),
                    'Lanche': const MealReminderSettings(id: 4, hour: 16, minute: 0),
                  },
                  weightSettings: const WeightReminderSettings(hour: 7, minute: 0),
                  waterSettings: const WaterReminderSettings(),
                );
              } else {
                await notificationService.cancelAll();
              }
            },
            activeThumbColor: context.colors.green,
          ),
          SwitchListTile(
            title: const Text('Lembrete de peso'),
            subtitle: const Text('Aviso diário para registrar o peso'),
            value: true,
            onChanged: (value) async {
              if (!value) {
                await notificationService.cancel(100);
              }
            },
            activeThumbColor: context.colors.green,
          ),
          SwitchListTile(
            title: const Text('Lembretes de água'),
            subtitle: const Text('Avisos a cada 2h para beber água'),
            value: true,
            onChanged: (value) async {
              if (value) {
                await notificationService.scheduleWaterReminder(
                  intervalMinutes: 120,
                  startHour: 8,
                  endHour: 20,
                );
              } else {
                for (int i = 200; i < 300; i++) {
                  await notificationService.cancel(i);
                }
              }
            },
            activeThumbColor: context.colors.green,
          ),
        ],
      ),
    );
  }
}

/// Card de backup e exportação.
class _BackupCard extends ConsumerWidget {
  const _BackupCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backupService = ref.watch(backupServiceProvider);
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.fatSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.backup_rounded, color: context.colors.fat, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Backup e Exportação', style: theme.textTheme.titleMedium),
                    Text(
                      'Exporte seus dados ou restaure um backup',
                      style: theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await backupService.exportAndShare();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Backup exportado com sucesso!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao exportar: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Exportar Backup (JSON)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.green,
                    side: BorderSide(color: context.colors.green),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await backupService.importFromFile();
                      ref.invalidate(userProfileProvider);
                      ref.invalidate(weightLogsProvider);
                      ref.invalidate(savedMealsProvider);
                      ref.invalidate(favoritesProvider);
                      ref.invalidate(recentFoodsProvider);
                      ref.invalidate(todayWaterProvider);
                      ref.invalidate(todayWaterLogsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Backup importado com sucesso!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao importar: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.upload_rounded, size: 18),
                  label: const Text('Importar Backup'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.carbs,
                    side: BorderSide(color: context.colors.carbs),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await _exportCsv(context, ref);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao exportar CSV: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.table_chart_rounded, size: 18),
                  label: const Text('Exportar CSV (Diário)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.protein,
                    side: BorderSide(color: context.colors.protein),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final diaryRepo = ref.read(diaryRepositoryProvider);
    final entries = await diaryRepo.getAllEntries();

    if (entries.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum registro para exportar')),
        );
      }
      return;
    }

    final csvData = <List<String>>[
      ['Data', 'Refeição', 'Alimento', 'Quantidade (g)', 'kcal', 'Proteína (g)', 'Carboidrato (g)', 'Gordura (g)'],
    ];

    for (final entry in entries) {
      final dateStr = '${entry.day.day.toString().padLeft(2, '0')}/${entry.day.month.toString().padLeft(2, '0')}/${entry.day.year}';
      csvData.add([
        dateStr,
        entry.meal,
        entry.foodName,
        entry.grams.toStringAsFixed(1),
        entry.kcal.toStringAsFixed(1),
        entry.protein.toStringAsFixed(1),
        entry.carbs.toStringAsFixed(1),
        entry.fat.toStringAsFixed(1),
      ]);
    }

    final csv = const CsvEncoder().convert(csvData);
    final tempDir = await getTemporaryDirectory();
    final fileName = 'nutria_diario_${DateTime.now().toIso8601String().split('T').first}.csv';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(csv);

    await Share.shareXFiles([XFile(file.path)], text: 'Exportação do diário Nutria (CSV)');
  }
}

/// Perfil do usuário (card detalhado).
class _UserProfileCard extends ConsumerWidget {
  const _UserProfileCard({required this.profile});

  final UserProfileData profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activity = profile.activityLevel == null
        ? '—'
        : ActivityLevel.fromString(profile.activityLevel!).label;
    final goal =
        profile.goal == null ? '—' : Goal.fromString(profile.goal!).label;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          _ProfileRow(
            icon: Icons.wc_rounded,
            label: 'Sexo',
            value: profile.sex == 'masculino'
                ? 'Masculino'
                : profile.sex == 'feminino'
                    ? 'Feminino'
                    : '—',
          ),
          Divider(height: 18, color: context.colors.line),
          _ProfileRow(
            icon: Icons.cake_outlined,
            label: 'Idade',
            value: profile.age == null ? '—' : '${profile.age} anos',
          ),
          Divider(height: 18, color: context.colors.line),
          _ProfileRow(
            icon: Icons.straighten_rounded,
            label: 'Altura',
            value: profile.height == null ? '—' : '${profile.height} cm',
          ),
          Divider(height: 18, color: context.colors.line),
          _ProfileRow(
            icon: Icons.monitor_weight_outlined,
            label: 'Peso inicial',
            value: profile.weight == null
                ? '—'
                : '${profile.weight!.toStringAsFixed(1).replaceAll('.', ',')} kg',
          ),
          Divider(height: 18, color: context.colors.line),
          _ProfileRow(
            icon: Icons.directions_run_rounded,
            label: 'Atividade',
            value: activity,
          ),
          Divider(height: 18, color: context.colors.line),
          _ProfileRow(
            icon: Icons.flag_outlined,
            label: 'Objetivo',
            value: goal,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openOnboarding(context, ref),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Editar dados e recalcular metas'),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'As metas são recalculadas ao salvar. Ajustes manuais podem ser '
            'feitos em "Metas diárias".',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.foods, required this.entries});

  final int? foods;
  final int? entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.colors.greenSoft,
                  shape: BoxShape.circle,
                ),
                child: const Text('🥗', style: TextStyle(fontSize: 27)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Meu diário', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      'Local, privado e sempre com você',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: context.colors.muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: context.colors.greenSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'OFFLINE',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: context.colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: context.colors.cream,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _Stat(
                    value: foods == null ? '—' : '$foods',
                    label: 'alimentos',
                  ),
                ),
                Container(width: 1, height: 30, color: context.colors.line),
                Expanded(
                  child: _Stat(
                    value: entries == null ? '—' : '$entries',
                    label: 'registros',
                  ),
                ),
                Container(width: 1, height: 30, color: context.colors.line),
                const Expanded(
                  child: _Stat(value: '4ª ed.', label: 'TACO'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
        ),
      ],
    );
  }
}

class _GoalsCard extends StatelessWidget {
  const _GoalsCard({required this.goals});

  final NutritionGoals goals;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'kcal por dia',
                  value: goals.kcal.toStringAsFixed(0),
                  color: context.colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  label: 'Proteína',
                  value: '${goals.protein.toStringAsFixed(0)} g',
                  color: context.colors.protein,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'Carboidrato',
                  value: '${goals.carbs.toStringAsFixed(0)} g',
                  color: context.colors.carbs,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  label: 'Gordura',
                  value: '${goals.fat.toStringAsFixed(0)} g',
                  color: context.colors.fat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: context.colors.green),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.colors.greenSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 20, color: context.colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: context.colors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: context.colors.line),
      ],
    );
  }
}