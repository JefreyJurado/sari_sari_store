import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../utils/filipino_categories.dart';
import 'database_service.dart';

const _uuid = Uuid();

const _templateHeader = [
  'name',
  'category',
  'buyPrice',
  'sellPrice',
  'stock',
  'unit',
  'barcode',
  'reorderPoint',
  'supplierName',
  'supplierContact',
];

class ImportParseResult {
  final List<Product> toInsert;
  final int skippedDuplicates;
  final List<String> rowErrors;
  const ImportParseResult({
    required this.toInsert,
    required this.skippedDuplicates,
    required this.rowErrors,
  });
}

class ProductImportService {
  static final ProductImportService instance = ProductImportService._();
  ProductImportService._();

  /// Shares a CSV template (header + one example row) so a store owner can
  /// fill it in with their existing catalog in Sheets/Excel and re-share it
  /// back in for [pickAndParseFile] — same temp-file-then-share pattern as
  /// BackupService.exportBackup.
  Future<void> exportTemplate() async {
    const exampleRow = [
      'Lucky Me Pancit Canton',
      'Snacks',
      '8.00',
      '12.00',
      '50',
      'pcs',
      '',
      '5',
      '',
      '',
    ];
    final csv =
        const ListToCsvConverter().convert([_templateHeader, exampleRow]);

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/storeph_product_import_template.csv');
    await file.writeAsString(csv);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'StorePH Product Import Template',
      ),
    );
  }

  /// Lets the user pick a CSV file, parses it against the template columns
  /// (matched by header name, not position, so a re-ordered column doesn't
  /// silently corrupt data), validates/dedupes each row, and returns a
  /// preview result. Performs no DB writes — the caller decides whether to
  /// actually commit [ImportParseResult.toInsert] via
  /// AppProvider.importProducts.
  Future<ImportParseResult?> pickAndParseFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    final path = result?.files.single.path;
    if (path == null) return null;

    final content = await File(path).readAsString();
    // No explicit `eol` — let the package auto-detect \r\n vs \n so a CSV
    // exported from Excel/Sheets on Windows (which uses \r\n) parses the
    // same as one saved on macOS/Linux.
    final rows =
        const CsvToListConverter(shouldParseNumbers: false).convert(content);
    if (rows.isEmpty) {
      return const ImportParseResult(
          toInsert: [], skippedDuplicates: 0, rowErrors: []);
    }

    final header =
        rows.first.map((c) => c.toString().trim().toLowerCase()).toList();
    int? col(String name) {
      final idx = header.indexOf(name.toLowerCase());
      return idx == -1 ? null : idx;
    }
    String cell(List<dynamic> row, int? index) =>
        index == null || index >= row.length ? '' : row[index].toString().trim();

    // Spreadsheet exports commonly format price/quantity cells with a
    // currency symbol, thousands separators, or a trailing ".0" on whole
    // numbers (e.g. "₱1,200.00", "50.0") — strip anything but digits/./-
    // before parsing instead of rejecting those as invalid.
    double? parsePrice(String raw) {
      final cleaned = raw.replaceAll(RegExp(r'[^\d.\-]'), '');
      return cleaned.isEmpty ? null : double.tryParse(cleaned);
    }

    int? parseInt(String raw) {
      final cleaned = raw.replaceAll(RegExp(r'[^\d.\-]'), '');
      if (cleaned.isEmpty) return null;
      return int.tryParse(cleaned) ?? double.tryParse(cleaned)?.round();
    }

    final nameCol = col('name');
    final categoryCol = col('category');
    final buyCol = col('buyPrice');
    final sellCol = col('sellPrice');
    final stockCol = col('stock');
    final unitCol = col('unit');
    final barcodeCol = col('barcode');
    final reorderCol = col('reorderPoint');
    final supplierNameCol = col('supplierName');
    final supplierContactCol = col('supplierContact');

    // A missing name/buyPrice/sellPrice column means every row would fail
    // the same way — one clear error beats the same "missing name" message
    // repeated for every row in the file.
    final missingRequired = [
      if (nameCol == null) 'name',
      if (buyCol == null) 'buyPrice',
      if (sellCol == null) 'sellPrice',
    ];
    if (missingRequired.isNotEmpty) {
      return ImportParseResult(
        toInsert: const [],
        skippedDuplicates: 0,
        rowErrors: [
          'Missing required column(s): ${missingRequired.join(', ')}. '
              'Download the template to check the expected headers.'
        ],
      );
    }

    final existing = await DatabaseService.instance.getProducts();
    final knownBarcodes = {
      for (final p in existing)
        if (p.barcode != null && p.barcode!.isNotEmpty) p.barcode!,
    };
    final knownNames = {for (final p in existing) p.name.toLowerCase()};

    final toInsert = <Product>[];
    final rowErrors = <String>[];
    var skippedDuplicates = 0;
    final now = DateTime.now();

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      // A trailing blank line at the end of the file parses as a single
      // empty cell — not a real row worth an error message.
      if (row.length == 1 && cell(row, 0).isEmpty) continue;

      final rowNum = i + 1; // 1-based, matches what a spreadsheet shows
      final name = cell(row, nameCol);
      if (name.isEmpty) {
        rowErrors.add('Row $rowNum: missing name');
        continue;
      }

      final buyPrice = parsePrice(cell(row, buyCol));
      final sellPrice = parsePrice(cell(row, sellCol));
      if (buyPrice == null || buyPrice < 0) {
        rowErrors.add('Row $rowNum: invalid buyPrice');
        continue;
      }
      if (sellPrice == null || sellPrice < 0) {
        rowErrors.add('Row $rowNum: invalid sellPrice');
        continue;
      }

      final barcode = cell(row, barcodeCol);
      final isDuplicate = (barcode.isNotEmpty && knownBarcodes.contains(barcode)) ||
          knownNames.contains(name.toLowerCase());
      if (isDuplicate) {
        skippedDuplicates++;
        continue;
      }

      final rawCategory = cell(row, categoryCol);
      final category = FilipinoCategories.productCategories.firstWhere(
        (c) => c.toLowerCase() == rawCategory.toLowerCase(),
        orElse: () => 'Others',
      );
      final stock = parseInt(cell(row, stockCol)) ?? 0;
      final reorderPoint = parseInt(cell(row, reorderCol)) ?? 5;
      final unit = cell(row, unitCol);
      final supplierName = cell(row, supplierNameCol);
      final supplierContact = cell(row, supplierContactCol);

      toInsert.add(Product(
        id: _uuid.v4(),
        name: name,
        category: category,
        buyPrice: buyPrice,
        sellPrice: sellPrice,
        stock: stock,
        unit: unit.isEmpty ? null : unit,
        barcode: barcode.isEmpty ? null : barcode,
        createdAt: now,
        reorderPoint: reorderPoint,
        supplierName: supplierName.isEmpty ? null : supplierName,
        supplierContact: supplierContact.isEmpty ? null : supplierContact,
      ));

      // Track within-file duplicates too, so two rows sharing a name/
      // barcode don't both get inserted.
      if (barcode.isNotEmpty) knownBarcodes.add(barcode);
      knownNames.add(name.toLowerCase());
    }

    return ImportParseResult(
      toInsert: toInsert,
      skippedDuplicates: skippedDuplicates,
      rowErrors: rowErrors,
    );
  }
}
