import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/providers.dart';
import '../../core/meals.dart';
import '../../core/food_style.dart';
import '../../core/text.dart';
import '../../core/theme.dart';
import '../../data/db/database.dart';
import '../../data/remote/open_food_facts.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/food_avatar.dart';
import '../../shared/widgets/metric_tile.dart';
import '../add_food/add_food_screen.dart';

/// Abre o leitor de código de barras para uma refeição.
Future<void> openBarcodeScanner(
  BuildContext context, {
  required DateTime day,
  required String meal,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BarcodeScanScreen(day: day, meal: meal),
    ),
  );
}

class BarcodeScanScreen extends ConsumerStatefulWidget {
  const BarcodeScanScreen({
    super.key,
    required this.day,
    required this.meal,
    this.enableCamera,
  });

  final DateTime day;
  final String meal;

  /// Força a câmera ligada/desligada. `null` decide pelo dispositivo
  /// (câmera ligada só em Android/iOS; navegador começa no modo manual).
  final bool? enableCamera;

  @override
  ConsumerState<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends ConsumerState<BarcodeScanScreen> {
  final _manual = TextEditingController();
  MobileScannerController? _controller;
  bool _cameraEnabled = false;
  bool _busy = false;
  String? _error;
  Food? _found;
  String? _barcode;

  static const _barcodeFormats = [
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
    BarcodeFormat.code128,
    BarcodeFormat.code39,
    BarcodeFormat.itf14,
  ];

  @override
  void initState() {
    super.initState();
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    _cameraEnabled = widget.enableCamera ?? (!kIsWeb && isMobile);
    if (_cameraEnabled) {
      _controller = _createController();
    }
  }

  @override
  void dispose() {
    _manual.dispose();
    _controller?.dispose();
    super.dispose();
  }

  MobileScannerController _createController() => MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: _barcodeFormats,
      );

  void _enableCamera() {
    setState(() {
      _cameraEnabled = true;
      _controller ??= _createController();
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy || _found != null) return;
    if (capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    _lookup(code);
  }

  Future<void> _lookup(String raw) async {
    final code = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (!isValidGtin(code)) {
      setState(() {
        _error = 'Código de barras inválido (dígito verificador).';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _barcode = code;
    });

    try {
      final repository = ref.read(foodRepositoryProvider);
      var food = await repository.byBarcode(code);
      if (food == null) {
        final product = await ref.read(offServiceProvider).lookup(code);
        food = await repository.saveOffProduct(product);
      }
      if (!mounted) return;
      setState(() {
        _found = food;
        _busy = false;
      });
      await _controller?.stop();
    } on OffException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Algo deu errado ao buscar o produto. Tente de novo.';
        _busy = false;
      });
    }
  }

  void _scanAnother() {
    setState(() {
      _found = null;
      _error = null;
      _barcode = null;
      _manual.clear();
    });
    _resumeCamera();
  }

  Future<void> _resumeCamera() async {
    if (!_cameraEnabled) return;
    try {
      _controller ??= _createController();
      await _controller!.start();
    } catch (_) {
      // Sem câmera: o campo manual continua disponível.
    }
  }

