import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pin_screen.dart';

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
          content: Text('Na-save ang settings! ✅'),
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
      // Confirm before disabling
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
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
                  content: Text('PIN na-remove! ✅'),
                  backgroundColor: Colors.orange));
        }
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mga Setting')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Tindahan ──────────────────────────────────
                _label('TINDAHAN'),
                Card(
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

                // ── Notifications ─────────────────────────────
                _label('NOTIFICATIONS'),
                Card(
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

                // ── Seguridad ─────────────────────────────────
                _label('SEGURIDAD'),
                Card(
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
                  Card(
                    child: ListTile(
                      leading: const Icon(
                          Icons.password_outlined,
                          color: Colors.blue),
                      title: const Text('Palitan ang PIN'),
                      subtitle:
                          const Text('Gumawa ng bagong PIN'),
                      trailing: const Icon(
                          Icons.chevron_right,
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
                            content: Text('Nabago ang PIN! ✅'),
                            backgroundColor: Colors.green,
                          ));
                        }
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // ── Tungkol sa App ────────────────────────────
                _label('TUNGKOL SA APP'),
                Card(
                  child: Column(children: [
                    const ListTile(
                      leading: Icon(Icons.phone_android_outlined),
                      title: Text('TindaPH'),
                      subtitle: Text('Version 1.0.0'),
                    ),
                    const Divider(height: 1),
                    const ListTile(
                      leading: Icon(Icons.favorite_outline,
                          color: Colors.red),
                      title: Text('Gawa para sa mga Pilipino'),
                      subtitle:
                          Text('Para sa inyong negosyo 🇵🇭'),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                // ── Save button ───────────────────────────────
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