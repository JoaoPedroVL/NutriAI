import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import '../core/theme.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/shell/home_shell.dart';

// Import condicional para web
import 'app_web.dart' if (dart.library.io) 'app_mobile.dart';

class NutriaApp extends ConsumerWidget {
  const NutriaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seed = ref.watch(seedProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'NutriAI',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildDarkAppTheme(),
      themeMode: themeMode,
      // No desktop/web mantém a largura de um celular, centralizado.
      builder: (context, child) => ColoredBox(
        color: context.colors.cream,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: child,
          ),
        ),
      ),
      home: switch (seed) {
        AsyncData() => const _RootGate(),
        AsyncError(:final error) => _StartupError(error: error),
        _ => const _Splash(),
      },
    );
  }
}

/// Decide entre onboarding (primeira abertura) e o app.
class _RootGate extends ConsumerWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);

    if (profile.isLoading && !profile.hasValue) {
      return const _Splash();
    }

    // Falha ao ler o perfil não deve travar o app.
    if (profile.hasError) return const HomeShell();

    return profile.value == null
        ? const OnboardingScreen()
        : const HomeShell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco, size: 56, color: context.colors.green),
            const SizedBox(height: 16),
            const Text('Preparando seu diário…'),
            const SizedBox(height: 16),
            const SizedBox(
              width: 120,
              child: LinearProgressIndicator(minHeight: 4),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartupError extends ConsumerStatefulWidget {
  const _StartupError({required this.error});

  final Object error;

  @override
  ConsumerState<_StartupError> createState() => _StartupErrorState();
}

class _StartupErrorState extends ConsumerState<_StartupError> {
  bool _resetting = false;
  String? _resetError;

  Future<void> _resetDatabase() async {
    setState(() {
      _resetting = true;
      _resetError = null;
    });

    try {
      await resetDatabaseAndReload();
      if (!mounted) return;
      // Recarrega a página
      reloadPage();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resetting = false;
        _resetError = 'Erro ao resetar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorText = widget.error.toString();

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: context.colors.coral),
              const SizedBox(height: 12),
              const Text(
                'Não foi possível iniciar o banco local.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colors.line),
                ),
                child: SelectableText(
                  errorText,
                  textAlign: TextAlign.left,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: context.colors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_resetError != null) ...[
                Text(
                  _resetError!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: context.colors.coral),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                onPressed: _resetting ? null : _resetDatabase,
                icon: _resetting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: context.colors.onGreen,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 20),
                label: Text(_resetting ? 'Resetando…' : 'Resetar banco (apaga dados)'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: reloadPage,
                child: const Text('Recarregar página'),
              ),
              const SizedBox(height: 8),
              Text(
                'Isso apaga TODOS os dados locais (diário, metas, rascunhos, cache de produtos escaneados).',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}