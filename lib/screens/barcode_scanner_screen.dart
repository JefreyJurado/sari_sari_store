import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_provider.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import '../utils/currency_formatter.dart';
import '../utils/filipino_categories.dart';

const _uuid = Uuid();

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});
  @override
  State<BarcodeScannerScreen> createState() =>
      _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState
    extends State<BarcodeScannerScreen> {
  MobileScannerController? _controller;
  bool _isScanning = true;
  bool _torchOn = false;
  String? _lastScanned;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _resume() {
    setState(() {
      _isScanning = true;
      _lastScanned = null;
    });
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

    final prov = context.read<AppProvider>();
    final byBarcode =
        await DatabaseService.instance.getProductByBarcode(code);

    if (byBarcode != null) {
      _showProductFound(byBarcode, prov);
      return;
    }

    final byName = prov.products
        .where((p) =>
            p.name.toLowerCase().contains(code.toLowerCase()))
        .toList();

    if (byName.isNotEmpty) {
      _showProductFound(byName.first, prov);
    } else {
      _showAddProductForm(code, prov);
    }
  }

  void _showProductFound(Product product, AppProvider prov) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF5F6FA),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child:
            Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),

          // Product found indicator
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline,
                color: Colors.green, size: 32),
          ),
          const SizedBox(height: 12),
          Text(product.name,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          Text(product.category,
              style: TextStyle(
                  color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 16),

          // Stats
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,
                children: [
              _statCol(
                  'Presyo',
                  CurrencyFormatter.format(product.sellPrice),
                  const Color(0xFF2E7D32)),
              Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey[200]),
              _statCol(
                  'Stock',
                  '${product.stock}',
                  product.isOutOfStock
                      ? Colors.red
                      : Colors.blue),
              Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey[200]),
              _statCol(
                  'Tubo',
                  CurrencyFormatter.format(product.profit),
                  Colors.orange),
            ]),
          ),
          const SizedBox(height: 20),

          // Buttons
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _resume();
                },
                icon: const Icon(
                    Icons.qr_code_scanner_outlined,
                    size: 18),
                label: const Text('I-scan Ulit'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 13)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: product.isOutOfStock
                    ? null
                    : () {
                        prov.addToCart(product);
                        Navigator.pop(context);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                          content: Text(
                              '${product.name} naidagdag sa cart!'),
                          backgroundColor: Colors.green,
                        ));
                      },
                icon: const Icon(
                    Icons.add_shopping_cart_outlined,
                    size: 18),
                label: const Text('Sa Cart'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 13)),
              ),
            ),
          ]),
        ]),
      ),
    ).then((_) => _resume());
  }

  void _showAddProductForm(String barcode, AppProvider prov) {
    final nameCtrl = TextEditingController();
    final buyCtrl = TextEditingController();
    final sellCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'pcs');
    String category =
        FilipinoCategories.productCategories.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF5F6FA),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              bottom:
                  MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius:
                          BorderRadius.circular(2)),
                ),
              ),
              const Text('Bagong Produkto',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // Barcode badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF2E7D32)
                          .withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.qr_code_outlined,
                      size: 16,
                      color: Color(0xFF2E7D32)),
                  const SizedBox(width: 8),
                  Text('Barcode: $barcode',
                      style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 16),

              _field(nameCtrl, 'Pangalan ng Produkto *',
                  Icons.label_outlined,
                  autofocus: true),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                decoration: InputDecoration(
                  labelText: 'Kategorya',
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                borderRadius: BorderRadius.circular(12),
                items: FilipinoCategories.productCategories
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                            '${FilipinoCategories.emoji(c)} $c')))
                    .toList(),
                onChanged: (v) =>
                    setS(() => category = v!),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _field(
                      buyCtrl,
                      'Presyo ng Bili',
                      Icons.arrow_downward_outlined,
                      keyboardType: TextInputType.number,
                      prefix: '₱ '),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                      sellCtrl,
                      'Presyo ng Benta',
                      Icons.arrow_upward_outlined,
                      keyboardType: TextInputType.number,
                      prefix: '₱ '),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _field(
                      stockCtrl,
                      'Stock',
                      Icons.inventory_2_outlined,
                      keyboardType: TextInputType.number),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(unitCtrl,
                      'Unit (pcs, kg...)',
                      Icons.straighten_outlined),
                ),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(
                        content: Text(
                            'Lagyan ng pangalan ang produkto!'),
                        backgroundColor: Colors.red,
                      ));
                      return;
                    }
                    final product = Product(
                      id: _uuid.v4(),
                      name: nameCtrl.text.trim(),
                      category: category,
                      buyPrice:
                          double.tryParse(buyCtrl.text) ?? 0,
                      sellPrice:
                          double.tryParse(sellCtrl.text) ?? 0,
                      stock:
                          int.tryParse(stockCtrl.text) ?? 0,
                      unit: unitCtrl.text.trim().isEmpty
                          ? 'pcs'
                          : unitCtrl.text.trim(),
                      barcode: barcode,
                      createdAt: DateTime.now(),
                    );
                    await prov.addProduct(product);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(
                        content:
                            Text('${product.name} nai-save na!'),
                        backgroundColor: Colors.green,
                      ));
                    }
                    _resume();
                  },
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14)),
                  child: const Text('I-save ang Produkto',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _resume();
                  },
                  icon: const Icon(
                      Icons.qr_code_scanner_outlined,
                      size: 18),
                  label: const Text('I-scan Ulit'),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 13)),
                ),
              ),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    ).then((_) => _resume());
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? prefix,
    bool autofocus = false,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        autofocus: autofocus,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          prefixText: prefix,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      );

  Widget _statCol(
          String label, String value, Color color) =>
      Column(children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color)),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: Colors.grey[500])),
      ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode Scanner'),
        actions: [
          IconButton(
            icon: Icon(_torchOn
                ? Icons.flash_on
                : Icons.flash_off_outlined),
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
      body: Column(children: [
        // Camera view
        Expanded(
          flex: 3,
          child: Stack(children: [
            MobileScanner(
              controller: _controller!,
              onDetect: _onDetect,
            ),
            // Scan frame
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _isScanning
                        ? const Color(0xFF2E7D32)
                        : Colors.orange,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(children: [
                  // Corner accents
                  ...[
                    Alignment.topLeft,
                    Alignment.topRight,
                    Alignment.bottomLeft,
                    Alignment.bottomRight,
                  ].map((align) => Align(
                        alignment: align,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            border: Border(
                              top: align ==
                                          Alignment.topLeft ||
                                      align ==
                                          Alignment.topRight
                                  ? BorderSide(
                                      color: _isScanning
                                          ? const Color(
                                              0xFF2E7D32)
                                          : Colors.orange,
                                      width: 4)
                                  : BorderSide.none,
                              bottom: align ==
                                          Alignment
                                              .bottomLeft ||
                                      align ==
                                          Alignment.bottomRight
                                  ? BorderSide(
                                      color: _isScanning
                                          ? const Color(
                                              0xFF2E7D32)
                                          : Colors.orange,
                                      width: 4)
                                  : BorderSide.none,
                              left: align ==
                                          Alignment.topLeft ||
                                      align ==
                                          Alignment.bottomLeft
                                  ? BorderSide(
                                      color: _isScanning
                                          ? const Color(
                                              0xFF2E7D32)
                                          : Colors.orange,
                                      width: 4)
                                  : BorderSide.none,
                              right: align ==
                                          Alignment.topRight ||
                                      align ==
                                          Alignment.bottomRight
                                  ? BorderSide(
                                      color: _isScanning
                                          ? const Color(
                                              0xFF2E7D32)
                                          : Colors.orange,
                                      width: 4)
                                  : BorderSide.none,
                            ),
                          ),
                        ),
                      )),
                ]),
              ),
            ),
          ]),
        ),

        // Status bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Icon(
              _isScanning
                  ? Icons.qr_code_scanner_outlined
                  : Icons.hourglass_empty_outlined,
              size: 32,
              color: _isScanning
                  ? const Color(0xFF2E7D32)
                  : Colors.orange,
            ),
            const SizedBox(height: 8),
            Text(
              _isScanning
                  ? 'I-scan ang barcode ng produkto'
                  : 'Nagpoproseso...',
              style: TextStyle(
                  color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (_lastScanned != null) ...[
              const SizedBox(height: 4),
              Text('Barcode: $_lastScanned',
                  style: TextStyle(
                      color: Colors.grey[400], fontSize: 12)),
            ],
          ]),
        ),
      ]),
    );
  }
}