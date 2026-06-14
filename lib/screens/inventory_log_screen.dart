import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../utils/currency_formatter.dart';

const _blue = Color(0xFF1E3A8A);

class InventoryLogScreen extends StatefulWidget {
  const InventoryLogScreen({super.key});
  @override
  State<InventoryLogScreen> createState() => _InventoryLogScreenState();
}

class _InventoryLogScreenState extends State<InventoryLogScreen> {
  final List<String> _months = _generateMonths();
  late String _selectedMonth;
  List<Map<String, dynamic>> _snapshot = [];
  bool _loading = true;

  static List<String> _generateMonths() {
    final now = DateTime.now();
    final months = <String>[];
    for (int i = 0; i < 12; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      months.add('${d.year}-${d.month.toString().padLeft(2, '0')}');
    }
    return months;
  }

  @override
  void initState() {
    super.initState();
    _selectedMonth = _months.first;
    _loadSnapshot();
  }

  Future<void> _loadSnapshot() async {
    setState(() => _loading = true);
    final data = await DatabaseService.instance
        .getInventorySnapshot(_selectedMonth);
    setState(() {
      _snapshot = data;
      _loading = false;
    });
  }

  String _formatMonth(String month) {
    final parts = month.split('-');
    final year = parts[0];
    final monthNames = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
    final monthName = monthNames[int.parse(parts[1]) - 1];
    return '$monthName $year';
  }

  @override
  Widget build(BuildContext context) {
    final totalValue = _snapshot.fold(
        0.0, (s, p) => s + (p['totalInventoryValue'] as num).toDouble());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Inventory Control Log',
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
      body: Column(
        children: [
          // Month selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.white,
            child: Row(children: [
              const Icon(Icons.calendar_month_outlined, size: 16, color: _blue),
              const SizedBox(width: 8),
              const Text('Month:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedMonth,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                  items: _months.map((m) => DropdownMenuItem(value: m, child: Text(_formatMonth(m), style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedMonth = v);
                      _loadSnapshot();
                    }
                  },
                ),
              ),
            ]),
          ),
          // Total value
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _blue.withValues(alpha: 0.15)),
            ),
            child: Row(children: [
              const Icon(Icons.inventory_2_outlined, size: 16, color: _blue),
              const SizedBox(width: 8),
              const Text('Total Inventory Value',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
              const Spacer(),
              Text(CurrencyFormatter.format(totalValue),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _blue)),
            ]),
          ),
          // Column headers
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Expanded(flex: 3, child: Text('Product', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54))),
              const Expanded(child: Text('Begin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54), textAlign: TextAlign.center)),
              const Expanded(child: Text('Sold', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red), textAlign: TextAlign.center)),
              const Expanded(child: Text('End', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54), textAlign: TextAlign.center)),
              const Expanded(flex: 2, child: Text('Value', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _blue), textAlign: TextAlign.right)),
            ]),
          ),
          const SizedBox(height: 8),
          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _snapshot.isEmpty
                    ? Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('No inventory data', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                        ]),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _snapshot.length,
                        itemBuilder: (_, i) {
                          final p = _snapshot[i];
                          final endingStock = (p['endingStock'] as num).toInt();
                          final stockSold = (p['stockSold'] as num).toInt();
                          final beginningStock = (p['beginningStock'] as num).toInt();
                          final value = (p['totalInventoryValue'] as num).toDouble();
                          final unitCost = (p['unitCost'] as num).toDouble();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(p['productName'] as String,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                                ),
                                Expanded(
                                  child: Text('$beginningStock',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      textAlign: TextAlign.center),
                                ),
                                Expanded(
                                  child: Text('$stockSold',
                                      style: TextStyle(fontSize: 12, color: stockSold > 0 ? Colors.red.shade600 : Colors.grey[400]),
                                      textAlign: TextAlign.center),
                                ),
                                Expanded(
                                  child: Text('$endingStock',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                                      textAlign: TextAlign.center),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(CurrencyFormatter.format(value),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _blue),
                                      textAlign: TextAlign.right),
                                ),
                              ]),
                              const SizedBox(height: 2),
                              Text('Unit Cost: ${CurrencyFormatter.format(unitCost)}',
                                  style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                            ]),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}