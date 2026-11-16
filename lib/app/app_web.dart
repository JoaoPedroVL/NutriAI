// Web implementation for database reset and page reload
// Uses package:web instead of deprecated dart:html
import 'package:web/web.dart' as web;

Future<void> resetDatabaseAndReload() async {
  // Limpa localStorage e sessionStorage
  web.window.localStorage.clear();
  web.window.sessionStorage.clear();
  
  // Tenta limpar IndexedDB se a API estiver disponível
  // O deleteDatabase retorna IDBOpenDBRequest, não dá para await direto
  // Apenas chamamos para tentar limpar (best effort)
  final idbFactory = web.window.indexedDB;
  try {
    idbFactory.deleteDatabase('nutria');
    idbFactory.deleteDatabase('nutria_db');
    idbFactory.deleteDatabase('drift');
  } catch (_) {
    // Ignora erros
  }
  
  // Força reload
  web.window.location.reload();
}

void reloadPage() {
  web.window.location.reload();
}