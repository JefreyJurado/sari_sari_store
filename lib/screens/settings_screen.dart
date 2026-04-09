import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'pin_screen.dart';
import '../services/database_service.dart';
import '../providers/app_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  bool _notif = true;
  bool _pinEnabled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameCtrl.text =
          prefs.getString('store_name') ?? 'Aming Sari-Sari Store';
      _notif = prefs.getBool('notifications') ?? true;
      _pinEnabled = prefs.getBool('pin_enabled') ?? false;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('store_name', _nameCtrl.text.trim());
    await prefs.setBool('notifications', _notif);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Na-save ang settings!'),
          backgroundColor: Colors.green));
    }
  }

  Future<void> _togglePin(bool val) async {
    if (val) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => const PinScreen(isSetup: true)),
      );
      if (result == true) {
        setState(() => _pinEnabled = true);
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('I-remove ang PIN?'),
          content: const Text(
              'Ang iyong PIN ay matatanggal. Hindi na kailangan ng PIN para buksan ang app.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Kanselahin')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red),
              child: const Text('I-remove'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('pin_enabled', false);
        await prefs.remove('app_pin');
        setState(() => _pinEnabled = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('PIN na-remove!'),
                  backgroundColor: Colors.orange));
        }
      }
    }
  }

  // ── Clear Specific Data ─────────────────────────────────────
  Future<void> _confirmClearData() async {
    bool clearSales = true;
    bool clearDebts = true;
    bool clearExpenses = true;
    bool clearCustomers = false;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('I-clear ang Specific Data'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Piliin kung ano ang ie-erase:',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),

                _checkItem('Mga Benta / Sales',
                    'History ng lahat ng benta',
                    clearSales,
                    (v) => setS(() => clearSales = v ?? false)),
                const SizedBox(height: 8),

                _checkItem('Lista ng Utang',
                    'Lahat ng utang at payment history',
                    clearDebts,
                    (v) => setS(() => clearDebts = v ?? false)),
                const SizedBox(height: 8),

                _checkItem('Mga Gastos',
                    'History ng lahat ng gastos',
                    clearExpenses,
                    (v) => setS(() => clearExpenses = v ?? false)),
                const SizedBox(height: 8),

                _checkItem('Mga Customer',
                    'Lahat ng customer records',
                    clearCustomers,
                    (v) => setS(() => clearCustomers = v ?? false)),

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ang mga Produkto ay hindi mabubura.',
                        style: TextStyle(
                            fontSize: 11, color: Colors.orange),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Kanselahin')),
            ElevatedButton(
              onPressed: () {
                if (!clearSales &&
                    !clearDebts &&
                    !clearExpenses &&
                    !clearCustomers) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                          content: Text('Pumili ng kahit isa!'),
                          backgroundColor: Colors.red));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange),
              child: const Text('I-clear'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    final db = DatabaseService.instance;
    if (clearSales) await db.clearSales();
    if (clearDebts) await db.clearDebts();
    if (clearExpenses) await db.clearExpenses();
    if (clearCustomers) await db.clearCustomers();

    await _keepSettings();

    if (mounted) {
      final cleared = <String>[];
      if (clearSales) cleared.add('Benta');
      if (clearDebts) cleared.add('Utang');
      if (clearExpenses) cleared.add('Gastos');
      if (clearCustomers) cleared.add('Customers');

      await context.read<AppProvider>().reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Na-clear na ang: ${cleared.join(', ')}!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ── Clear All Data ──────────────────────────────────────────
  Future<void> _confirmClearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('I-clear ang Lahat ng Data?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mabubura ang lahat ng:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red)),
                  SizedBox(height: 8),
                  Text('• Mga Benta at Sales History'),
                  Text('• Lista ng Utang'),
                  Text('• Mga Gastos'),
                  Text('• Mga Customer'),
                  Text('• Cash Drawer History'),
                  Text('• Loyalty Points'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.green.withValues(alpha: 0.2)),
              ),
              child: const Row(children: [
                Icon(Icons.check_circle_outline,
                    color: Colors.green, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mananatili ang mga Produkto.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.green),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(children: [
                Icon(Icons.warning_amber_outlined,
                    color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hindi na ito mababawi!',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Kanselahin')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('I-clear Lahat'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await DatabaseService.instance.clearAllData();
    await _keepSettings();

    if (mounted) {
      await context.read<AppProvider>().reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Na-clear na ang lahat! Nananatili ang mga Produkto.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // ── Helper: Keep Settings after clear ──────────────────────
  Future<void> _keepSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final storeName = prefs.getString('store_name');
    final pinEnabled = prefs.getBool('pin_enabled');
    final appPin = prefs.getString('app_pin');
    final notifications = prefs.getBool('notifications');

    await prefs.clear();

    if (storeName != null) {
      await prefs.setString('store_name', storeName);
    }
    if (pinEnabled != null) {
      await prefs.setBool('pin_enabled', pinEnabled);
    }
    if (appPin != null) {
      await prefs.setString('app_pin', appPin);
    }
    if (notifications != null) {
      await prefs.setBool('notifications', notifications);
    }
  }

  // ── Helper: Checkbox item ───────────────────────────────────
  Widget _checkItem(
    String title,
    String subtitle,
    bool value,
    void Function(bool?) onChanged,
  ) =>
      Container(
        decoration: BoxDecoration(
          color: value
              ? Colors.red.withValues(alpha: 0.05)
              : Colors.grey.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: value
                  ? Colors.red.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.2)),
        ),
        child: CheckboxListTile(
          dense: true,
          title: Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle,
              style: const TextStyle(fontSize: 11)),
          value: value,
          activeColor: Colors.red,
          onChanged: onChanged,
        ),
      );

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(title: const Text('Mga Setting')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Tindahan ───────────────────────
                _label('TINDAHAN'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Pangalan ng Tindahan',
                        prefixIcon: Icon(Icons.store_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Notifications ──────────────────
                _label('NOTIFICATIONS'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SwitchListTile(
                    title: const Text('I-enable ang Notifications'),
                    subtitle:
                        const Text('Low stock at utang reminders'),
                    secondary:
                        const Icon(Icons.notifications_outlined),
                    value: _notif,
                    onChanged: (v) => setState(() => _notif = v),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Seguridad ──────────────────────
                _label('SEGURIDAD'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SwitchListTile(
                    title: const Text('PIN Lock'),
                    subtitle: Text(_pinEnabled
                        ? 'Naka-on — may PIN protection'
                        : 'Naka-off — walang PIN'),
                    secondary: Icon(
                      _pinEnabled
                          ? Icons.lock_outline
                          : Icons.lock_open_outlined,
                      color: _pinEnabled
                          ? const Color(0xFF2E7D32)
                          : Colors.grey,
                    ),
                    value: _pinEnabled,
                    onChanged: _togglePin,
                  ),
                ),
                if (_pinEnabled) ...[
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: const Icon(
                          Icons.password_outlined,
                          color: Colors.blue),
                      title: const Text('Palitan ang PIN'),
                      subtitle:
                          const Text('Gumawa ng bagong PIN'),
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.grey),
                      onTap: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const PinScreen(isSetup: true)),
                        );
                        if (result == true && mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text('Nabago ang PIN!'),
                            backgroundColor: Colors.green,
                          ));
                        }
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // ── Danger Zone ────────────────────
                _label('DANGER ZONE'),

                // Specific Data
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color:
                            Colors.orange.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: const Icon(
                        Icons.delete_outline,
                        color: Colors.orange),
                    title: const Text(
                        'I-clear ang Specific Data',
                        style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Piliin kung ano ang ie-erase',
                        style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right,
                        color: Colors.grey),
                    onTap: () => _confirmClearData(),
                  ),
                ),
                const SizedBox(height: 8),

                // Clear All
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: const Icon(
                        Icons.delete_forever_outlined,
                        color: Colors.red),
                    title: const Text(
                        'I-clear ang Lahat ng Data',
                        style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Burahin lahat — benta, utang, gastos, customers',
                        style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right,
                        color: Colors.grey),
                    onTap: () => _confirmClearAll(),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Tungkol sa App ─────────────────
                _label('TUNGKOL SA APP'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Column(children: [
                    ListTile(
                      leading: Icon(Icons.phone_android_outlined),
                      title: Text('TindaPH'),
                      subtitle: Text('Version 1.0.0'),
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.favorite_outline,
                          color: Colors.red),
                      title: Text('Gawa para sa mga Pilipino'),
                      subtitle: Text('Para sa inyong negosyo 🇵🇭'),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                // ── Save button ────────────────────
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14)),
                  child: const Text(
                    'I-save ang Settings',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontSize: 12,
                letterSpacing: 1)),
      );
}