import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/capital_entry.dart';
import '../utils/currency_formatter.dart';
import '../theme/app_theme.dart';
import '../widgets/center_toast.dart';

const _blue = AppColors.blue;

class CapitalScreen extends StatefulWidget {
  const CapitalScreen({super.key});
  @override
  State<CapitalScreen> createState() => _CapitalScreenState();
}

class _CapitalScreenState extends State<CapitalScreen> {
  bool _isEditing = false;
  bool _loaded = false;
  List<Map<String, dynamic>> _setupItems = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    final prov = context.read<AppProvider>();
    final cap = prov.capital;
    // Dispose whatever controllers are currently loaded first — this is
    // also called from the "Cancel" button to discard uncommitted edits
    // (including locally-added-but-unsaved items), not just at initState.
    for (final item in _setupItems) {
      (item['ctrl'] as TextEditingController).dispose();
      (item['amtCtrl'] as TextEditingController).dispose();
      (item['vendorCtrl'] as TextEditingController).dispose();
    }
    _setupItems = (cap?.setupItems ?? []).map<Map<String, dynamic>>((i) {
      final amtCtrl = TextEditingController(text: i.amount.toStringAsFixed(2));
      amtCtrl.addListener(() => setState(() {}));
      return {
        'ctrl': TextEditingController(text: i.label),
        'amtCtrl': amtCtrl,
        'vendorCtrl': TextEditingController(text: i.vendor ?? ''),
        'category': i.category, // Assuming category is an enum, adjust if it's a string
        'paymentMethod': i.paymentMethod.toString().trim(),
        'date': i.date,
      };
    }).toList();
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final item in _setupItems) {
      (item['ctrl'] as TextEditingController).dispose();
      (item['amtCtrl'] as TextEditingController).dispose();
      (item['vendorCtrl'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final prov = context.read<AppProvider>();
    final setupItems = _setupItems
        .map((item) {
          // Explicitly cast and default check safely
          final selectedCategory = (item['category'] as String?)?.isNotEmpty == true 
              ? item['category'] as String 
              : 'Equipment';
          final selectedPayment = (item['paymentMethod'] as String?)?.isNotEmpty == true 
              ? item['paymentMethod'] as String 
              : 'Cash';
          
          return SetupCostItem(
            label: (item['ctrl'] as TextEditingController).text.trim(),
            amount: double.tryParse(
                    (item['amtCtrl'] as TextEditingController).text) ?? 0,
            category: selectedCategory,
            vendor: (item['vendorCtrl'] as TextEditingController).text.trim().isEmpty
                ? null
                : (item['vendorCtrl'] as TextEditingController).text.trim(),
            paymentMethod: selectedPayment,
            date: item['date'] as DateTime? ?? DateTime.now(),
          );
        })
        .where((i) => i.label.isNotEmpty)
        .toList();
    final totalSetup =
        CurrencyFormatter.roundCents(setupItems.fold(0.0, (s, i) => s + i.amount));
    await prov.saveCapital(
      setupCosts: totalSetup,
      inventoryValue: prov.currentInventoryValue,
      setupItems: setupItems,
    );
    if (mounted) {
      setState(() => _isEditing = false);
      CenterToast.showSuccess(context, 'Capital settings saved!');
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
            onPressed: () {
              if (_isEditing) _loadItems(); // Cancel: discard edits
              setState(() => _isEditing = !_isEditing);
            },
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
                                      'vendorCtrl': TextEditingController(),
                                      'category': 'Equipment',
                                      'paymentMethod': 'Cash',
                                      'date': DateTime.now(),
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
                                final itemDate = _setupItems[i]['date'] as DateTime? ?? DateTime.now();
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Column(children: [
                                    Row(children: [
                                      Expanded(
                                        flex: 3,
                                        child: TextField(
                                          controller: _setupItems[i]['ctrl'] as TextEditingController,
                                          decoration: InputDecoration(
                                            hintText: 'e.g. DTI, Equipment...',
                                            labelText: 'Description',
                                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                                            labelStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: TextField(
                                          controller: _setupItems[i]['amtCtrl'] as TextEditingController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: InputDecoration(
                                            prefixText: '₱ ',
                                            labelText: 'Amount',
                                            labelStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        onPressed: () {
                                            // Read directly via absolute indexing before mutation safely
                                            final controllersToDispose = _setupItems[i];
                                            setState(() {
                                            _setupItems.removeAt(i);
                                            });
                                            // Dispose after the widget tree releases the text element structure
                                            (controllersToDispose['ctrl'] as TextEditingController).dispose();
                                            (controllersToDispose['amtCtrl'] as TextEditingController).dispose();
                                            (controllersToDispose['vendorCtrl'] as TextEditingController).dispose();
                                        },
                                        icon: Icon(Icons.close, size: 18, color: Colors.red.shade300),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        ),
                                    ]),
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _setupItems[i]['vendorCtrl'] as TextEditingController,
                                          decoration: InputDecoration(
                                            hintText: 'Vendor (optional)',
                                            labelText: 'Vendor',
                                            labelStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                          ),
                                        ),
                                      ),
                                    ]),
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      Expanded(
                                        child: InputDecorator(
                                          decoration: InputDecoration(
                                            labelText: 'Category',
                                            labelStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: (_setupItems[i]['category'] as String?)?.isEmpty == true ? 'Equipment' : (_setupItems[i]['category'] as String? ?? 'Equipment'),
                                              isDense: true,
                                              items: SetupCostItem.categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                                              onChanged: (v) {
                                                if (v != null) {
                                                  setState(() {
                                                    _setupItems[i]['category'] = v;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: InputDecorator(
                                          decoration: InputDecoration(
                                            labelText: 'Payment',
                                            labelStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: (_setupItems[i]['paymentMethod'] as String?)?.isEmpty == true ? 'Cash' : (_setupItems[i]['paymentMethod'] as String? ?? 'Cash'),
                                              isDense: true,
                                              items: SetupCostItem.paymentMethods.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12)))).toList(),
                                              onChanged: (v) {
                                                if (v != null) {
                                                  setState(() {
                                                    _setupItems[i]['paymentMethod'] = v;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ]),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                    onTap: () async {
                                        final picked = await showDatePicker(
                                        context: context,
                                        initialDate: itemDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                        );
                                        if (picked != null) {
                                        setState(() {
                                            _setupItems[i]['date'] = picked; // Explicit list index mutate
                                        });
                                        }
                                    },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: Row(children: [
                                          Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey[500]),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${itemDate.month}/${itemDate.day}/${itemDate.year}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                          ),
                                        ]),
                                      ),
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
                              ...prov.capital!.setupItems.map((item) => Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [
                                        Expanded(
                                          child: Text(item.label,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                                        ),
                                        Text(CurrencyFormatter.format(item.amount),
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
                                      ]),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _blue.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(item.category.isEmpty ? 'Uncategorized' : item.category, 
                                          style: TextStyle(fontSize: 10, color: _blue.withValues(alpha: 0.8))),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(item.paymentMethod.isEmpty ? 'No Payment Method' : item.paymentMethod, style: TextStyle(fontSize: 10, color: Colors.green.shade700)),
                                        ),
                                        const Spacer(),
                                        if (item.vendor != null)
                                          Text(item.vendor!, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                                      ]),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.date.month}/${item.date.day}/${item.date.year}',
                                        style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                                      ),
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

                      // ── Stock Monitoring ──
                      _sectionHeader('Stock Monitoring'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(children: [
                          _detailRow(
                              'Current Inventory Value',
                              CurrencyFormatter.format(prov.currentInventoryValue),
                              Icons.inventory_2_outlined,
                              Colors.purple.shade600),
                          const SizedBox(height: 4),
                          Row(children: [
                            const SizedBox(width: 48),
                            Text(
                              'Live stock value — not included in ROI',
                              style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                            ),
                          ]),
                        ]),
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

                      // ── Break-Even Point ──
                      _sectionHeader('Break-Even Analysis'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(children: [
                          // Formula explanation
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(children: [
                              Icon(Icons.info_outline, size: 13, color: Colors.grey[400]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Break-Even = Total Fixed Expenses ÷ (Avg Sell Price - Avg Unit Cost)',
                                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 14),
                          _perfRow(
                            'Total Fixed Expenses',
                            CurrencyFormatter.format(prov.totalExpensesAmount),
                            Colors.orange.shade600,
                          ),
                          const SizedBox(height: 8),
                          _perfRow(
                            'Avg Sell Price',
                            CurrencyFormatter.format(prov.avgSellPrice),
                            Colors.green.shade600,
                          ),
                          const SizedBox(height: 8),
                          _perfRow(
                            'Avg Unit Cost',
                            CurrencyFormatter.format(prov.avgUnitCost),
                            Colors.red.shade400,
                          ),
                          Divider(height: 20, color: Colors.grey.shade200),
                          _perfRow(
                            'Break-Even Units',
                            prov.breakEvenUnits <= 0
                                ? 'N/A'
                                : '${prov.breakEvenUnits.toStringAsFixed(0)} units',
                            _blue,
                            bold: true,
                          ),
                          const SizedBox(height: 4),
                          Row(children: [
                            const SizedBox(width: 4),
                            Text(
                              prov.breakEvenUnits <= 0
                                  ? 'Add products to compute break-even'
                                  : 'Sell ${prov.breakEvenUnits.toStringAsFixed(0)} units to cover all expenses',
                              style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                            ),
                          ]),
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