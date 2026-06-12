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

const _blue = Color(0xFF1E3A8A);

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
      _storeName = prefs.getString('store_name') ?? 'TindaPH';
      _storeAddress = prefs.getString('store_address') ?? '';
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
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Receipt from $_storeName\n${DateHelper.formatDate(widget.sale.createdAt)}',
        ),
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
                  content: Text('Could not capture receipt.'),
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
          content: Text('Saved to Gallery!'),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: const Text('Receipt',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        actions: [
          IconButton(
            icon: _sharing
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2))
                : const Icon(Icons.share_outlined,
                    color: Colors.black54, size: 22),
            tooltip: 'Share',
            onPressed: _sharing ? null : _shareReceipt,
          ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2))
                : const Icon(Icons.save_alt_outlined,
                    color: Colors.black54, size: 22),
            tooltip: 'Save to Gallery',
            onPressed: _saving ? null : _saveToGallery,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child:
              Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [

          // ── Receipt Card ───────────────────────────
          RepaintBoundary(
            key: _receiptKey,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: Colors.grey.shade200),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [

                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                      20, 22, 20, 22),
                  color: _blue,
                  child: Column(children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.store,
                                  color: Colors.white,
                                  size: 28),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _storeName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
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
                                .withValues(alpha: 0.75),
                            fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Text(
                        '#${sale.id.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1),
                      ),
                    ),
                  ]),
                ),

                // Body
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [

                    // Date + Status
                    Row(children: [
                      _infoChip(
                          Icons.calendar_today_outlined,
                          DateHelper.formatDate(
                              sale.createdAt)),
                      const SizedBox(width: 6),
                      _infoChip(Icons.access_time_outlined,
                          DateHelper.formatTime(
                              sale.createdAt)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: sale.isVoided
                              ? Colors.red
                                  .withValues(alpha: 0.08)
                              : Colors.green.shade50,
                          borderRadius:
                              BorderRadius.circular(6),
                          border: Border.all(
                            color: sale.isVoided
                                ? Colors.red.shade200
                                : Colors.green.shade200,
                          ),
                        ),
                        child: Text(
                          sale.isVoided ? 'VOID' : 'PAID',
                          style: TextStyle(
                            color: sale.isVoided
                                ? Colors.red
                                : Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ]),

                    if (sale.customerName != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.grey.shade200),
                        ),
                        child: Row(children: [
                          Icon(Icons.person_outlined,
                              size: 14,
                              color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text(sale.customerName!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.black87)),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 14),
                    _dottedDivider(),
                    const SizedBox(height: 12),

                    // Items header
                    Row(children: [
                      Expanded(
                        flex: 4,
                        child: Text('ITEM',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                                color: Colors.grey[500],
                                letterSpacing: 0.5)),
                      ),
                      Text('QTY',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                              color: Colors.grey[500])),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 70,
                        child: Text('AMOUNT',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                                color: Colors.grey[500],
                                letterSpacing: 0.5)),
                      ),
                    ]),
                    const SizedBox(height: 10),

                    // Items
                    ...sale.items.map((item) => Padding(
                          padding: const EdgeInsets.only(
                              bottom: 10),
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
                                        fontSize: 13,
                                        color:
                                            Colors.black87)),
                                Text(
                                    CurrencyFormatter.format(
                                        item.price),
                                    style: TextStyle(
                                        color:
                                            Colors.grey[500],
                                        fontSize: 11)),
                              ]),
                            ),
                            Text('×${item.quantity}',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600])),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 70,
                              child: Text(
                                CurrencyFormatter.format(
                                    item.subtotal),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.black87),
                              ),
                            ),
                          ]),
                        )),

                    _dottedDivider(),
                    const SizedBox(height: 10),

                    // Totals
                    if (sale.cashPaid > 0)
                      _totalRow('Cash received',
                          CurrencyFormatter.format(
                              sale.cashPaid)),
                    if (sale.change > 0)
                      _totalRow('Change',
                          CurrencyFormatter.format(
                              sale.change)),
                    if (sale.creditAmount > 0)
                      _totalRow('Credit',
                          CurrencyFormatter.format(
                              sale.creditAmount),
                          color: Colors.orange),
                    const SizedBox(height: 8),

                    // Grand Total
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.06),
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                _blue.withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        const Text('TOTAL',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: _blue)),
                        const Spacer(),
                        Text(
                          CurrencyFormatter.format(
                              sale.totalAmount),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: _blue),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),

                    // Payment type badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.grey.shade200),
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
                                    : Icons
                                        .phone_android_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            sale.type == PaymentType.cash
                                ? 'Cash'
                                : sale.type ==
                                        PaymentType.credit
                                    ? 'Credit'
                                    : 'Online Payment',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 18),
                    _dottedDivider(),
                    const SizedBox(height: 14),

                    // Footer
                    Center(
                      child: Column(children: [
                        const Text('Thank you!',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text('Please come again.',
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12)),
                        const SizedBox(height: 10),
                        Text(
                          'Powered by TindaPH',
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 10),
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
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2))
                    : const Icon(Icons.share_outlined,
                        size: 16),
                label: const Text('Share',
                    style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _blue,
                  side: BorderSide(
                      color: _blue.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(
                      vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveToGallery,
                icon: _saving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2))
                    : const Icon(Icons.save_alt_outlined,
                        size: 16),
                label: const Text('Save to Gallery',
                    style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10)),
                ),
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
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: Colors.grey[600], fontSize: 10)),
        ]),
      );

  Widget _totalRow(String label, String value,
          {Color? color}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey[600], fontSize: 12)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: color ?? Colors.black87)),
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