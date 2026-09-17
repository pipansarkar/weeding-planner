import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';

const List<String> _backupTables = [
  'weddings',
  'checklist_items',
  'budget_items',
  'guests',
  'vendors',
  'vendor_contact_logs',
  'timeline_events',
  'emergency_contacts',
  'seating_tables',
  'mood_board_items',
  'menu_items',
  'custom_lists',
  'custom_list_items',
];

class BackupFile {
  final String fileName;
  final DateTime createdAt;
  final int sizeBytes;

  const BackupFile({
    required this.fileName,
    required this.createdAt,
    required this.sizeBytes,
  });
}

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  Future<Directory> _backupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/backups');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Map<String, dynamic>> _buildSnapshot() async {
    final db = await AppDatabase.instance.database;
    final data = <String, dynamic>{};
    for (final table in _backupTables) {
      data[table] = await db.query(table);
    }
    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': data,
    };
  }

  Future<String> exportSnapshotJson() async {
    final snapshot = await _buildSnapshot();
    return const JsonEncoder.withIndent('  ').convert(snapshot);
  }

  Future<File> createBackup() async {
    final dir = await _backupDir();
    final timestamp = DateTime.now();
    final name = 'backup_${_fileTimestamp(timestamp)}.json';
    final file = File('${dir.path}/$name');
    await file.writeAsString(await exportSnapshotJson());
    return file;
  }

  Future<List<BackupFile>> listBackups() async {
    final dir = await _backupDir();
    final entries = await dir.list().toList();
    final files = entries.whereType<File>().where((f) => f.path.endsWith('.json'));
    final result = <BackupFile>[];
    for (final file in files) {
      final stat = await file.stat();
      result.add(BackupFile(
        fileName: file.uri.pathSegments.last,
        createdAt: stat.modified,
        sizeBytes: stat.size,
      ));
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<File> _fileFor(String fileName) async {
    final dir = await _backupDir();
    return File('${dir.path}/$fileName');
  }

  Future<void> deleteBackup(String fileName) async {
    final file = await _fileFor(fileName);
    if (await file.exists()) await file.delete();
  }

  Future<String> readBackupContent(String fileName) async {
    final file = await _fileFor(fileName);
    return file.readAsString();
  }

  Future<void> restoreFromJson(String jsonContent) async {
    final decoded = jsonDecode(jsonContent) as Map<String, dynamic>;
    final tables = decoded['tables'] as Map<String, dynamic>;
    final db = await AppDatabase.instance.database;

    await db.transaction((txn) async {
      for (final table in _backupTables.reversed) {
        await txn.delete(table);
      }
      for (final table in _backupTables) {
        final rows = (tables[table] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        for (final row in rows) {
          await txn.insert(table, row);
        }
      }
    });
  }

  Future<void> resetAllData() async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      for (final table in _backupTables.reversed) {
        await txn.delete(table);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_wedding_id');
  }

  String _fileTimestamp(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}_${two(dt.hour)}-${two(dt.minute)}-${two(dt.second)}';
  }
}
