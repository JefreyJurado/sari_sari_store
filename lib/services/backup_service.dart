import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';

const _kLastManualBackupKey = 'last_manual_backup_at';
const _kLastAutoBackupKey = 'last_auto_backup_at';
const _kAutoBackupSubdir = 'auto_backups';
const _kMaxAutoBackups = 5;

class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  Future<String> exportBackup() async {
    final data = await DatabaseService.instance.exportAll();
    final json = jsonEncode(data);

    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    // Translated prefix from 'sari_backup_' to 'pos_backup_'
    final filename =
        'pos_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
    final file = File('${dir.path}/$filename');
    await file.writeAsString(json);

    // Translated dialog sheet title text from 'Sari Store Backup'
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'POS System Backup',
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastManualBackupKey, now.toIso8601String());

    return filename;
  }

  Future<bool> importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return false;

      final path = result.files.single.path;
      if (path == null) return false;

      return await restoreFromFile(File(path));
    } catch (_) {
      return false;
    }
  }

  Future<bool> restoreFromFile(File file) async {
    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      await DatabaseService.instance.importAll(data);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<DateTime?> getLastManualBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_kLastManualBackupKey);
    return iso == null ? null : DateTime.tryParse(iso);
  }

  Future<void>? _autoBackupInFlight;

  /// Writes a rotating local snapshot (last [_kMaxAutoBackups] kept) so a
  /// corrupted DB or accidental data wipe can always be recovered from,
  /// even if the user never exports a backup manually. Runs at most once
  /// per day and never throws — safe to call unawaited on every app start.
  /// Guarded in-memory too, since [AppProvider.initialize] can fire twice
  /// in quick succession on startup, before either call's SharedPreferences
  /// write would otherwise be visible to the other.
  Future<void> autoBackupIfNeeded() {
    return _autoBackupInFlight ??= _doAutoBackup().whenComplete(() {
      _autoBackupInFlight = null;
    });
  }

  Future<void> _doAutoBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final lastIso = prefs.getString(_kLastAutoBackupKey);
      if (lastIso != null) {
        final last = DateTime.tryParse(lastIso);
        if (last != null && _isSameDay(last, now)) return;
      }

      final dir = await _autoBackupDir();
      final data = await DatabaseService.instance.exportAll();
      final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final file = File('${dir.path}/auto_backup_$stamp.json');
      await file.writeAsString(jsonEncode(data));

      await _pruneOldAutoBackups(dir);
      await prefs.setString(_kLastAutoBackupKey, now.toIso8601String());
    } catch (_) {}
  }

  Future<List<File>> listAutoBackups() async {
    try {
      final dir = await _autoBackupDir();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      files.sort((a, b) => b.path.compareTo(a.path));
      return files;
    } catch (_) {
      return [];
    }
  }

  Future<Directory> _autoBackupDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_kAutoBackupSubdir');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _pruneOldAutoBackups(Directory dir) async {
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final f in files.skip(_kMaxAutoBackups)) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}