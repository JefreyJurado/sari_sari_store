import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../models/store.dart';
import '../theme/app_theme.dart';
import '../widgets/center_toast.dart';

const _uuid = Uuid();

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  List<Store> _stores = [];
  String _activeStoreId = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final storesJson = prefs.getString('stores') ?? '[]';
    _activeStoreId = prefs.getString('active_store_id') ?? '';

    try {
      final list = jsonDecode(storesJson) as List;
      _stores =
          list.map((s) => Store.fromMap(s as Map<String, dynamic>)).toList();
    } catch (_) {}

    if (_stores.isEmpty) {
      _stores = [
        Store(
          id: _uuid.v4(),
          name: 'Aming Sari-Sari Store',
          createdAt: DateTime.now(),
        )
      ];
      _activeStoreId = _stores.first.id;
      await _save();
    }

    if (_activeStoreId.isEmpty) {
      _activeStoreId = _stores.first.id;
      await _save();
    }

    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'stores', jsonEncode(_stores.map((s) => s.toMap()).toList()));
    await prefs.setString('active_store_id', _activeStoreId);
  }

  void _showForm({Store? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name);
    final addressCtrl = TextEditingController(text: existing?.address);
    final phoneCtrl = TextEditingController(text: existing?.phone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Text(existing == null ? 'Dagdag Tindahan' : 'I-edit ang Tindahan',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _field(nameCtrl, 'Pangalan ng Tindahan *', Icons.store_outlined),
          const SizedBox(height: 12),
          _field(addressCtrl, 'Address (optional)', Icons.location_on_outlined),
          const SizedBox(height: 12),
          _field(phoneCtrl, 'Numero (optional)', Icons.phone_outlined,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                if (existing == null) {
                  final store = Store(
                    id: _uuid.v4(),
                    name: nameCtrl.text.trim(),
                    address: addressCtrl.text.trim().isEmpty
                        ? null
                        : addressCtrl.text.trim(),
                    phone: phoneCtrl.text.trim().isEmpty
                        ? null
                        : phoneCtrl.text.trim(),
                    createdAt: DateTime.now(),
                  );
                  _stores.add(store);
                } else {
                  final idx = _stores.indexWhere((s) => s.id == existing.id);
                  if (idx != -1) {
                    _stores[idx] = existing.copyWith(
                      name: nameCtrl.text.trim(),
                      address: addressCtrl.text.trim().isEmpty
                          ? null
                          : addressCtrl.text.trim(),
                      phone: phoneCtrl.text.trim().isEmpty
                          ? null
                          : phoneCtrl.text.trim(),
                    );
                  }
                }
                await _save();
                setState(() {});
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(
                existing == null
                    ? 'I-save ang Tindahan'
                    : 'I-update ang Tindahan',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final activeStore =
        _stores.where((s) => s.id == _activeStoreId).firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: const Text('Mga Tindahan',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // ── Gradient Header ────────────────────────────
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1B5E20),
                      AppColors.green,
                      Color(0xFF388E3C),
                      Color(0xFF43A047),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Stack(children: [
                  ...[
                    [20.0, 10.0],
                    [280.0, 8.0],
                    [150.0, 5.0],
                    [310.0, 40.0],
                    [50.0, 50.0],
                  ].map((pos) => Positioned(
                        left: pos[0],
                        top: pos[1],
                        child: Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                      )),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Active store info
                        Row(children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.store_outlined,
                                color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Aktibong Tindahan',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 2),
                                Text(
                                  activeStore?.name ?? 'Walang aktibo',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                if (activeStore?.address != null)
                                  Text(activeStore!.address!,
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Column(children: [
                              Text('${_stores.length}',
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              const Text('tindahan',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.white70)),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 14),

                        // Info tip
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: const Row(children: [
                            Icon(Icons.touch_app_outlined,
                                color: Colors.white70, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'I-tap ang tindahan para i-set bilang aktibo.',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),

              // ── Store List ─────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: _stores.map((store) {
                    final isActive = store.id == _activeStoreId;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: isActive
                            ? Border.all(
                                color: AppColors.green, width: 2)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: isActive
                                ? AppColors.green.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            onTap: () async {
                              setState(() => _activeStoreId = store.id);
                              await _save();
                              if (mounted) {
                                CenterToast.showSuccess(
                                    context, '${store.name} ang aktibong tindahan na!');
                              }
                            },
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.green
                                    : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.store_outlined,
                                  color: isActive ? Colors.white : Colors.grey,
                                  size: 22),
                            ),
                            title: Row(children: [
                              Expanded(
                                child: Text(store.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15)),
                              ),
                              if (isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: AppColors.green,
                                      borderRadius: BorderRadius.circular(6)),
                                  child: const Text('AKTIBO',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                            ]),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (store.address != null)
                                  Text(store.address!,
                                      style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12)),
                                if (store.phone != null)
                                  Text(store.phone!,
                                      style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12)),
                              ],
                            ),
                            trailing: PopupMenuButton(
                              icon: Icon(Icons.more_vert,
                                  color: Colors.grey[400], size: 20),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'edit',
                                    child: Row(children: [
                                      Icon(Icons.edit_outlined,
                                          size: 18, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('I-edit'),
                                    ])),
                                PopupMenuItem(
                                    value: 'delete',
                                    child: Row(children: [
                                      Icon(Icons.delete_outline,
                                          size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Burahin',
                                          style: TextStyle(color: Colors.red)),
                                    ])),
                              ],
                              onSelected: (v) async {
                                if (v == 'edit') {
                                  _showForm(existing: store);
                                } else if (v == 'delete') {
                                  if (_stores.length <= 1) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                      content: Text(
                                          'Hindi puwedeng burahin ang tanging tindahan!'),
                                      backgroundColor: Colors.red,
                                    ));
                                    return;
                                  }
                                  _stores.removeWhere((s) => s.id == store.id);
                                  if (_activeStoreId == store.id) {
                                    _activeStoreId = _stores.first.id;
                                  }
                                  await _save();
                                  setState(() {});
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add),
        label: const Text('Dagdag Tindahan'),
      ),
    );
  }
}
