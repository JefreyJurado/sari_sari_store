import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/backup_service.dart';

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
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(title: const Text('Backup at Restore')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header banner
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              padding:
                  const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.backup_outlined,
                      size: 36, color: Colors.white),
                ),
                const SizedBox(height: 14),
                const Text('Protektahan ang Iyong Data',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                    'Regular na i-backup para hindi masayang ang iyong mga records.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13)),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Export card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.green
                                .withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: const Icon(
                              Icons.upload_outlined,
                              color: Colors.green,
                              size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                          Text('I-export ang Backup',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          Text('I-share bilang JSON file',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12)),
                        ]),
                      ]),
                      const SizedBox(height: 12),
                      Text(
                          'I-save ang lahat ng data — produkto, benta, utang, at gastos.',
                          style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _exporting ? null : _export,
                          icon: _exporting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2))
                              : const Icon(
                                  Icons.share_outlined),
                          label: Text(_exporting
                              ? 'Nag-e-export...'
                              : 'I-export at I-share'),
                          style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 13)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Import card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.orange
                                .withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: const Icon(
                              Icons.download_outlined,
                              color: Colors.orange,
                              size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                          Text('I-restore mula sa Backup',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          Text('Mag-upload ng JSON file',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12)),
                        ]),
                      ]),
                      const SizedBox(height: 12),
                      Text(
                          'Piliin ang JSON backup file para i-restore ang data.',
                          style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange
                              .withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orange
                                  .withValues(alpha: 0.3)),
                        ),
                        child: const Row(children: [
                          Icon(Icons.warning_amber_outlined,
                              color: Colors.orange, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                                'Mabubura ang kasalukuyang data!',
                                style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight.w600)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              _importing ? null : _import,
                          icon: _importing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(
                                          strokeWidth: 2))
                              : const Icon(
                                  Icons.folder_open_outlined,
                                  color: Colors.orange),
                          label: Text(
                              _importing
                                  ? 'Nag-i-import...'
                                  : 'Pumili ng Backup File',
                              style: const TextStyle(
                                  color: Colors.orange)),
                          style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Colors.orange),
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 13)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  // Tip
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.lightbulb_outline,
                          color: Colors.blue, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tip: I-backup minsan sa isang linggo para safe ang data mo.',
                          style: TextStyle(
                              color: Colors.blue, fontSize: 12),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
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
                content: Text('Na-export ang backup!'),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Sigurado ka ba?'),
        content: const Text(
            'Mabubura ang lahat ng kasalukuyang data at papalitan ng backup file. Hindi na ito mababalik!'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Kanselahin')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('Ituloy'),
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
                content: Text('Na-restore ang backup!'),
                backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Hindi na-import. Siguraduhing tama ang JSON file.'),
                backgroundColor: Colors.red));
      }
      setState(() => _importing = false);
    }
  }
}