import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/backup_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_helper.dart';
import '../widgets/center_toast.dart';

const _blue = AppColors.blue;

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _exporting = false;
  bool _importing = false;
  DateTime? _lastManualBackup;
  List<File> _autoBackups = [];

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final last = await BackupService.instance.getLastManualBackupDate();
    final autos = await BackupService.instance.listAutoBackups();
    if (mounted) {
      setState(() {
        _lastManualBackup = last;
        _autoBackups = autos;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Backup & Restore',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Keep your data safe',
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 13)),
              const SizedBox(height: 20),

              // ── Info Card ──────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _blue.withValues(alpha: 0.15)),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      const Icon(Icons.backup_outlined, color: _blue, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Protect Your Data',
                        style: TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    Text(
                        'Back up regularly to keep your records safe.',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            _lastBackupStatus(),
            const SizedBox(height: 20),

            // ── Export Card ────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.green.shade100),
                    ),
                    child: Icon(Icons.upload_outlined,
                        color: Colors.green.shade600, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                    const Text('Export Backup',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87)),
                    Text('Save as JSON file',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11)),
                  ]),
                ]),
                const SizedBox(height: 10),
                Text(
                    'Saves all data — products, sales, credit, and expenses.',
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _exporting ? null : _export,
                    icon: _exporting
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2))
                        : const Icon(Icons.share_outlined,
                            size: 16),
                    label: Text(
                        _exporting
                            ? 'Exporting...'
                            : 'Export & Share',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Import Card ────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.orange.shade100),
                    ),
                    child: Icon(Icons.download_outlined,
                        color: Colors.orange.shade600, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                    const Text('Restore from Backup',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87)),
                    Text('Upload a JSON file',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11)),
                  ]),
                ]),
                const SizedBox(height: 10),
                Text('Select a JSON backup file to restore data.',
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.warning_amber_outlined,
                        color: Colors.orange.shade600, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'Current data will be overwritten.',
                          style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _importing ? null : _import,
                    icon: _importing
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Icon(Icons.folder_open_outlined,
                            size: 16),
                    label: Text(
                        _importing
                            ? 'Importing...'
                            : 'Select Backup File',
                        style: const TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      side:
                          BorderSide(color: _blue.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            _autoBackupsCard(),
            const SizedBox(height: 16),

            // ── Tip ───────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _blue.withValues(alpha: 0.12)),
              ),
              child: Row(children: [
                Icon(Icons.lightbulb_outline,
                    color: _blue.withValues(alpha: 0.6),
                    size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tip: Back up at least once a week to keep your data safe.',
                    style: TextStyle(
                        color: _blue.withValues(alpha: 0.8),
                        fontSize: 12),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
          ],
        ),
        ),
      ),
    );
  }

  Widget _lastBackupStatus() {
    final stale = _lastManualBackup == null ||
        DateTime.now().difference(_lastManualBackup!).inDays >= 7;
    final color = stale ? Colors.orange : Colors.green;
    final label = _lastManualBackup == null
        ? "You haven't exported a backup yet."
        : 'Last exported backup: ${DateHelper.timeAgo(_lastManualBackup!)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(stale ? Icons.warning_amber_outlined : Icons.check_circle_outline,
            color: color.shade700, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: color.shade700, fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }

  Widget _autoBackupsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.purple.shade100),
            ),
            child: Icon(Icons.history_outlined, color: Colors.purple.shade600, size: 20),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Local Auto-Backups',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
            Text('Saved automatically on this device',
                style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 10),
        Text(
            'A safety net only — stays on this phone, so still export a copy off-device regularly.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 12),
        if (_autoBackups.isEmpty)
          Text('None yet — one is saved automatically once a day.',
              style: TextStyle(color: Colors.grey[400], fontSize: 12))
        else
          ..._autoBackups.map((f) {
            final modified = f.statSync().modified;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                  child: Text(DateHelper.timeAgo(modified),
                      style: const TextStyle(fontSize: 12, color: Colors.black87)),
                ),
                TextButton(
                  onPressed: _importing ? null : () => _restoreFromAuto(f),
                  style: TextButton.styleFrom(
                      foregroundColor: _blue, padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('Restore', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ]),
            );
          }),
      ]),
    );
  }

  Future<bool> _confirmRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: const Text('Confirm Restore',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        content: Text(
            'All current data will be replaced with the backup file. This cannot be undone.',
            style: TextStyle(
                color: Colors.grey[600], fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: TextStyle(
                      color: Colors.grey[600], fontSize: 13))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore',
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
      ),
    );
    return confirm == true;
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await BackupService.instance.exportBackup();
      if (mounted) {
        CenterToast.showSuccess(context, 'Backup exported!');
      }
    } catch (e) {
      if (mounted) {
        CenterToast.showError(context, 'Error: $e');
      }
    }
    if (mounted) setState(() => _exporting = false);
    await _loadMeta();
  }

  Future<void> _import() async {
    if (!await _confirmRestore()) return;
    setState(() => _importing = true);
    final ok = await BackupService.instance.importBackup();
    await _finishRestore(ok);
  }

  Future<void> _restoreFromAuto(File file) async {
    if (!await _confirmRestore()) return;
    setState(() => _importing = true);
    final ok = await BackupService.instance.restoreFromFile(file);
    await _finishRestore(ok);
  }

  Future<void> _finishRestore(bool ok) async {
    if (mounted) {
      if (ok) {
        await context.read<AppProvider>().reload();
        CenterToast.showSuccess(context, 'Backup restored!');
      } else {
        CenterToast.showError(
            context, 'Import failed. Make sure the file is a valid JSON backup.');
      }
      setState(() => _importing = false);
    }
  }
}