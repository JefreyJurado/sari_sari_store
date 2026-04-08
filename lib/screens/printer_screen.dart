import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_provider.dart';
import '../models/transaction.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';

class PrinterScreen extends StatefulWidget {
  final Sale? sale;
  const PrinterScreen({super.key, this.sale});
  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  String _storeName = 'TindaPH';
  String _storeAddress = '';
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _storeName =
          prefs.getString('store_name') ?? 'TindaPH';
      _storeAddress =
          prefs.getString('store_address') ?? '';
    });
  }

  String _buildReceipt(Sale sale) {
    final lines = <String>[];
    const divider = '================================';
    const thinDiv = '--------------------------------';

    lines.add(_center(_storeName, 32));
    if (_storeAddress.isNotEmpty) {
      lines.add(_center(_storeAddress, 32));
    }
    lines.add(divider);
    lines.add(
        'Petsa: ${DateHelper.formatDate(sale.createdAt)}');
    lines.add(
        'Oras:  ${DateHelper.formatTime(sale.createdAt)}');
    if (sale.customerName != null) {
      lines.add('Customer: ${sale.customerName}');
    }
    lines.add(thinDiv);
    lines.add('ITEM              QTY   PRESYO');
    lines.add(thinDiv);

    for (final item in sale.items) {
      final name = item.productName.length > 16
          ? item.productName.substring(0, 16)
          : item.productName.padRight(16);
      final qty = '${item.quantity}'.padLeft(4);
      final price =
          CurrencyFormatter.format(item.subtotal).padLeft(9);
      lines.add('$name$qty$price');
    }

    lines.add(divider);
    lines.add('TOTAL:'.padRight(23) +
        CurrencyFormatter.format(sale.totalAmount));
    if (sale.cashPaid > 0) {
      lines.add('CASH:'.padRight(23) +
          CurrencyFormatter.format(sale.cashPaid));
    }
    if (sale.change > 0) {
      lines.add('SUKLI:'.padRight(23) +
          CurrencyFormatter.format(sale.change));
    }
    if (sale.creditAmount > 0) {
      lines.add('UTANG:'.padRight(23) +
          CurrencyFormatter.format(sale.creditAmount));
    }
    lines.add(divider);
    lines.add(_center('Salamat sa inyong pagbili!', 32));
    lines.add(_center('Bumalik po kayo!', 32));
    lines.add(_center('Powered by TindaPH', 32));
    lines.add('');
    lines.add('');

    return lines.join('\n');
  }

  String _center(String text, int width) {
    if (text.length >= width) return text;
    final padding = (width - text.length) ~/ 2;
    return ' ' * padding + text;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, prov, _) {
      final sales = widget.sale != null
          ? [widget.sale!]
          : prov.sales.take(10).toList();

      return Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(title: const Text('I-print ang Resibo')),
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
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(
                  20, 16, 20, 24),
              child: Column(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color:
                        Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.print_outlined,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(height: 10),
                const Text('Thermal Printer',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  'I-share ang receipt sa iyong printer app',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12),
                ),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Setup info card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          Colors.blue.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                      const Row(children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue, size: 16),
                        SizedBox(width: 8),
                        Text('Thermal Printer Setup',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                fontSize: 13)),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        '1. I-pair ang Bluetooth printer sa phone\n'
                        '2. I-install ang printer app ng manufacturer\n'
                        '3. I-tap ang "I-share" para ipadala sa printer app',
                        style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            height: 1.6),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  const Text('Preview ng Resibo',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  const SizedBox(height: 10),

                  if (sales.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                          child: Text('Walang benta pa')),
                    )
                  else
                    ...sales.map((sale) => Container(
                          margin: const EdgeInsets.only(
                              bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(children: [
                            ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E7D32)
                                      .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                    Icons.receipt_outlined,
                                    color: Color(0xFF2E7D32),
                                    size: 20),
                              ),
                              title: Text(
                                  sale.customerName ??
                                      'Cash Sale',
                                  style: const TextStyle(
                                      fontWeight:
                                          FontWeight.w600,
                                      fontSize: 14)),
                              subtitle: Text(
                                  '${sale.items.length} item  •  ${DateHelper.formatDate(sale.createdAt)}',
                                  style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12)),
                              trailing: Text(
                                  CurrencyFormatter.format(
                                      sale.totalAmount),
                                  style: const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      color:
                                          Color(0xFF2E7D32))),
                            ),
                            const Divider(height: 1),

                            // Receipt preview
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  border: Border.all(
                                      color:
                                          Colors.grey.shade200),
                                ),
                                child: Text(
                                  _buildReceipt(sale),
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),

                            // Buttons
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(
                                      12, 0, 12, 14),
                              child: Row(children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      final receipt =
                                          _buildReceipt(sale);
                                      showDialog(
                                        context: context,
                                        builder: (_) =>
                                            AlertDialog(
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                          16)),
                                          title: const Text(
                                              'Receipt Text'),
                                          content:
                                              SingleChildScrollView(
                                            child: SelectableText(
                                              receipt,
                                              style:
                                                  const TextStyle(
                                                fontFamily:
                                                    'monospace',
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          actions: [
                                            ElevatedButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                        context),
                                                child: const Text(
                                                    'OK')),
                                          ],
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                        Icons.visibility_outlined,
                                        size: 18),
                                    label:
                                        const Text('I-preview'),
                                    style:
                                        OutlinedButton.styleFrom(
                                            padding:
                                                const EdgeInsets
                                                    .symmetric(
                                                    vertical: 12)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _sharing
                                        ? null
                                        : () async {
                                            setState(() =>
                                                _sharing = true);
                                            final receipt =
                                                _buildReceipt(
                                                    sale);
                                            await Share.share(
                                              receipt,
                                              subject:
                                                  'Receipt - $_storeName',
                                            );
                                            if (mounted) {
                                              setState(() =>
                                                  _sharing =
                                                      false);
                                            }
                                          },
                                    icon: _sharing
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child:
                                                CircularProgressIndicator(
                                                    color: Colors
                                                        .white,
                                                    strokeWidth:
                                                        2))
                                        : const Icon(
                                            Icons.share_outlined,
                                            size: 18),
                                    label:
                                        const Text('I-share'),
                                    style:
                                        ElevatedButton.styleFrom(
                                            padding:
                                                const EdgeInsets
                                                    .symmetric(
                                                    vertical: 12)),
                                  ),
                                ),
                              ]),
                            ),
                          ]),
                        )),
                ],
              ),
            ),
          ]),
        ),
      );
    });
  }
}