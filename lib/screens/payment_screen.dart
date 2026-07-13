import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/debt.dart';
import '../models/customer.dart';
import '../utils/currency_formatter.dart';
import '../theme/app_theme.dart';
import '../widgets/center_toast.dart';

const _blue = AppColors.blue;

class PaymentScreen extends StatefulWidget {
  final Debt debt;
  final Customer customer;
  const PaymentScreen(
      {super.key, required this.debt, required this.customer});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isProcessing = false;

  double get _amount =>
      double.tryParse(_amountCtrl.text) ?? 0;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text =
        widget.debt.remaining.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
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
        title: const Text('Accept Payment',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child:
              Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Customer Info ──────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _blue.withValues(alpha: 0.15)),
              ),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor:
                      _blue.withValues(alpha: 0.12),
                  radius: 22,
                  child: Text(
                    widget.customer.name[0].toUpperCase(),
                    style: const TextStyle(
                        color: _blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                  Text(widget.customer.name,
                      style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  if (widget.customer.phone != null)
                    Text(widget.customer.phone!,
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12)),
                ]),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Debt Summary ───────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.grey.shade200),
              ),
              child: Column(children: [
                _row('Original amount:',
                    CurrencyFormatter.format(
                        widget.debt.originalAmount)),
                const SizedBox(height: 6),
                _row('Amount paid:',
                    CurrencyFormatter.format(
                        widget.debt.paidAmount),
                    color: Colors.green),
                Divider(
                    height: 20, color: Colors.grey.shade200),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.grey.shade200),
                  ),
                  child: Row(children: [
                    Text('Balance',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                            fontSize: 13)),
                    const Spacer(),
                    Text(
                      CurrencyFormatter.format(
                          widget.debt.remaining),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontSize: 22),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Payment Amount ─────────────────────────
            Text('Payment Amount',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.grey[700])),
            const SizedBox(height: 8),

            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(
                      decimal: true),
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixText: '₱ ',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Colors.grey.shade300)),
                suffixIcon: TextButton(
                  onPressed: () => setState(() {
                    _amountCtrl.text = widget.debt.remaining
                        .toStringAsFixed(2);
                  }),
                  child: const Text('FULL\nPAY',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _blue)),
                ),
              ),
            ),

            // Remaining after payment
            if (_amount > 0 &&
                _amount <= widget.debt.remaining) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _blue.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Icon(
                      Icons.account_balance_wallet_outlined,
                      color: _blue.withValues(alpha: 0.6),
                      size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Remaining after payment: ${CurrencyFormatter.format(widget.debt.remaining - _amount)}',
                    style: const TextStyle(
                        color: _blue,
                        fontWeight: FontWeight.w500,
                        fontSize: 13),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 14),

            // ── Notes ──────────────────────────────────
            TextField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                labelStyle: TextStyle(
                    color: Colors.grey[600], fontSize: 13),
                prefixIcon: Icon(Icons.notes_outlined,
                    color: Colors.grey[500], size: 18),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Colors.grey.shade300)),
              ),
            ),
            const SizedBox(height: 28),

            // ── Submit ──────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _process,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10)),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2))
                    : const Text('Record Payment',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value,
          {Color? color}) =>
      Row(children: [
        Text(label,
            style: TextStyle(
                color: Colors.grey[600], fontSize: 13)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color ?? Colors.black87,
                fontSize: 13)),
      ]);

  Future<void> _process() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      CenterToast.showError(context, 'Enter a valid amount.');
      return;
    }
    final prov = context.read<AppProvider>();
    // Re-check against the freshest known balance rather than the
    // snapshot this screen was opened with, in case another payment on
    // this same debt landed in the meantime.
    final currentDebt = prov.debts
        .where((d) => d.id == widget.debt.id)
        .firstOrNull ?? widget.debt;
    if (amount > currentDebt.remaining) {
      CenterToast.showError(context, 'Amount cannot exceed balance.');
      return;
    }
    setState(() => _isProcessing = true);
    await prov.recordPayment(
          currentDebt,
          amount,
          notes: _notesCtrl.text.isEmpty
              ? null
              : _notesCtrl.text,
        );
    if (!mounted) return;
    Navigator.pop(context);
    CenterToast.showSuccess(
        context, 'Payment of ${CurrencyFormatter.format(amount)} recorded!');
  }
}