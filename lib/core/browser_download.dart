/// Baixa um arquivo gerado em memória no navegador (web).
///
/// No mobile/desktop usamos `path_provider` + `share_plus`; na web não existe
/// sistema de arquivos, então o conteúdo vira um Blob e o navegador faz o
/// download. A implementação real fica em `browser_download_web.dart` e é
/// escolhida por import condicional.
library;

export 'browser_download_io.dart'
    if (dart.library.js_interop) 'browser_download_web.dart';
