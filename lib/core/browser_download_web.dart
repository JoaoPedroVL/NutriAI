import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Cria um Blob com [content] e dispara o download no navegador.
///
/// Funciona em desktop e, no iOS (Safari 13+), salva em "Arquivos > Downloads".
void downloadInBrowser(
  String content, {
  required String fileName,
  required String mimeType,
}) {
  final bytes = Uint8List.fromList(utf8.encode(content));
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';

  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();

  // Revogar na hora pode cancelar o download em alguns navegadores.
  Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
}