  void _choosePortion(Food food) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AddFoodScreen(
          day: widget.day,
          meal: widget.meal,
          initialFood: food,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final found = _found;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear produto'),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: found != null
            ? [
                _ProductResult(
                  food: found,
                  barcode: _barcode,
                  onChoosePortion: () => _choosePortion(found),
                  onScanAnother: _scanAnother,
                ),
              ]
            : [
                if (_cameraEnabled)
                  _CameraCard(
                    controller: _controller!,
                    onDetect: _onDetect,
                  )
                else
                  _CameraDisabledCard(onEnable: _enableCamera),
                const SizedBox(height: 14),
                _ManualCodeCard(
                  controller: _manual,
                  busy: _busy,
                  onSearch: () => _lookup(_manual.text),
                ),
                if (_busy) ...[
                  const SizedBox(height: 14),
                  const _LookingUpCard(),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _ErrorCard(message: _error!),
                ],
                const SizedBox(height: 16),
                Text(
                  'Os dados vêm da comunidade do Open Food Facts. '
                  'Sempre confira o rótulo do produto.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: context.colors.muted),
                ),
              ],
      ),
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.controller, required this.onDetect});

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: MobileScanner(
              controller: controller,
              onDetect: onDetect,
              errorBuilder: (context, error) => const _CameraError(),
              placeholderBuilder: (context) => ColoredBox(
                color: context.colors.ink,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.center_focus_strong_rounded,
                size: 16, color: context.colors.green),
            SizedBox(width: 6),
            Text(
              'Aponte para o código de barras',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.colors.muted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.ink,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.no_photography_rounded, color: Colors.white70, size: 34),
          SizedBox(height: 10),
          Text(
            'Não foi possível abrir a câmera',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Use o campo de código abaixo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.5,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraDisabledCard extends StatelessWidget {
  const _CameraDisabledCard({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: context.colors.greenSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.qr_code_scanner_rounded,
                color: context.colors.green, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            'Câmera desligada neste dispositivo',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'No navegador você pode tentar abrir a câmera ou digitar o '
            'código impresso na embalagem.',
            textAlign: TextAlign.center,
            style:
                theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onEnable,
            icon: const Icon(Icons.photo_camera_rounded, size: 18),
            label: const Text('Tentar abrir a câmera'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.green,
              side: BorderSide(color: context.colors.greenSoft, width: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualCodeCard extends StatelessWidget {
  const _ManualCodeCard({
    required this.controller,
    required this.busy,
    required this.onSearch,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ou digite o código', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'O número fica embaixo do código de barras.',
            style:
                theme.textTheme.bodySmall?.copyWith(color: context.colors.muted),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Ex.: 7894900010015',
              prefixIcon: Icon(Icons.numbers_rounded),
              filled: true,
              fillColor: context.colors.cream,
            ),
            onSubmitted: (_) => onSearch(),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : onSearch,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.search_rounded, size: 20),
            label: Text(busy ? 'Consultando…' : 'Buscar produto'),
          ),
        ],
      ),
    );
  }
}

class _LookingUpCard extends StatelessWidget {
  const _LookingUpCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      color: context.colors.greenSoft,
      shadow: false,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: context.colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Consultando o Open Food Facts…',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: context.colors.greenDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      color: context.colors.coralSoft,
      shadow: false,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: context.colors.coral, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: context.colors.coral),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductResult extends StatelessWidget {
  const _ProductResult({
    required this.food,
    required this.barcode,
    required this.onChoosePortion,
    required this.onScanAnother,
  });

  final Food food;
  final String? barcode;
  final VoidCallback onChoosePortion;
  final VoidCallback onScanAnother;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FoodAvatar(category: food.category, size: 58),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          shortCategory(food.category),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: context.colors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.colors.greenSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'OPEN FOOD FACTS',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: context.colors.green,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (barcode != null)
                    Text(
                      barcode!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: context.colors.muted),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Valores por 100 ${unitForCategory(food.category)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: context.colors.muted),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: 'kcal',
                      value: food.kcal100.toStringAsFixed(0),
                      color: context.colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetricTile(
                      label: 'Proteína',
                      value: '${food.protein100.toStringAsFixed(1)} g',
                      color: context.colors.protein,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetricTile(
                      label: 'Carbo',
                      value: '${food.carbs100.toStringAsFixed(1)} g',
                      color: context.colors.carbs,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetricTile(
                      label: 'Gordura',
                      value: '${food.fat100.toStringAsFixed(1)} g',
                      color: context.colors.fat,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: context.colors.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Dados enviados pela comunidade — confira o rótulo.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: context.colors.muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onChoosePortion,
          icon: const Icon(Icons.percent_rounded, size: 20),
          label: const Text('Escolher porção'),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: onScanAnother,
            child: const Text('Escanear outro produto'),
          ),
        ),
      ],
    );
  }
}