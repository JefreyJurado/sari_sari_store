import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/capital_entry.dart';
import '../utils/currency_formatter.dart';

const _blue = Color(0xFF1E3A8A);

class CapitalScreen extends StatefulWidget {
  const CapitalScreen({super.key});
  @override
  State<CapitalScreen> createState() => _CapitalScreenState();
}

class _CapitalScreenState extends State<CapitalScreen> {
  bool _isEditing = false;
  bool _loaded = false;
  List<Map<String, Object>> _setupItems = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    final prov = context.read<AppProvider>();
    final cap = prov.capital;
    if (cap != null && cap.setupItems.isNotEmpty) {
      _setupItems = cap.setupItems.map<Map<String, Object>>((i) {
        final amtCtrl = TextEditingController(text: i.amount.toStringAsFixed(2));
        amtCtrl.addListener(() => setState(() {}));
        return {
          'ctrl': TextEditingController(text: i.label),
          'amtCtrl': amtCtrl,
        };
      }).toList();
    }
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final item in _setupItems) {
      (item['ctrl'] as TextEditingController).dispose();
      (item['amtCtrl'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final prov = context.read<AppProvider>();
    final setupItems = _setupItems
        .map((i) => SetupCostItem(
              label: (i['ctrl'] as TextEditingController).text.trim(),
              amount: double.tryParse(
                      (i['amtCtrl'] as TextEditingController).text) ??
                  0,
            ))
        .where((i) => i.label.isNotEmpty)
        .toList();
    final totalSetup = setupItems.fold(0.0, (s, i) => s + i.amount);
    await prov.saveCapital(
      setupCosts: totalSetup,
      inventoryValue: prov.currentInventoryValue,
      setupItems: setupItems,
    );
    if (mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Capital settings saved!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Capital Overview',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _isEditing = !_isEditing),
            icon: Icon(
                _isEditing ? Icons.close : Icons.edit_outlined,
                size: 16,
                color: _blue),
            label: Text(
                _isEditing ? 'Cancel' : 'Edit',
                style: const TextStyle(fontSize: 13, color: _blue)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Consumer<AppProvider>(
              builder: (context, prov, _) {
                final roi = prov.roiPercent;
                final isProfit = roi >= 0;
                final roiColor = isProfit
                    ? Colors.green.shade600
                    : Colors.red.shade600;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── ROI Badge ──
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: isProfit
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                                color: isProfit
                                    ? Colors.green.shade200
                                    : Colors.red.shade200),
                          ),
                          child: Text(
                            '${isProfit ? '+' : ''}${roi.toStringAsFixed(2)}% ROI',
                            style: TextStyle(
                                color: roiColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Business Setup Costs ──
                      _sectionHeader('Business Setup Costs'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(children: [

                          // Edit mode
                          if (_isEditing) ...[
                            Row(children: [
                              const Text('Setup Cost Items',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87)),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    final amtCtrl = TextEditingController(text: '0');
                                    amtCtrl.addListener(() => setState(() {}));
                                    _setupItems.add({
                                      'ctrl': TextEditingController(),
                                      'amtCtrl': amtCtrl,
                                    });
                                  });
                                },
                                icon: const Icon(Icons.add, size: 16, color: _blue),
                                label: const Text('Add Item',
                                    style: TextStyle(fontSize: 12, color: _blue)),
                                style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            if (_setupItems.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(children: [
                                  Icon(Icons.info_outline,
                                      size: 14, color: Colors.grey[400]),
                                  const SizedBox(width: 8),
                                  Text('Tap "Add Item" to add setup cost details',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey[500])),
                                ]),
                              )
                            else
                              ...List.generate(_setupItems.length, (i) {
                                final item = _setupItems[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: item['ctrl'] as TextEditingController,
                                        decoration: InputDecoration(
                                          hintText: 'e.g. DTI, Equipment...',
                                          hintStyle: TextStyle(
                                              color: Colors.grey[400], fontSize: 12),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: Colors.grey.shade300)),
                                          enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: Colors.grey.shade300)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: item['amtCtrl'] as TextEditingController,
                                        keyboardType: const TextInputType.numberWithOptions(
                                            decimal: true),
                                        decoration: InputDecoration(
                                          prefixText: '₱ ',
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: Colors.grey.shade300)),
                                          enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: Colors.grey.shade300)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      onPressed: () {
                                        (item['ctrl'] as TextEditingController).dispose();
                                        (item['amtCtrl'] as TextEditingController).dispose();
                                        setState(() => _setupItems.removeAt(i));
                                      },
                                      icon: Icon(Icons.close,
                                          size: 18, color: Colors.red.shade300),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ]),
                                );
                              }),
                            if (_setupItems.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _blue.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: _blue.withValues(alpha: 0.15)),
                                ),
                                child: Row(children: [
                                  const Text('Total Setup Cost',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87)),
                                  const Spacer(),
                                  Text(
                                    '₱${_setupItems.fold(0.0, (s, item) => s + (double.tryParse((item['amtCtrl'] as TextEditingController).text) ?? 0)).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: _blue),
                                  ),
                                ]),
                              ),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _blue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Save Capital Settings',
                                    style: TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ]

                          // View mode
                          else ...[
                            if (prov.capital?.setupItems.isNotEmpty == true) ...[
                              ...prov.capital!.setupItems.map((item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(children: [
                                      Container(
                                        width: 6, height: 6,
                                        decoration: BoxDecoration(
                                            color: _blue.withValues(alpha: 0.4),
                                            shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(item.label,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600])),
                                      ),
                                      Text(CurrencyFormatter.format(item.amount),
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87)),
                                    ]),
                                  )),
                              Divider(height: 16, color: Colors.grey.shade200),
                            ],
                            _detailRow(
                                'Total Setup Costs',
                                CurrencyFormatter.format(prov.businessSetupCosts),
                                Icons.store_mall_directory_outlined,
                                Colors.blue.shade600),
                          ],
                        ]),
                      ),
                      const SizedBox(height: 20),

                      // ── Starting Inventory ──
                      _sectionHeader('Current Inventory Value'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: _detailRow(
                            'Current Inventory Value',
                            CurrencyFormatter.format(prov.currentInventoryValue),
                            Icons.inventory_2_outlined,
                            Colors.purple.shade600),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _blue.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _blue.withValues(alpha: 0.15)),
                        ),
                        child: _detailRow(
                            'Total Investment',
                            CurrencyFormatter.format(prov.totalInvestment),
                            Icons.account_balance_outlined,
                            _blue,
                            bold: true),
                      ),
                      const SizedBox(height: 20),

                      // ── Performance ──
                      _sectionHeader('Business Performance'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(children: [
                          _perfRow('Total Sales Profit',
                              CurrencyFormatter.format(prov.totalSalesProfit),
                              Colors.green.shade600),
                          const SizedBox(height: 10),
                          _perfRow('Total Expenses',
                              '- ${CurrencyFormatter.format(prov.totalExpensesAmount)}',
                              Colors.red.shade600),
                          Divider(height: 20, color: Colors.grey.shade200),
                          _perfRow('Current Capital',
                              CurrencyFormatter.format(prov.currentCapital),
                              _blue,
                              bold: true),
                          const SizedBox(height: 8),
                          _perfRow(
                              isProfit ? 'Net Gain' : 'Net Loss',
                              '${isProfit ? '+' : ''}${CurrencyFormatter.format(prov.netGainLoss)}',
                              roiColor,
                              bold: true),
                        ]),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _sectionHeader(String title) => Text(title,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.black87));

  Widget _detailRow(String label, String value, IconData icon, Color color,
      {bool bold = false}) =>
      Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight:
                        bold ? FontWeight.w700 : FontWeight.w500))),
        Text(value,
            style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                fontSize: bold ? 15 : 13,
                color: bold ? color : Colors.black87)),
      ]);

  Widget _perfRow(String label, String value, Color color,
      {bool bold = false}) =>
      Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight:
                        bold ? FontWeight.w700 : FontWeight.w500))),
        Text(value,
            style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                fontSize: bold ? 15 : 13,
                color: bold ? color : Colors.black87)),
      ]);
}