import 'package:flutter/material.dart';
import '../screens/expenses_screen.dart';
import '../screens/lista_screen.dart';
import '../screens/inventory_screen.dart';
import '../screens/cash_drawer_screen.dart';
import '../screens/daily_summary_screen.dart';
import '../screens/loyalty_screen.dart';
import '../screens/installment_screen.dart';
import '../screens/store_screen.dart';
import '../screens/printer_screen.dart';
import '../screens/barcode_scanner_screen.dart';

class QuickActionButtons extends StatefulWidget {
  const QuickActionButtons({super.key});
  @override
  State<QuickActionButtons> createState() => _QuickActionButtonsState();
}

class _QuickActionButtonsState extends State<QuickActionButtons> {
  bool _showMore = false;

  @override
  Widget build(BuildContext context) {
    final mainActions = [
      _QA('Lista ng Utang', Icons.list_alt_outlined, const Color(0xFFE65100),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ListaScreen()))),
      _QA('Dagdag Stock', Icons.inventory_2_outlined, const Color(0xFF1565C0),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const InventoryScreen()))),
      _QA('Gastusin', Icons.receipt_long_outlined, const Color(0xFFC62828),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ExpensesScreen()))),
      _QA('Cash Drawer', Icons.account_balance_wallet_outlined,
          const Color(0xFF2E7D32),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => CashDrawerScreen()))),
    ];

    final moreActions = [
      _QA('Buod ng Araw', Icons.bar_chart_outlined, const Color(0xFF283593),
          () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const DailySummaryScreen()))),
      _QA('Loyalty', Icons.card_membership_outlined, const Color(0xFFF57F17),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => LoyaltyScreen()))),
      _QA('Installment', Icons.credit_score_outlined, const Color(0xFF6A1B9A),
          () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const InstallmentScreen()))),
      _QA('Tindahan', Icons.store_outlined, const Color(0xFF00695C),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const StoreScreen()))),
      _QA('I-print', Icons.print_outlined, const Color(0xFF4E342E),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PrinterScreen()))),
      _QA('Barcode', Icons.qr_code_scanner_outlined, const Color(0xFF00838F),
          () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const BarcodeScannerScreen()))),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main 4 actions
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: mainActions.map(_buildBtn).toList(),
        ),
        const SizedBox(height: 8),

        // Toggle button
        GestureDetector(
          onTap: () => setState(() => _showMore = !_showMore),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _showMore ? 'Itago ang Tools' : 'Iba pang Tools',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600]),
                ),
                const SizedBox(width: 6),
                Icon(
                  _showMore
                      ? Icons.keyboard_arrow_up_outlined
                      : Icons.keyboard_arrow_down_outlined,
                  size: 20,
                  color: Colors.grey[500],
                ),
              ],
            ),
          ),
        ),

        // More actions
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
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: a.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(a.icon, color: a.color, size: 22),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  a.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600),
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