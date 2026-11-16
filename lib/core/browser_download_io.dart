/// Stub para plataformas que não são web (Android, iOS, desktop).
///
/// Nunca é chamado: o código só usa `downloadInBrowser` dentro de `kIsWeb`.
void downloadInBrowser(
  String content, {
  required String fileName,
  required String mimeType,
}) {
  throw UnsupportedError('downloadInBrowser só existe na web');
}
