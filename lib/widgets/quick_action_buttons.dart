import 'package:flutter/material.dart';
import '../screens/expenses_screen.dart';
import '../screens/lista_screen.dart';
import '../screens/inventory_screen.dart';
import '../screens/calculator_screen.dart';
import '../screens/daily_summary_screen.dart';
import '../screens/installment_screen.dart';
import '../screens/stock_alert_screen.dart';
import '../screens/barcode_scanner_screen.dart';

const _blue = Color(0xFF1E3A8A);
const _green = Color(0xFF059669);
const _orange = Color(0xFFEA580C);
const _purple = Color(0xFF7C3AED);
const _teal = Color(0xFF0891B2);
const _pink = Color(0xFFDB2777);
const _red = Color(0xFFDC2626);
const _amber = Color(0xFFD97706);

class QuickActionButtons extends StatefulWidget {
  const QuickActionButtons({super.key});
  @override
  State<QuickActionButtons> createState() =>
      _QuickActionButtonsState();
}

class _QuickActionButtonsState
    extends State<QuickActionButtons> {
  bool _showMore = false;

  @override
  Widget build(BuildContext context) {
    final mainActions = [
      _QA('Credit', Icons.list_alt_outlined, _orange,
          () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const ListaScreen()))),
      _QA('Inventory', Icons.inventory_2_outlined, _purple,
          () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const InventoryScreen()))),
      _QA('Expenses', Icons.receipt_long_outlined, _red,
          () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const ExpensesScreen()))),
      _QA('Calculator', Icons.calculate_outlined, _blue,
          () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const CalculatorScreen()))),
    ];

    final moreActions = [
      _QA('Summary', Icons.bar_chart_outlined, _teal,
          () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const DailySummaryScreen()))),
      _QA('Installment', Icons.credit_score_outlined, _green,
          () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const InstallmentScreen()))),
      _QA('Stock Alert', Icons.warning_amber_outlined, _amber,
          () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const StockAlertScreen()))),
      _QA('Barcode', Icons.qr_code_scanner_outlined, _pink,
          () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) =>
                      const BarcodeScannerScreen()))),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: mainActions.map(_buildBtn).toList(),
        ),
        const SizedBox(height: 8),

        // Toggle
        GestureDetector(
          onTap: () =>
              setState(() => _showMore = !_showMore),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _showMore ? 'Show less' : 'More tools',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600]),
                ),
                const SizedBox(width: 4),
                Icon(
                  _showMore
                      ? Icons.keyboard_arrow_up_outlined
                      : Icons.keyboard_arrow_down_outlined,
                  size: 18,
                  color: Colors.grey[500],
                ),
              ],
            ),
          ),
        ),

        if (_showMore) ...[
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: moreActions.map(_buildBtn).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildBtn(_QA a) => GestureDetector(
        onTap: a.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: a.color.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: a.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(a.icon, color: a.color, size: 20),
              ),
              const SizedBox(height: 6),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  a.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
}

class _QA {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _QA(this.label, this.icon, this.color, this.onTap);
}