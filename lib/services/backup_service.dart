import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../services/database_service.dart';

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

      final content = await File(path).readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      await DatabaseService.instance.importAll(data);
      return true;
    } catch (_) {
      return false;
    }
  }
}