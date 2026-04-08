import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/debt.dart';
import '../models/customer.dart';
import '../utils/currency_formatter.dart';

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
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(title: const Text('Tanggap ng Bayad')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header banner
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              padding:
                  const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor:
                      Colors.white.withValues(alpha: 0.2),
                  radius: 26,
                  child: Text(
                    widget.customer.name[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                  Text(widget.customer.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                  if (widget.customer.phone != null)
                    Text(widget.customer.phone!,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13)),
                ]),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Debt summary card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(children: [
                      _row('Orihinal na Utang:',
                          CurrencyFormatter.format(
                              widget.debt.originalAmount)),
                      const SizedBox(height: 6),
                      _row(
                          'Bayad na:',
                          CurrencyFormatter.format(
                              widget.debt.paidAmount),
                          color: Colors.green),
                      const Divider(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red
                              .withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.red
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          const Text('NATITIRA:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                  fontSize: 14)),
                          const Spacer(),
                          Text(
                            CurrencyFormatter.format(
                                widget.debt.remaining),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                                fontSize: 24),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  const Text('Halaga ng Bayad',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  const SizedBox(height: 10),

                  // Amount input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixText: '₱ ',
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: TextButton(
                          onPressed: () {
                            setState(() {
                              _amountCtrl.text = widget.debt
                                  .remaining
                                  .toStringAsFixed(2);
                            });
                          },
                          child: const Text('BUONG\nBAYAD',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),

                  // Change indicator
                  if (_amount > 0 &&
                      _amount <= widget.debt.remaining) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32)
                            .withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Color(0xFF2E7D32),
                            size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Matitira: ${CurrencyFormatter.format(widget.debt.remaining - _amount)}',
                          style: const TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                        ),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Notes
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _notesCtrl,
                      decoration: InputDecoration(
                        labelText: 'Mga tala (optional)',
                        prefixIcon: const Icon(
                            Icons.notes_outlined),
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _isProcessing ? null : _process,
                      style: ElevatedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 16)),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2))
                          : const Text('I-record ang Bayad',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) =>
      Row(children: [
        Text(label,
            style: TextStyle(color: Colors.grey[600])),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 14)),
      ]);

  Future<void> _process() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ilagay ang tamang halaga!'),
              backgroundColor: Colors.red));
      return;
    }
    if (amount > widget.debt.remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Hindi pwedeng mas malaki sa utang!'),
              backgroundColor: Colors.red));
      return;
    }
    setState(() => _isProcessing = true);
    await context.read<AppProvider>().recordPayment(
          widget.debt,
          amount,
          notes: _notesCtrl.text.isEmpty
              ? null
              : _notesCtrl.text,
        );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Natanggap ang bayad na ${CurrencyFormatter.format(amount)}!'),
        backgroundColor: Colors.green));
  }
}