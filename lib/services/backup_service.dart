import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class BackupService {
  static Future<String> createBackup() async {
    final databasesPath = await getDatabasesPath();

    final sourceDb = File(p.join(databasesPath, 'qubico.db'));

    if (!await sourceDb.exists()) {
      throw Exception('No se encontró la base de datos');
    }

    //qubico_backup_FECHA_HORA.db
    final now = DateTime.now();

    final fileName =
        'qubico_backup_'
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}.db';

    final downloads = Directory('/storage/emulated/0/Download');

    if (!await downloads.exists()) {
      await downloads.create(recursive: true);
    }

    final backupFile = File(p.join(downloads.path, fileName));

    await sourceDb.copy(backupFile.path);

    return backupFile.path;
  }
}
