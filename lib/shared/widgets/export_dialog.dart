import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/browser_download.dart';
import '../../core/theme.dart';

/// Mostra o conteúdo exportado com opções de baixar/copiar.
///
/// Na web o download precisa acontecer **dentro** do toque do usuário: gerar o
/// JSON é assíncrono e, se o download fosse disparado logo depois do `await`,
/// o Safari (iOS) bloqueia. Por isso o arquivo só é criado quando o usuário
/// toca em "Baixar" neste diálogo.
Future<void> showExportDialog(
  BuildContext context, {
  required String title,
  required String content,
  required String fileName,
  required String mimeType,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final colors = dialogContext.colors;
      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fileName,
                style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                  color: colors.muted,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.cream,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.line),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    content,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Baixe o arquivo ou copie o conteúdo para guardar onde quiser.',
                style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                  color: colors.muted,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: content));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Conteúdo copiado')),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copiar'),
          ),
          FilledButton.icon(
            onPressed: () {
              downloadInBrowser(
                content,
                fileName: fileName,
                mimeType: mimeType,
              );
              Navigator.of(dialogContext).pop();
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Baixar'),
          ),
        ],
      );
    },
  );
}
