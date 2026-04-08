import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:gal/gal.dart';
import '../models/transaction.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';

class ReceiptScreen extends StatefulWidget {
  final Sale sale;
  const ReceiptScreen({super.key, required this.sale});
  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final _receiptKey = GlobalKey();
  String _storeName = 'TindaPH';
  String _storeAddress = '';
  bool _saving = false;
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

  Future<Uint8List?> _captureReceipt() async {
    try {
      final boundary = _receiptKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(
          format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareReceipt() async {
    setState(() => _sharing = true);
    try {
      final bytes = await _captureReceipt();
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/receipt_${widget.sale.id.substring(0, 8)}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Receipt mula sa $_storeName\n${DateHelper.formatDate(widget.sale.createdAt)}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _sharing = false);
  }

  Future<void> _saveToGallery() async {
    setState(() => _saving = true);
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) await Gal.requestAccess();

      final bytes = await _captureReceipt();
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Hindi ma-capture!'),
                  backgroundColor: Colors.red));
        }
        setState(() => _saving = false);
        return;
      }

      final dir = await getTemporaryDirectory();
      final filename =
          'receipt_${widget.sale.id.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      await Gal.putImage(file.path, album: 'TindaPH Receipts');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
          content: Text('Na-save sa Gallery!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Receipt'),
        actions: [
          IconButton(
            icon: _sharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.share_outlined),
            tooltip: 'I-share',
            onPressed: _sharing ? null : _shareReceipt,
          ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_alt_outlined),
            tooltip: 'I-save sa Gallery',
            onPressed: _saving ? null : _saveToGallery,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Receipt Card
          RepaintBoundary(
            key: _receiptKey,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                      20, 24, 20, 24),
                  color: const Color(0xFF2E7D32),
                  child: Column(children: [
                    // Logo
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color:
                            Colors.white.withValues(alpha: 0.2),
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.store,
                                  color: Colors.white,
                                  size: 32),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _storeName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5),
                      textAlign: TextAlign.center,
                    ),
                    if (_storeAddress.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _storeAddress,
                        style: TextStyle(
                            color: Colors.white
                                .withValues(alpha: 0.8),
                            fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Receipt number badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '#${sale.id.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1),
                      ),
                    ),
                  ]),
                ),

                // Receipt body
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                    // Date/Time row
                    Row(children: [
                      _infoChip(Icons.calendar_today_outlined,
                          DateHelper.formatDate(sale.createdAt)),
                      const SizedBox(width: 8),
                      _infoChip(Icons.access_time_outlined,
                          DateHelper.formatTime(sale.createdAt)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: sale.isVoided
                              ? Colors.red
                                  .withValues(alpha: 0.1)
                              : const Color(0xFF2E7D32)
                                  .withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                            color: sale.isVoided
                                ? Colors.red
                                : const Color(0xFF2E7D32),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          sale.isVoided ? 'VOID' : 'BAYAD',
                          style: TextStyle(
                            color: sale.isVoided
                                ? Colors.red
                                : const Color(0xFF2E7D32),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ]),

                    if (sale.customerName != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          const Icon(Icons.person_outlined,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(sale.customerName!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 16),
                    _dottedDivider(),
                    const SizedBox(height: 14),

                    // Items header
                    Row(children: [
                      const Expanded(
                        flex: 4,
                        child: Text('PRODUKTO',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Colors.grey,
                                letterSpacing: 0.5)),
                      ),
                      const Text('QTY',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Colors.grey)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 75,
                        child: const Text('HALAGA',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Colors.grey,
                                letterSpacing: 0.5)),
                      ),
                    ]),
                    const SizedBox(height: 10),

                    // Items
                    ...sale.items.map((item) => Padding(
                          padding: const EdgeInsets.only(
                              bottom: 12),
                          child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                Text(item.productName,
                                    style: const TextStyle(
                                        fontWeight:
                                            FontWeight.w600,
                                        fontSize: 13)),
                                Text(
                                    CurrencyFormatter.format(
                                        item.price),
                                    style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 11)),
                              ]),
                            ),
                            Text('×${item.quantity}',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600])),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 75,
                              child: Text(
                                CurrencyFormatter.format(
                                    item.subtotal),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                            ),
                          ]),
                        )),

                    _dottedDivider(),
                    const SizedBox(height: 12),

                    // Totals
                    if (sale.cashPaid > 0)
                      _totalRow('Cash Ibinigay',
                          CurrencyFormatter.format(
                              sale.cashPaid)),
                    if (sale.change > 0)
                      _totalRow(
                          'Sukli',
                          CurrencyFormatter.format(
                              sale.change),
                          color: Colors.blue),
                    if (sale.creditAmount > 0)
                      _totalRow(
                          'Utang',
                          CurrencyFormatter.format(
                              sale.creditAmount),
                          color: Colors.orange),
                    const SizedBox(height: 8),

                    // Grand Total
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32)
                            .withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF2E7D32)
                                .withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        const Text('KABUUAN',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF2E7D32))),
                        const Spacer(),
                        Text(
                          CurrencyFormatter.format(
                              sale.totalAmount),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: Color(0xFF2E7D32)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),

                    // Payment badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sale.type == PaymentType.cash
                              ? const Color(0xFF2E7D32)
                                  .withValues(alpha: 0.08)
                              : Colors.orange
                                  .withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                            color: sale.type == PaymentType.cash
                                ? const Color(0xFF2E7D32)
                                    .withValues(alpha: 0.4)
                                : Colors.orange
                                    .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          Icon(
                            sale.type == PaymentType.cash
                                ? Icons.payments_outlined
                                : sale.type ==
                                        PaymentType.credit
                                    ? Icons.credit_card_outlined
                                    : Icons.phone_android_outlined,
                            size: 16,
                            color: sale.type == PaymentType.cash
                                ? const Color(0xFF2E7D32)
                                : Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            sale.type == PaymentType.cash
                                ? 'Cash Payment'
                                : sale.type ==
                                        PaymentType.credit
                                    ? 'Utang'
                                    : 'Online Payment',
                            style: TextStyle(
                              color: sale.type ==
                                      PaymentType.cash
                                  ? const Color(0xFF2E7D32)
                                  : Colors.orange,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 20),
                    _dottedDivider(),
                    const SizedBox(height: 16),

                    // Footer
                    Center(
                      child: Column(children: [
                        const Text(
                            'Salamat sa inyong pagbili!',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Bumalik po kayo!',
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12)),
                        const SizedBox(height: 12),
                        Text(
                          'Powered by TindaPH 🇵🇭',
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 8),
                  ]),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _sharing ? null : _shareReceipt,
                icon: _sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2))
                    : const Icon(Icons.share_outlined),
                label: const Text('I-share'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveToGallery,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2))
                    : const Icon(Icons.save_alt_outlined),
                label: const Text('I-save sa Gallery'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14)),
              ),
            ),
          ]),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: Colors.grey[600], fontSize: 11)),
        ]),
      );

  Widget _totalRow(String label, String value,
          {Color? color}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey[600], fontSize: 13)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: color)),
        ]),
      );

  Widget _dottedDivider() => Row(
        children: List.generate(
          50,
          (i) => Expanded(
            child: Container(
              height: 1,
              color: i.isEven
                  ? Colors.grey[300]
                  : Colors.transparent,
            ),
          ),
        ),
      );
}