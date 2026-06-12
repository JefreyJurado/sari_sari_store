import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'pin_screen.dart';
import '../services/database_service.dart';
import '../providers/app_provider.dart';

const _blue = Color(0xFF1E3A8A);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _setupCtrl = TextEditingController();
  final _inventoryCtrl = TextEditingController();
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
    final prov = context.read<AppProvider>();
    setState(() {
      _nameCtrl.text =
          prefs.getString('store_name') ?? 'My Sari-Sari Store';
      _notif = prefs.getBool('notifications') ?? true;
      _pinEnabled = prefs.getBool('pin_enabled') ?? false;
      final cap = prov.capital;
      if (cap != null) {
        _setupCtrl.text =
            cap.setupCosts.toStringAsFixed(2);
        _inventoryCtrl.text =
            cap.inventoryValue.toStringAsFixed(2);
      }
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'store_name', _nameCtrl.text.trim());
    await prefs.setBool('notifications', _notif);

    final prov = context.read<AppProvider>();
    await prov.saveCapital(
      setupCosts:
          double.tryParse(_setupCtrl.text) ?? 0,
      inventoryValue:
          double.tryParse(_inventoryCtrl.text) ?? 0,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Settings saved!'),
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
      if (result == true) setState(() => _pinEnabled = true);
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          title: const Text('Remove PIN?',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          content: Text(
              'Your PIN will be removed. The app will no longer require a PIN to open.',
              style: TextStyle(
                  color: Colors.grey[600], fontSize: 13)),
          actions: [
            TextButton(
                onPressed: () =>
                    Navigator.pop(context, false),
                child: Text('Cancel',
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13))),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text('Remove',
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
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
                  content: Text('PIN removed.'),
                  backgroundColor: Colors.orange));
        }
      }
    }
  }

  Future<void> _confirmClearData() async {
    bool clearSales = true;
    bool clearDebts = true;
    bool clearExpenses = true;
    bool clearCustomers = false;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          title: const Text('Clear Specific Data',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select what to erase:',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500])),
                const SizedBox(height: 12),
                _checkItem('Sales', 'All sales history',
                    clearSales,
                    (v) => setS(
                        () => clearSales = v ?? false)),
                const SizedBox(height: 8),
                _checkItem('Credit / Debts',
                    'All credit and payment history',
                    clearDebts,
                    (v) => setS(
                        () => clearDebts = v ?? false)),
                const SizedBox(height: 8),
                _checkItem('Expenses',
                    'All expense records', clearExpenses,
                    (v) => setS(() =>
                        clearExpenses = v ?? false)),
                const SizedBox(height: 8),
                _checkItem('Customers',
                    'All customer records', clearCustomers,
                    (v) => setS(() =>
                        clearCustomers = v ?? false)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.grey.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline,
                        color: Colors.grey[500], size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'Products will not be deleted.',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600])),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, false),
                child: Text('Cancel',
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13))),
            TextButton(
              onPressed: () {
                if (!clearSales &&
                    !clearDebts &&
                    !clearExpenses &&
                    !clearCustomers) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(const SnackBar(
                          content:
                              Text('Select at least one.'),
                          backgroundColor: Colors.red));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Clear',
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
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
      if (clearSales) cleared.add('Sales');
      if (clearDebts) cleared.add('Credit');
      if (clearExpenses) cleared.add('Expenses');
      if (clearCustomers) cleared.add('Customers');
      await context.read<AppProvider>().reload();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Cleared: ${cleared.join(', ')}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  Future<void> _confirmClearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: const Text('Clear All Data?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text('This will delete:',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                          fontSize: 13)),
                  const SizedBox(height: 8),
                  ...[
                    'Sales history',
                    'Credit / Debts',
                    'Expenses',
                    'Customers',
                    'Loyalty Points'
                  ].map((t) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: 3),
                        child: Row(children: [
                          Icon(Icons.remove,
                              size: 12,
                              color: Colors.red.shade400),
                          const SizedBox(width: 6),
                          Text(t,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700])),
                        ]),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.grey.shade200),
              ),
              child: Row(children: [
                Icon(Icons.check_circle_outline,
                    color: Colors.green.shade400, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Products will be kept.',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600])),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.orange.shade200),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber_outlined,
                    color: Colors.orange.shade600,
                    size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('This cannot be undone.',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: Text('Cancel',
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13))),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, true),
            child: const Text('Clear All',
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
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
        content:
            Text('All data cleared. Products are kept.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ));
    }
  }

  Future<void> _keepSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final storeName = prefs.getString('store_name');
    final pinEnabled = prefs.getBool('pin_enabled');
    final appPin = prefs.getString('app_pin');
    final notifications = prefs.getBool('notifications');
    await prefs.clear();
    if (storeName != null)
      await prefs.setString('store_name', storeName);
    if (pinEnabled != null)
      await prefs.setBool('pin_enabled', pinEnabled);
    if (appPin != null)
      await prefs.setString('app_pin', appPin);
    if (notifications != null)
      await prefs.setBool('notifications', notifications);
  }

  Widget _checkItem(String title, String subtitle,
          bool value, void Function(bool?) onChanged) =>
      Container(
        decoration: BoxDecoration(
          color: value
              ? Colors.red.withValues(alpha: 0.04)
              : Colors.grey.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: value
                  ? Colors.red.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.15)),
        ),
        child: CheckboxListTile(
          dense: true,
          title: Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          subtitle: Text(subtitle,
              style: TextStyle(
                  fontSize: 11, color: Colors.grey[500])),
          value: value,
          activeColor: Colors.red,
          onChanged: onChanged,
        ),
      );

  Widget _capitalField(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon,
  ) =>
      TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(
            decimal: true),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
              color: Colors.grey[600], fontSize: 13),
          hintText: hint,
          hintStyle: TextStyle(
              color: Colors.grey[400], fontSize: 11),
          prefixText: '₱ ',
          prefixIcon: Icon(icon,
              size: 18, color: Colors.grey[500]),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: Colors.grey.shade300)),
        ),
      );

  @override
  void dispose() {
    _nameCtrl.dispose();
    _setupCtrl.dispose();
    _inventoryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: const Text('Settings',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
              height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [

                // ── Store info card ──────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
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
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.store_outlined,
                          color: _blue, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                        Text(
                            _nameCtrl.text.isEmpty
                                ? 'My Sari-Sari Store'
                                : _nameCtrl.text,
                            style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 15,
                                fontWeight:
                                    FontWeight.w600)),
                        Text('Configure your app',
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12)),
                      ]),
                    ),
                    if (_pinEnabled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              _blue.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                              color: _blue
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          Icon(Icons.lock_outline,
                              color: _blue, size: 12),
                          const SizedBox(width: 4),
                          Text('PIN',
                              style: TextStyle(
                                  color: _blue,
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight.bold)),
                        ]),
                      ),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Store Name ───────────────────────────
                _label('STORE'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: TextField(
                      controller: _nameCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Store name',
                        labelStyle: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13),
                        prefixIcon: Icon(
                            Icons.store_outlined,
                            color: Colors.grey[500],
                            size: 18),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color:
                                    Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color:
                                    Colors.grey.shade300)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Beginning Balance ────────────────────
                _label('BEGINNING BALANCE'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.grey.shade200),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(
                            Icons.account_balance_outlined,
                            color: _blue, size: 16),
                        const SizedBox(width: 8),
                        const Text('Initial Investment',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87)),
                      ]),
                      Text(
                          'Set once when starting your business. Used to track ROI and capital growth.',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500])),
                      const SizedBox(height: 14),
                      _capitalField(
                        _setupCtrl,
                        'Business Setup Costs',
                        'DTI, permits, equipment, renovation',
                        Icons.store_mall_directory_outlined,
                      ),
                      const SizedBox(height: 10),
                      _capitalField(
                        _inventoryCtrl,
                        'Starting Inventory Value',
                        'Actual products bought to sell',
                        Icons.inventory_2_outlined,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _blue.withValues(alpha: 0.04),
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  _blue.withValues(alpha: 0.12)),
                        ),
                        child: Row(children: [
                          Icon(Icons.info_outline,
                              size: 13,
                              color:
                                  _blue.withValues(alpha: 0.6)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Monthly operating costs (salary, rent, utilities) are tracked automatically via the Expenses screen.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600]),
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Notifications ────────────────────────
                _label('NOTIFICATIONS'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.grey.shade200),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                        'Enable Notifications',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87)),
                    subtitle: Text(
                        'Low stock & credit reminders',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11)),
                    secondary: Icon(
                        Icons.notifications_outlined,
                        color: Colors.grey[500], size: 20),
                    value: _notif,
                    activeColor: _blue,
                    onChanged: (v) =>
                        setState(() => _notif = v),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Security ─────────────────────────────
                _label('SECURITY'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.grey.shade200),
                  ),
                  child: SwitchListTile(
                    title: const Text('PIN Lock',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87)),
                    subtitle: Text(
                      _pinEnabled
                          ? 'Enabled — PIN required to open'
                          : 'Disabled — no PIN required',
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11),
                    ),
                    secondary: Icon(
                      _pinEnabled
                          ? Icons.lock_outline
                          : Icons.lock_open_outlined,
                      color: _pinEnabled
                          ? _blue
                          : Colors.grey[400],
                      size: 20,
                    ),
                    value: _pinEnabled,
                    activeColor: _blue,
                    onChanged: _togglePin,
                  ),
                ),
                if (_pinEnabled) ...[
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      leading: Icon(
                          Icons.password_outlined,
                          color: _blue, size: 20),
                      title: const Text('Change PIN',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87)),
                      subtitle: Text('Set a new PIN',
                          style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11)),
                      trailing: Icon(Icons.chevron_right,
                          color: Colors.grey[400], size: 18),
                      onTap: () async {
                        final result =
                            await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const PinScreen(
                                      isSetup: true)),
                        );
                        if (result == true && mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                                  content:
                                      Text('PIN updated!'),
                                  backgroundColor:
                                      Colors.green));
                        }
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // ── Danger Zone ──────────────────────────
                _label('DANGER ZONE'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.orange.shade100),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.delete_outline,
                        color: Colors.orange.shade400,
                        size: 20),
                    title: const Text(
                        'Clear Specific Data',
                        style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                            fontSize: 13)),
                    subtitle: Text('Choose what to erase',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11)),
                    trailing: Icon(Icons.chevron_right,
                        color: Colors.grey[400], size: 18),
                    onTap: () => _confirmClearData(),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.red.shade100),
                  ),
                  child: ListTile(
                    leading: Icon(
                        Icons.delete_forever_outlined,
                        color: Colors.red.shade400, size: 20),
                    title: const Text('Clear All Data',
                        style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                            fontSize: 13)),
                    subtitle: Text(
                        'Delete sales, credit, expenses, customers',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11)),
                    trailing: Icon(Icons.chevron_right,
                        color: Colors.grey[400], size: 18),
                    onTap: () => _confirmClearAll(),
                  ),
                ),
                const SizedBox(height: 16),

                // ── About ────────────────────────────────
                _label('ABOUT'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.grey.shade200),
                  ),
                  child: Column(children: [
                    ListTile(
                      leading: Icon(
                          Icons.phone_android_outlined,
                          color: Colors.grey[500], size: 20),
                      title: const Text('TindaPH',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87)),
                      subtitle: Text('Version 1.0.0',
                          style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11)),
                    ),
                    Divider(
                        height: 1,
                        color: Colors.grey.shade100),
                    ListTile(
                      leading: Icon(
                          Icons.favorite_outline,
                          color: Colors.red.shade300,
                          size: 20),
                      title: const Text(
                          'Made for Filipino store owners',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87)),
                      subtitle: Text(
                          'For your business 🇵🇭',
                          style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11)),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Save Button ──────────────────────────
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10)),
                  ),
                  child: const Text('Save Settings',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                fontSize: 11,
                letterSpacing: 0.8)),
      );
}