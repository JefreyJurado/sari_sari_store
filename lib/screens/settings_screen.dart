import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'pin_screen.dart';
import '../services/database_service.dart';
import '../services/biometric_service.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/center_toast.dart';
import '../widgets/help_sheet.dart';

const _blue = AppColors.blue;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  bool _notif = true;
  bool _pinEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _loaded = false;
  String _appVersion = '';
  TimeOfDay _openTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 21, minute: 0);
  // DateTime.weekday values (Mon=1 ... Sun=7) the store does NOT operate.
  // Defaults to empty (open every day) so existing users see no change
  // until they actually mark a day off.
  Set<int> _closedWeekdays = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final biometricAvailable = await BiometricService.instance.isAvailable();
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _nameCtrl.text = prefs.getString('store_name') ?? 'My Sari-Sari Store';
      _notif = prefs.getBool('notifications') ?? true;
      _pinEnabled = prefs.getBool('pin_enabled') ?? false;
      _biometricAvailable = biometricAvailable;
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      _appVersion =
          '${packageInfo.version} (${packageInfo.buildNumber})';
      final openMin = prefs.getInt('store_open_minutes') ?? 6 * 60;
      final closeMin = prefs.getInt('store_close_minutes') ?? 21 * 60;
      _openTime = TimeOfDay(hour: openMin ~/ 60, minute: openMin % 60);
      _closeTime = TimeOfDay(hour: closeMin ~/ 60, minute: closeMin % 60);
      final closedDaysStr = prefs.getString('store_closed_weekdays') ?? '';
      _closedWeekdays = closedDaysStr.isEmpty
          ? {}
          : closedDaysStr.split(',').map(int.parse).toSet();
      _loaded = true;
    });
  }

  Future<void> _pickOpenTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _openTime);
    if (picked != null && mounted) setState(() => _openTime = picked);
  }

  Future<void> _pickCloseTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _closeTime);
    if (picked != null && mounted) setState(() => _closeTime = picked);
  }

  Widget _dayChip(int weekday, String label) {
    final isOpen = !_closedWeekdays.contains(weekday);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTap: () => setState(() {
          if (isOpen) {
            _closedWeekdays.add(weekday);
          } else {
            _closedWeekdays.remove(weekday);
          }
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isOpen ? _blue : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isOpen ? _blue : Colors.grey.shade300),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isOpen ? Colors.white : Colors.grey[500])),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('store_name', _nameCtrl.text.trim());
    await prefs.setBool('notifications', _notif);
    await prefs.setInt(
        'store_open_minutes', _openTime.hour * 60 + _openTime.minute);
    await prefs.setInt(
        'store_close_minutes', _closeTime.hour * 60 + _closeTime.minute);
    await prefs.setString(
        'store_closed_weekdays', _closedWeekdays.join(','));

    if (!mounted) return;
    final prov = context.read<AppProvider>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded,
                    color: Colors.green.shade600, size: 36),
              ),
              const SizedBox(height: 16),
              const Text('Settings Saved!',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 8),
              Text('Your changes have been saved successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);

                    // Forces state data re-hydration to prevent out-of-sync form manipulation layout crashes
                    await prov.reload();
                    await _load();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Done',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _togglePin(bool val) async {
    if (val) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const PinScreen(isSetup: true)),
      );
      if (result == true && mounted) setState(() => _pinEnabled = true);
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Remove PIN?',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          content: Text(
              'Your PIN will be removed. The app will no longer require a PIN to open.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13))),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
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
        // Biometric unlock is only meaningful as a shortcut on top of a
        // PIN — removing the PIN removes the thing it was a shortcut for,
        // so leaving it "on" would dangle with nothing backing it.
        await prefs.setBool('biometric_enabled', false);
        if (!mounted) return;
        setState(() {
          _pinEnabled = false;
          _biometricEnabled = false;
        });
        CenterToast.showWarning(context, 'PIN removed.');
      }
    }
  }

  Future<void> _toggleBiometric(bool val) async {
    if (val) {
      // Require a successful scan before turning it on — otherwise a
      // device with hardware present but nothing enrolled (or a user who
      // just doesn't want to scan right now) would enable a setting that
      // silently never works on the actual lock screen.
      final success = await BiometricService.instance
          .authenticate('Confirm to enable biometric unlock');
      if (!success) {
        if (mounted) {
          CenterToast.showError(context, 'Could not verify biometrics.');
        }
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', true);
      if (!mounted) return;
      setState(() => _biometricEnabled = true);
      CenterToast.showSuccess(context, 'Biometric unlock enabled!');
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', false);
      if (!mounted) return;
      setState(() => _biometricEnabled = false);
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 12),
                _checkItem('Sales', 'All sales history', clearSales,
                    (v) => setS(() => clearSales = v ?? false)),
                const SizedBox(height: 8),
                _checkItem('Credit / Debts', 'All credit and payment history',
                    clearDebts, (v) => setS(() => clearDebts = v ?? false)),
                const SizedBox(height: 8),
                _checkItem('Expenses', 'All expense records', clearExpenses,
                    (v) => setS(() => clearExpenses = v ?? false)),
                const SizedBox(height: 8),
                _checkItem('Customers', 'All customer records', clearCustomers,
                    (v) => setS(() => clearCustomers = v ?? false)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline, color: Colors.grey[500], size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Products will not be deleted.',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13))),
            TextButton(
              onPressed: () {
                if (!clearSales &&
                    !clearDebts &&
                    !clearExpenses &&
                    !clearCustomers) {
                  CenterToast.showError(ctx, 'Select at least one.');
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
      if (!mounted) return;
      CenterToast.showSuccess(context, 'Cleared: ${cleared.join(', ')}');
    }
  }

  Future<void> _confirmClearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(children: [
                          Icon(Icons.remove,
                              size: 12, color: Colors.red.shade400),
                          const SizedBox(width: 6),
                          Text(t,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[700])),
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
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(children: [
                Icon(Icons.check_circle_outline,
                    color: Colors.green.shade400, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Products will be kept.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber_outlined,
                    color: Colors.orange.shade600, size: 14),
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
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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
      if (!mounted) return;
      CenterToast.showSuccess(context, 'All data cleared. Products are kept.');
    }
  }

  Future<void> _keepSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final storeName = prefs.getString('store_name');
    final pinEnabled = prefs.getBool('pin_enabled');
    final appPin = prefs.getString('app_pin');
    final notifications = prefs.getBool('notifications');
    final userName = prefs.getString('user_name');
    final biometricEnabled = prefs.getBool('biometric_enabled');
    final openMinutes = prefs.getInt('store_open_minutes');
    final closeMinutes = prefs.getInt('store_close_minutes');
    final closedWeekdays = prefs.getString('store_closed_weekdays');
    final onboardingSeen = prefs.getBool('onboarding_seen');
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
    if (userName != null) {
      await prefs.setString('user_name', userName);
    }
    if (biometricEnabled != null) {
      await prefs.setBool('biometric_enabled', biometricEnabled);
    }
    if (openMinutes != null) {
      await prefs.setInt('store_open_minutes', openMinutes);
    }
    if (closeMinutes != null) {
      await prefs.setInt('store_close_minutes', closeMinutes);
    }
    if (closedWeekdays != null) {
      await prefs.setString('store_closed_weekdays', closedWeekdays);
    }
    if (onboardingSeen != null) {
      await prefs.setBool('onboarding_seen', onboardingSeen);
    }
  }

  Widget _checkItem(String title, String subtitle, bool value,
          void Function(bool?) onChanged) =>
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              dense: true,
              title: Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              subtitle: Text(subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              value: value,
              activeColor: Colors.red,
              onChanged: onChanged,
            ),
          ),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Settings',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          HelpIconButton(
            title: 'Settings, Security & Backup',
            points: [
              'Store Name shows up on your Home screen and on every Order Slip — set it to whatever your customers know your tindahan as.',
              'Store Hours tells the app when you\'re actually open — set your real opening and closing time so the Home screen mascot reflects it accurately instead of guessing.',
              'PIN Lock requires a 4-digit code to open the app; Biometric Unlock (fingerprint/face) is an optional shortcut on top of it, never a replacement.',
              "Forgot your PIN? Use \"Forgot PIN?\" on the lock screen — it verifies you through your phone's own screen lock, then lets you set a new one.",
              'Clear Specific Data lets you wipe just one category (e.g. only sales); Clear All Data erases everything — both are permanent, so back up first if unsure.',
              'A backup is a JSON file with all your data — keep a copy somewhere safe (email, cloud drive) so switching phones never means starting over.',
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                children: [
                  Text('Configure your store',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _blue.withValues(alpha: 0.15)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.store_outlined,
                            color: _blue, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  _nameCtrl.text.isEmpty
                                      ? 'My Sari-Sari Store'
                                      : _nameCtrl.text,
                                  style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              Text('Configure your app',
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 12)),
                            ]),
                      ),
                      if (_pinEnabled)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: _blue.withValues(alpha: 0.2)),
                          ),
                          child: const Row(children: [
                            Icon(Icons.lock_outline, color: _blue, size: 12),
                            SizedBox(width: 4),
                            Text('PIN',
                                style: TextStyle(
                                    color: _blue,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ]),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  _label('STORE'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: TextField(
                        controller: _nameCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Store name',
                          labelStyle:
                              TextStyle(color: Colors.grey[600], fontSize: 13),
                          prefixIcon: Icon(Icons.store_outlined,
                              color: Colors.grey[500], size: 18),
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
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _label('STORE HOURS'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            onTap: _pickOpenTime,
                            leading: Icon(Icons.wb_sunny_outlined,
                                color: Colors.grey[500], size: 20),
                            title: const Text('Opening time',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87)),
                            trailing: Text(_openTime.format(context),
                                style: const TextStyle(
                                    color: _blue,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                        ),
                      ),
                      Divider(
                          height: 1,
                          indent: 14,
                          endIndent: 14,
                          color: Colors.grey.shade200),
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(12)),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            onTap: _pickCloseTime,
                            leading: Icon(Icons.nights_stay_outlined,
                                color: Colors.grey[500], size: 20),
                            title: const Text('Closing time',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87)),
                            trailing: Text(_closeTime.format(context),
                                style: const TextStyle(
                                    color: _blue,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Text('Open on these days',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final entry in const [
                        MapEntry(1, 'M'),
                        MapEntry(2, 'T'),
                        MapEntry(3, 'W'),
                        MapEntry(4, 'Th'),
                        MapEntry(5, 'F'),
                        MapEntry(6, 'Sa'),
                        MapEntry(7, 'Su'),
                      ])
                        Expanded(child: _dayChip(entry.key, entry.value)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10, left: 4, right: 4),
                    child: Text(
                        "The Home screen mascot uses these hours and days to know when your store is actually open — set them to match your real schedule.",
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ),
                  const SizedBox(height: 16),
                  _label('NOTIFICATIONS'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          title: const Text('Enable Notifications',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87)),
                          subtitle: Text('Low stock & credit reminders',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 11)),
                          secondary: Icon(Icons.notifications_outlined,
                              color: Colors.grey[500], size: 20),
                          value: _notif,
                          activeThumbColor: _blue,
                          onChanged: (v) => setState(() => _notif = v),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _label('SECURITY'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Material(
                        color: Colors.transparent,
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
                                color: Colors.grey[500], fontSize: 11),
                          ),
                          secondary: Icon(
                            _pinEnabled
                                ? Icons.lock_outline
                                : Icons.lock_open_outlined,
                            color: _pinEnabled ? _blue : Colors.grey[400],
                            size: 20,
                          ),
                          value: _pinEnabled,
                          activeThumbColor: _blue,
                          onChanged: _togglePin,
                        ),
                      ),
                    ),
                  ),
                  if (_pinEnabled) ...[
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            leading: const Icon(Icons.password_outlined,
                                color: _blue, size: 20),
                            title: const Text('Change PIN',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87)),
                            subtitle: Text('Set a new PIN',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 11)),
                            trailing: Icon(Icons.chevron_right,
                                color: Colors.grey[400], size: 18),
                            onTap: () async {
                              final result = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const PinScreen(isSetup: true)),
                              );
                              if (!mounted) return;
                              if (result == true) {
                                CenterToast.showSuccess(context, 'PIN updated!');
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    // Only offered when the device actually has usable
                    // biometric hardware + an enrolled fingerprint/face —
                    // otherwise this would be a switch that can never work.
                    if (_biometricAvailable) ...[
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Material(
                            color: Colors.transparent,
                            child: SwitchListTile(
                              title: const Text('Biometric Unlock',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87)),
                              subtitle: Text(
                                _biometricEnabled
                                    ? 'Enabled — fingerprint or face to unlock'
                                    : 'Disabled — PIN only',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 11),
                              ),
                              secondary: Icon(Icons.fingerprint,
                                  color:
                                      _biometricEnabled ? _blue : Colors.grey[400],
                                  size: 20),
                              value: _biometricEnabled,
                              activeThumbColor: _blue,
                              onChanged: _toggleBiometric,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  _label('DANGER ZONE'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade100),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: Icon(Icons.delete_outline,
                              color: Colors.orange.shade400, size: 20),
                          title: const Text('Clear Specific Data',
                              style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13)),
                          subtitle: Text('Choose what to erase',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 11)),
                          trailing: Icon(Icons.chevron_right,
                              color: Colors.grey[400], size: 18),
                          onTap: () => _confirmClearData(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: Icon(Icons.delete_forever_outlined,
                              color: Colors.red.shade400, size: 20),
                          title: const Text('Clear All Data',
                              style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13)),
                          subtitle: Text(
                              'Delete sales, credit, expenses, customers',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 11)),
                          trailing: Icon(Icons.chevron_right,
                              color: Colors.grey[400], size: 18),
                          onTap: () => _confirmClearAll(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _label('ABOUT'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            leading: Icon(Icons.phone_android_outlined,
                                color: Colors.grey[500], size: 20),
                            title: const Text('StorePH',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87)),
                            subtitle: Text('Version $_appVersion',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 11)),
                          ),
                        ),
                      ),
                      Divider(height: 1, color: Colors.grey.shade100),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            leading: Icon(Icons.favorite_outline,
                                color: Colors.red.shade300, size: 20),
                            title: const Text('Made for Filipino Store Owners',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87)),
                            subtitle: Text('For your business 🇵🇭',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 11)),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save Settings',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
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
