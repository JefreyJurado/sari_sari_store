import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../utils/currency_formatter.dart';
import '../theme/app_theme.dart';

const _blue = AppColors.blue;

class InventoryLogScreen extends StatefulWidget {
  const InventoryLogScreen({super.key});
  @override
  State<InventoryLogScreen> createState() => _InventoryLogScreenState();
}

class _InventoryLogScreenState extends State<InventoryLogScreen> {
  late String _selectedMonth;
  List<Map<String, dynamic>> _snapshot = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
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
          // Current month (historical months aren't tracked — see note below)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.white,
            child: Row(children: [
              const Icon(Icons.calendar_month_outlined, size: 16, color: _blue),
              const SizedBox(width: 8),
              const Text('Month:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Text(_formatMonth(_selectedMonth),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _blue)),
            ]),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Only the current month can be shown accurately — past-month stock history isn\'t recorded yet.',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
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
                    : Builder(builder: (_) {
                        final sorted = List<Map<String, dynamic>>.from(_snapshot)
                          ..sort((a, b) => (b['stockSold'] as num).compareTo(a['stockSold'] as num));
                        return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: sorted.length,
                        itemBuilder: (_, i) {
                          final p = sorted[i];
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
                        );
                      }),
          ),
        ],
      ),
    );
  }
}