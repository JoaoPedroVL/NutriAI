// Mobile implementation for database reset and page reload
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'providers.dart';
import '../data/db/database.dart';

Future<void> resetDatabaseAndReload() async {
  // Fecha o banco atual
  final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(AppDatabase())]);
  final db = container.read(databaseProvider);
  await db.close();
  
  // Apaga o arquivo do banco
  final dir = await getApplicationDocumentsDirectory();
  final dbFile = File('${dir.path}/nutria.sqlite');
  if (await dbFile.exists()) {
    await dbFile.delete();
  }
  // Apaga também -shm e -wal se existirem
  await File('${dir.path}/nutria.sqlite-shm').delete().catchError((_) => File('${dir.path}/nutria.sqlite-shm'));
  await File('${dir.path}/nutria.sqlite-wal').delete().catchError((_) => File('${dir.path}/nutria.sqlite-wal'));
  
  container.dispose();
}

void reloadPage() {
  // No mobile, apenas fecha o app - o usuário reabre
  exit(0);
}