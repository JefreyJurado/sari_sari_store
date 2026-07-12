import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_provider.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import '../utils/currency_formatter.dart';
import '../utils/filipino_categories.dart';
import '../theme/app_theme.dart';

const _uuid = Uuid();

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});
  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  MobileScannerController? _controller;
  bool _isScanning = true;
  bool _torchOn = false;
  String? _lastScanned;

  Color _flashColor = Colors.green;
  double _flashOpacity = 0.0;
  final List<_ScanRecord> _history = [];

  late AnimationController _animCtrl;
  late Animation<double> _scanAnim;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller?.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _resume() async {
    if (!mounted) return;
    setState(() {
      _isScanning = true;
      _lastScanned = null;
    });
    _animCtrl.repeat(reverse: true);
    await _controller?.start();
  }

  Future<void> _triggerFeedback(bool found) async {
    if (found) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      HapticFeedback.heavyImpact();
    }
    if (!mounted) return;
    setState(() {
      _flashColor = found ? AppColors.blue : Colors.red;
      _flashOpacity = 0.4;
    });
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) setState(() => _flashOpacity = 0.0);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_isScanning) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    final code = barcode!.rawValue!;
    if (code == _lastScanned) return;

    setState(() {
      _lastScanned = code;
      _isScanning = false;
    });
    _animCtrl.stop();
    await _controller?.stop();

    final prov = context.read<AppProvider>();
    final byBarcode = await DatabaseService.instance.getProductByBarcode(code);

    if (byBarcode != null) {
      await _triggerFeedback(true);
      _addHistory(code, byBarcode.name, true);
      _showProductFound(byBarcode, prov);
      return;
    }

    final byName = prov.products
        .where((p) => p.name.toLowerCase().contains(code.toLowerCase()))
        .toList();

    if (byName.isNotEmpty) {
      await _triggerFeedback(true);
      _addHistory(code, byName.first.name, true);
      _showProductFound(byName.first, prov);
    } else {
      await _triggerFeedback(false);
      _addHistory(code, 'Bagong Produkto', false);
      _showAddProductForm(code, prov);
    }
  }

  void _addHistory(String barcode, String name, bool found) {
    if (!mounted) return;
    setState(() {
      _history.insert(0, _ScanRecord(
          barcode: barcode, name: name, found: found, time: DateTime.now()));
      if (_history.length > 10) _history.removeLast();
    });
  }

  void _showProductFound(Product product, AppProvider prov) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 32),
          ),
          const SizedBox(height: 12),
          Text(product.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          Text(product.category, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8, offset: const Offset(0, 2),
              )],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _statCol('Presyo', CurrencyFormatter.format(product.sellPrice), AppColors.green),
              Container(width: 1, height: 40, color: Colors.grey[200]),
              _statCol('Stock', '${product.stock}', product.isOutOfStock ? Colors.red : Colors.blue),
              Container(width: 1, height: 40, color: Colors.grey[200]),
              _statCol('Tubo', CurrencyFormatter.format(product.profit), Colors.orange),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: product.isOutOfStock ? null : () {
                prov.addToCart(product);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${product.name} added to cart!'),
                  backgroundColor: Colors.green,
                ));
              },
              icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
              label: Text(product.isOutOfStock ? 'Out of Stock' : 'Add to Cart'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showAdjustStock(product, prov);
                },
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('Adjust Stock'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13), foregroundColor: Colors.blue),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showEditProduct(product, prov);
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('I-edit'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13), foregroundColor: Colors.orange),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.qr_code_scanner_outlined, size: 18),
              label: const Text('I-scan Ulit'),
            ),
          ),
        ]),
      ),
    ).then((_) => _resume());
  }

  void _showAdjustStock(Product product, AppProvider prov) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Adjust Stock'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(FilipinoCategories.getIcon(product.category), color: Colors.blue, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('Kasalukuyang stock: ${product.stock} ${product.unit ?? 'pcs'}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ])),
            ]),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Dagdag/Bawas',
              hintText: 'hal: +10 o -5',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: Colors.grey[50],
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); _resume(); }, child: const Text('Kanselahin')),
          ElevatedButton(
            onPressed: () {
              final adj = int.tryParse(ctrl.text);
              if (adj == null) return;
              final newStock = (product.stock + adj).clamp(0, 99999);
              prov.updateProduct(product.copyWith(stock: newStock));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Stock ng ${product.name} updated: $newStock ${product.unit ?? 'pcs'}'),
                backgroundColor: Colors.blue,
              ));
              _resume();
            },
            child: const Text('I-apply'),
          ),
        ],
      ),
    );
  }

  void _showEditProduct(Product product, AppProvider prov) {
    final nameCtrl = TextEditingController(text: product.name);
    final buyCtrl = TextEditingController(text: product.buyPrice.toStringAsFixed(2));
    final sellCtrl = TextEditingController(text: product.sellPrice.toStringAsFixed(2));
    final stockCtrl = TextEditingController(text: product.stock.toString());
    final unitCtrl = TextEditingController(text: product.unit ?? 'pcs');
    String category = product.category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(
                width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              )),
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_outlined, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('Edit Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
              ]),
              const SizedBox(height: 16),
              _field(nameCtrl, 'Pangalan ng Produkto *', Icons.label_outlined),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: InputDecoration(
                  labelText: 'Kategorya',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.white,
                ),
                borderRadius: BorderRadius.circular(12),
                items: FilipinoCategories.productCategories
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Row(
                            children: [
                              Icon(FilipinoCategories.getIcon(c), size: 18, color: Colors.grey[700]),
                              const SizedBox(width: 8),
                              Text(c),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setS(() => category = v!),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _field(buyCtrl, 'Presyo ng Bili', Icons.arrow_downward_outlined, keyboardType: TextInputType.number, prefix: '₱ ')),
                const SizedBox(width: 12),
                Expanded(child: _field(sellCtrl, 'Presyo ng Benta', Icons.arrow_upward_outlined, keyboardType: TextInputType.number, prefix: '₱ ')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _field(stockCtrl, 'Stock', Icons.inventory_2_outlined, keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _field(unitCtrl, 'Unit (pcs, kg...)', Icons.straighten_outlined)),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final updated = product.copyWith(
                      name: nameCtrl.text.trim(),
                      category: category,
                      buyPrice: double.tryParse(buyCtrl.text) ?? product.buyPrice,
                      sellPrice: double.tryParse(sellCtrl.text) ?? product.sellPrice,
                      stock: int.tryParse(stockCtrl.text) ?? product.stock,
                      unit: unitCtrl.text.trim().isEmpty ? 'pcs' : unitCtrl.text.trim(),
                    );
                    await prov.updateProduct(updated);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${updated.name} na-update na!'),
                        backgroundColor: Colors.green,
                      ));
                    }
                    _resume();
                  },
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Save Changes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
        ),
      ),
    ).then((_) => _resume());
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const Text('Scan History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 16),
          ..._history.map((r) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: r.found ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(r.found ? Icons.check_circle_outline : Icons.add_box_outlined, color: r.found ? Colors.green : Colors.orange, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(r.barcode, style: TextStyle(color: Colors.grey[400], fontSize: 11), overflow: TextOverflow.ellipsis),
              ])),
              Text('${r.time.hour.toString().padLeft(2, '0')}:${r.time.minute.toString().padLeft(2, '0')}', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ]),
          )),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                setState(() => _history.clear());
                Navigator.pop(context);
              },
              child: const Text('Clear History'),
            ),
          ),
        ]),
      ),
    );
  }

  void _showAddProductForm(String barcode, AppProvider prov) {
    final nameCtrl = TextEditingController();
    final buyCtrl = TextEditingController();
    final sellCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'pcs');
    String category = FilipinoCategories.productCategories.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(
                width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              )),
              const Text('New Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.green.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.qr_code_outlined, size: 16, color: AppColors.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Barcode: $barcode', style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis)),
                ]),
              ),
              const SizedBox(height: 16),
              _field(nameCtrl, 'Pangalan ng Produkto *', Icons.label_outlined, autofocus: true),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: InputDecoration(
                  labelText: 'Kategorya',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.white,
                ),
                borderRadius: BorderRadius.circular(12),
                items: FilipinoCategories.productCategories
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Row(
                            children: [
                              Icon(FilipinoCategories.getIcon(c), size: 18, color: Colors.grey[700]),
                              const SizedBox(width: 8),
                              Text(c),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setS(() => category = v!),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _field(buyCtrl, 'Presyo ng Bili', Icons.arrow_downward_outlined, keyboardType: TextInputType.number, prefix: '₱ ')),
                const SizedBox(width: 12),
                Expanded(child: _field(sellCtrl, 'Presyo ng Benta', Icons.arrow_upward_outlined, keyboardType: TextInputType.number, prefix: '₱ ')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _field(stockCtrl, 'Stock', Icons.inventory_2_outlined, keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _field(unitCtrl, 'Unit (pcs, kg...)', Icons.straighten_outlined)),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lagyan ng pangalan ang produkto!'), backgroundColor: Colors.red));
                      return;
                    }
                    final product = Product(
                      id: _uuid.v4(),
                      name: nameCtrl.text.trim(),
                      category: category,
                      buyPrice: double.tryParse(buyCtrl.text) ?? 0,
                      sellPrice: double.tryParse(sellCtrl.text) ?? 0,
                      stock: int.tryParse(stockCtrl.text) ?? 0,
                      unit: unitCtrl.text.trim().isEmpty ? 'pcs' : unitCtrl.text.trim(),
                      barcode: barcode,
                      createdAt: DateTime.now(),
                    );
                    await prov.addProduct(product);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${product.name} nai-save na!'), backgroundColor: Colors.green));
                    }
                    _resume();
                  },
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Save Product', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _resume(); },
                  icon: const Icon(Icons.qr_code_scanner_outlined, size: 18),
                  label: const Text('Scan Again'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                ),
              ),
            ]),
          ),
        ),
      ),
    ).then((_) => _resume());
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {
    TextInputType keyboardType = TextInputType.text, String? prefix, bool autofocus = false,
  }) => TextField(
    controller: ctrl, keyboardType: keyboardType, autofocus: autofocus,
    decoration: InputDecoration(
      labelText: label, prefixIcon: Icon(icon, size: 20), prefixText: prefix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true, fillColor: Colors.white,
    ),
  );

  Widget _statCol(String label, String value, Color color) => Column(children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ]);

  @override
  Widget build(BuildContext context) {
    final scanColor = _isScanning ? AppColors.blue : Colors.orange;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Barcode Scanner'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: Badge(label: Text('${_history.length}'), child: const Icon(Icons.history)),
              onPressed: _showHistory,
            ),
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off_outlined, color: _torchOn ? Colors.yellow : Colors.white),
            onPressed: () {
              _controller?.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_outlined),
            onPressed: () => _controller?.switchCamera(),
          ),
        ],
      ),
      body: Stack(children: [
        Positioned.fill(
          child: Stack(children: [
            MobileScanner(controller: _controller!, onDetect: _onDetect),
            Positioned.fill(
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;
                  const frameSize = 260.0;
                  final frameLeft = (w - frameSize) / 2;
                  final frameTop = (h - frameSize) / 2 - 40;

                  return Stack(children: [
                    Positioned(top: 0, left: 0, right: 0, height: frameTop, child: Container(color: Colors.black.withValues(alpha: 0.7))),
                    Positioned(top: frameTop + frameSize, left: 0, right: 0, bottom: 0, child: Container(color: Colors.black.withValues(alpha: 0.7))),
                    Positioned(top: frameTop, left: 0, width: frameLeft, height: frameSize, child: Container(color: Colors.black.withValues(alpha: 0.7))),
                    Positioned(top: frameTop, right: 0, width: frameLeft, height: frameSize, child: Container(color: Colors.black.withValues(alpha: 0.7))),
                    Positioned(
                      top: frameTop, left: frameLeft, width: frameSize, height: frameSize,
                      child: Stack(children: [
                        ...[Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight].map((align) => Align(
                          alignment: align,
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              border: Border(
                                top: (align == Alignment.topLeft || align == Alignment.topRight) ? BorderSide(color: scanColor, width: 4) : BorderSide.none,
                                bottom: (align == Alignment.bottomLeft || align == Alignment.bottomRight) ? BorderSide(color: scanColor, width: 4) : BorderSide.none,
                                left: (align == Alignment.topLeft || align == Alignment.bottomLeft) ? BorderSide(color: scanColor, width: 4) : BorderSide.none,
                                right: (align == Alignment.topRight || align == Alignment.bottomRight) ? BorderSide(color: scanColor, width: 4) : BorderSide.none,
                              ),
                            ),
                          ),
                        )),
                        if (_isScanning)
                          AnimatedBuilder(
                            animation: _scanAnim,
                            builder: (_, __) => Positioned(
                              top: 8 + (_scanAnim.value * 240), left: 8, right: 8,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: LinearGradient(colors: [
                                    Colors.transparent, scanColor.withValues(alpha: 0.8), scanColor, scanColor.withValues(alpha: 0.8), Colors.transparent,
                                  ], stops: const [0.0, 0.2, 0.5, 0.8, 1.0]),
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                    Positioned(
                      top: frameTop + frameSize + 16, left: 0, right: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 40),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              _isScanning ? 'Place barcode inside the frame' : 'Processing...',
                              style: TextStyle(color: _isScanning ? Colors.white : Colors.orange, fontSize: 13, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]);
                },
              ),
            ),
          ]),
        ),
        if (_flashOpacity > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _flashOpacity,
                duration: const Duration(milliseconds: 150),
                child: Container(color: _flashColor),
              ),
            ),
          ),
      ]),
    );
  }
}

class _ScanRecord {
  final String barcode;
  final String name;
  final bool found;
  final DateTime time;
  _ScanRecord({required this.barcode, required this.name, required this.found, required this.time});
}