import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/capital_entry.dart';
import '../utils/currency_formatter.dart';
import '../theme/app_theme.dart';
import '../widgets/center_toast.dart';
import '../widgets/help_sheet.dart';

const _blue = AppColors.blue;

class CapitalScreen extends StatefulWidget {
  const CapitalScreen({super.key});
  @override
  State<CapitalScreen> createState() => _CapitalScreenState();
}

class _CapitalScreenState extends State<CapitalScreen> {
  Future<void> _persist(AppProvider prov, List<SetupCostItem> items) async {
    final total =
        CurrencyFormatter.roundCents(items.fold(0.0, (s, i) => s + i.amount));
    await prov.saveCapital(
      setupCosts: total,
      inventoryValue: prov.currentInventoryValue,
      setupItems: items,
    );
  }

  /// Opens a single item's fields in a bottom sheet — for a new item when
  /// [existing]/[index] are null, or pre-filled for editing one in place.
  /// Replaces the old whole-list "Edit mode" (which expanded every item's
  /// full form at once, becoming an unwieldy wall of fields for stores
  /// with several setup costs) with the same tap-to-edit-one pattern the
  /// Products list already uses.
  void _showItemDialog(AppProvider prov,
      {SetupCostItem? existing, int? index}) {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final amtCtrl = TextEditingController(
        text: existing != null ? existing.amount.toStringAsFixed(2) : '');
    final vendorCtrl = TextEditingController(text: existing?.vendor ?? '');
    String category = existing?.category ?? 'Equipment';
    String paymentMethod = existing?.paymentMethod ?? 'Cash';
    DateTime date = existing?.date ?? DateTime.now();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              Text(existing == null ? 'Add Setup Cost' : 'Edit Setup Cost',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              const SizedBox(height: 18),
              TextField(
                controller: labelCtrl,
                decoration: InputDecoration(
                  labelText: category == 'Others'
                      ? 'OTHERS — type the exact purpose *'
                      : 'Description',
                  hintText: category == 'Others'
                      ? 'e.g. tricycle repair, ID lamination fee...'
                      : 'e.g. DTI, Equipment...',
                  labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amtCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₱ ',
                  labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: vendorCtrl,
                decoration: InputDecoration(
                  labelText: 'Vendor (optional)',
                  labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle:
                          TextStyle(color: Colors.grey[600], fontSize: 13),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: category,
                        isDense: true,
                        isExpanded: true,
                        items: SetupCostItem.categories
                            .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c,
                                    style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setS(() => category = v);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Payment',
                      labelStyle:
                          TextStyle(color: Colors.grey[600], fontSize: 13),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: paymentMethod,
                        isDense: true,
                        isExpanded: true,
                        items: SetupCostItem.paymentMethods
                            .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(p,
                                    style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setS(() => paymentMethod = v);
                        },
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetCtx,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setS(() => date = picked);
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 10),
                    Text('${date.month}/${date.day}/${date.year}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87)),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              Row(children: [
                if (existing != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          _confirmAndDelete(prov, index!, sheetCtx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.shade200),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Delete',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setS(() => isSaving = true);
                            final saved = await _saveItem(
                              prov,
                              existing: existing,
                              index: index,
                              label: labelCtrl.text.trim(),
                              amountText: amtCtrl.text,
                              vendor: vendorCtrl.text.trim(),
                              category: category,
                              paymentMethod: paymentMethod,
                              date: date,
                              sheetCtx: sheetCtx,
                            );
                            // Only reset when _saveItem returned early
                            // (validation failed) without popping the sheet
                            // — resetting after a real pop would touch the
                            // sheet's own controllers as they're disposed.
                            if (!saved && sheetCtx.mounted) {
                              setS(() => isSaving = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    ).whenComplete(() {
      labelCtrl.dispose();
      amtCtrl.dispose();
      vendorCtrl.dispose();
    });
  }

  // Returns whether the item actually saved (and the sheet was popped), so
  // the caller only resets its "isSaving" spinner flag on the validation-
  // failure path — calling setS() again after a successful pop races the
  // sheet's own exit transition and can touch controllers whenComplete()
  // is about to dispose.
  Future<bool> _saveItem(
    AppProvider prov, {
    SetupCostItem? existing,
    int? index,
    required String label,
    required String amountText,
    required String vendor,
    required String category,
    required String paymentMethod,
    required DateTime date,
    required BuildContext sheetCtx,
  }) async {
    if (label.isEmpty) {
      CenterToast.showError(context, 'Description is required.');
      return false;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      CenterToast.showError(context, 'Enter a valid amount.');
      return false;
    }

    final newItem = SetupCostItem(
      label: label,
      amount: amount,
      category: category,
      vendor: vendor.isEmpty ? null : vendor,
      paymentMethod: paymentMethod,
      date: date,
    );

    final items = List<SetupCostItem>.from(prov.capital?.setupItems ?? []);
    if (index != null) {
      items[index] = newItem;
    } else {
      items.add(newItem);
    }
    await _persist(prov, items);

    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
    if (mounted) {
      CenterToast.showSuccess(
          context, existing == null ? 'Item added!' : 'Item updated!');
    }
    return true;
  }

  Future<void> _confirmAndDelete(
      AppProvider prov, int index, BuildContext sheetCtx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete this item?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        content: const Text('This cannot be undone.',
            style: TextStyle(fontSize: 13, color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final items = List<SetupCostItem>.from(prov.capital?.setupItems ?? []);
    items.removeAt(index);
    await _persist(prov, items);

    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
    if (mounted) {
      CenterToast.showWarning(context, 'Item deleted.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Capital Overview',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          HelpIconButton(
            title: 'Understanding Capital Overview',
            points: [
              'Setup Costs are what you spent to start the business (shelving, initial stock, permits, etc.) — add each one here; tap an item to edit or delete it.',
              'ROI (Return on Investment) shows how much of that setup cost your profits have earned back so far.',
              'Profit Margin is what percentage of your sales revenue is actual profit, based on your real sales history.',
              "Break-Even Sales is how much you'd need to sell to cover all your logged expenses, given your current profit margin — it's in pesos, not units, since a sari-sari store sells many different items at different prices.",
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: Consumer<AppProvider>(
        builder: (context, prov, _) {
          final roi = prov.roiPercent;
          final isProfit = roi >= 0;
          final roiColor =
              isProfit ? Colors.green.shade600 : Colors.red.shade600;
          final setupItems = prov.capital?.setupItems ?? [];

          return SafeArea(
            top: false,
            child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── ROI Badge ──
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          isProfit ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: isProfit
                              ? Colors.green.shade200
                              : Colors.red.shade200),
                    ),
                    child: Text(
                      '${isProfit ? '+' : ''}${roi.toStringAsFixed(2)}% ROI',
                      style: TextStyle(
                          color: roiColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Business Setup Costs ──
                _sectionHeader('Business Setup Costs'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(children: [
                    Row(children: [
                      const Text('Setup Cost Items',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showItemDialog(prov),
                        icon: const Icon(Icons.add, size: 16, color: _blue),
                        label: const Text('Add Item',
                            style: TextStyle(fontSize: 12, color: _blue)),
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero, minimumSize: Size.zero),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    if (setupItems.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(children: [
                          Icon(Icons.info_outline,
                              size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                                'Tap "Add Item" to add setup cost details',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                          ),
                        ]),
                      )
                    else
                      ...List.generate(setupItems.length,
                          (i) => _setupItemRow(prov, setupItems[i], i)),
                    const SizedBox(height: 8),
                    _detailRow(
                        'Total Setup Costs',
                        CurrencyFormatter.format(prov.businessSetupCosts),
                        Icons.store_mall_directory_outlined,
                        Colors.blue.shade600),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Stock Monitoring ──
                _sectionHeader('Stock Monitoring'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(children: [
                    _detailRow(
                        'Current Inventory Value',
                        CurrencyFormatter.format(prov.currentInventoryValue),
                        Icons.inventory_2_outlined,
                        Colors.purple.shade600),
                    const SizedBox(height: 4),
                    Row(children: [
                      const SizedBox(width: 48),
                      Text(
                        'Live stock value — not included in ROI',
                        style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _blue.withValues(alpha: 0.15)),
                  ),
                  child: Column(children: [
                    _detailRow(
                        'Total Investment',
                        CurrencyFormatter.format(prov.totalInvestment),
                        Icons.account_balance_outlined,
                        _blue,
                        bold: true),
                    const SizedBox(height: 4),
                    Row(children: [
                      const SizedBox(width: 48),
                      Text(
                        '= Total Setup Costs (inventory excluded from ROI)',
                        style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Performance ──
                _sectionHeader('Business Performance'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(children: [
                    _perfRow(
                        'Total Sales Profit',
                        CurrencyFormatter.format(prov.totalSalesProfit),
                        Colors.green.shade600),
                    const SizedBox(height: 10),
                    _perfRow(
                        'Total Expenses',
                        // Only prefix a minus sign when there's actually
                        // something to subtract — otherwise ₱0.00 reads
                        // as "-₱0.00", which looks like a negative value
                        // that doesn't exist.
                        prov.totalExpensesAmount > 0
                            ? '- ${CurrencyFormatter.format(prov.totalExpensesAmount)}'
                            : CurrencyFormatter.format(
                                prov.totalExpensesAmount),
                        Colors.red.shade600),
                    Divider(height: 20, color: Colors.grey.shade200),
                    _perfRow('Current Capital',
                        CurrencyFormatter.format(prov.currentCapital), _blue,
                        bold: true),
                    const SizedBox(height: 8),
                    _perfRow(
                        isProfit ? 'Net Gain' : 'Net Loss',
                        '${isProfit ? '+' : ''}${CurrencyFormatter.format(prov.netGainLoss)}',
                        roiColor,
                        bold: true),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Break-Even Point ──
                _sectionHeader('Break-Even Analysis'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline,
                            size: 13, color: Colors.grey[400]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Break-Even Sales = Total Fixed Expenses ÷ Profit Margin',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[500]),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    _perfRow(
                      'Total Fixed Expenses',
                      CurrencyFormatter.format(prov.totalExpensesAmount),
                      Colors.orange.shade600,
                    ),
                    const SizedBox(height: 8),
                    _perfRow(
                      'Profit Margin',
                      prov.grossRevenue <= 0
                          ? 'N/A'
                          : '${prov.profitMarginPercent.toStringAsFixed(1)}%',
                      prov.grossRevenue > 0 && prov.profitMarginPercent > 0
                          ? Colors.green.shade600
                          : Colors.red.shade400,
                    ),
                    Divider(height: 20, color: Colors.grey.shade200),
                    _perfRow(
                      'Break-Even Sales',
                      // N/A only for genuinely invalid states (no sales, or
                      // an overall loss) — NOT whenever the peso figure
                      // happens to be zero, since zero logged expenses is a
                      // legitimate state where "₱0.00 needed" is the
                      // correct answer, not a missing one.
                      prov.grossRevenue <= 0 || prov.grossProfit <= 0
                          ? 'N/A'
                          : CurrencyFormatter.format(prov.breakEvenRevenue),
                      _blue,
                      bold: true,
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _breakEvenMessage(prov),
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[400]),
                        ),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 20),
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  Widget _setupItemRow(AppProvider prov, SetupCostItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showItemDialog(prov, existing: item, index: index),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(item.label,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                ),
                Text(CurrencyFormatter.format(item.amount),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87)),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_outlined,
                      size: 16, color: Colors.grey[400]),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined,
                            size: 16, color: Colors.black54),
                        SizedBox(width: 8),
                        Text('Edit', style: TextStyle(fontSize: 13)),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(color: Colors.red, fontSize: 13)),
                      ]),
                    ),
                  ],
                  onSelected: (v) {
                    if (v == 'edit') {
                      _showItemDialog(prov, existing: item, index: index);
                    } else if (v == 'delete') {
                      _confirmAndDeleteFromRow(prov, index);
                    }
                  },
                ),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                      item.category.isEmpty ? 'Uncategorized' : item.category,
                      style: TextStyle(
                          fontSize: 10, color: _blue.withValues(alpha: 0.8))),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                      item.paymentMethod.isEmpty
                          ? 'No Payment Method'
                          : item.paymentMethod,
                      style: TextStyle(
                          fontSize: 10, color: Colors.green.shade700)),
                ),
                const Spacer(),
                if (item.vendor != null)
                  Text(item.vendor!,
                      style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ]),
              const SizedBox(height: 2),
              Text(
                '${item.date.month}/${item.date.day}/${item.date.year}',
                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  /// Delete triggered from the row's "..." menu (no open sheet to pop).
  Future<void> _confirmAndDeleteFromRow(AppProvider prov, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete this item?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        content: const Text('This cannot be undone.',
            style: TextStyle(fontSize: 13, color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final items = List<SetupCostItem>.from(prov.capital?.setupItems ?? []);
    items.removeAt(index);
    await _persist(prov, items);
    if (mounted) CenterToast.showWarning(context, 'Item deleted.');
  }

  String _breakEvenMessage(AppProvider prov) {
    if (prov.grossRevenue <= 0) {
      return 'Log some sales first to compute break-even.';
    }
    if (prov.grossProfit <= 0) {
      return "You're selling at a loss overall — check your prices.";
    }
    if (prov.totalExpensesAmount <= 0) {
      return 'No expenses logged yet — you have no break-even threshold to clear.';
    }
    return 'Earn ${CurrencyFormatter.format(prov.breakEvenRevenue)} in sales to cover all your expenses.';
  }

  Widget _sectionHeader(String title) => Text(title,
      style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87));

  Widget _detailRow(String label, String value, IconData icon, Color color,
          {bool bold = false}) =>
      Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
        Text(value,
            style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                fontSize: bold ? 15 : 13,
                color: bold ? color : Colors.black87)),
      ]);

  Widget _perfRow(String label, String value, Color color,
          {bool bold = false}) =>
      Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
        Text(value,
            style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                fontSize: bold ? 15 : 13,
                color: bold ? color : Colors.black87)),
      ]);
}
