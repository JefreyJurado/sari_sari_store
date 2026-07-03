import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/backup_service.dart';

const _blue = Color(0xFF1E3A8A);

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _exporting = false;
  bool _importing = false;

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

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await BackupService.instance.exportBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Backup exported!'),
                backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _exporting = false);
  }

  Future<void> _import() async {
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
    if (confirm != true) return;
    setState(() => _importing = true);
    final ok = await BackupService.instance.importBackup();
    if (mounted) {
      if (ok) {
        await context.read<AppProvider>().reload();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Backup restored!'),
                backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Import failed. Make sure the file is a valid JSON backup.'),
                backgroundColor: Colors.red));
      }
      setState(() => _importing = false);
    }
  }
}