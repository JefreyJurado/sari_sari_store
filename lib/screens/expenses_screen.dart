import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/expense.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import '../utils/filipino_categories.dart';
import '../theme/app_theme.dart';
import '../widgets/center_toast.dart';
import '../widgets/search_field.dart';

const _blue = AppColors.blue;

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String _filterCat = 'All';
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, prov, _) {
      var expenses = prov.expenses;
      if (_filterCat != 'All') {
        expenses = expenses.where((e) => e.category == _filterCat).toList();
      }
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        expenses = expenses
            .where((e) =>
                e.description.toLowerCase().contains(q) ||
                e.category.toLowerCase().contains(q) ||
                (e.notes?.toLowerCase().contains(q) ?? false))
            .toList();
      }
      final total = CurrencyFormatter.roundCents(
          expenses.fold(0.0, (s, e) => s + e.amount));

      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Expenses',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
        ),
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Track your business expenses',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ── Summary + Filter ───────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(children: [
                // Summary card
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _blue.withValues(alpha: 0.15)),
                  ),
                  child: Row(children: [
                    Icon(Icons.receipt_long_outlined,
                        color: _blue.withValues(alpha: 0.5), size: 18),
                    const SizedBox(width: 10),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Expenses',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 11)),
                          Text(CurrencyFormatter.format(total),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.black87)),
                        ]),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _blue.withValues(alpha: 0.2)),
                      ),
                      child: Text('${expenses.length} records',
                          style: TextStyle(
                              fontSize: 11,
                              color: _blue.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500)),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),

                SearchField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  hintText: 'Search expenses...',
                ),
                const SizedBox(height: 10),

                // Category filter chips
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: ['All', ...FilipinoCategories.expenseCategories]
                        .map((cat) {
                      final sel = _filterCat == cat;
                      return GestureDetector(
                        onTap: () => setState(() => _filterCat = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? _blue : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    sel ? FontWeight.w600 : FontWeight.normal,
                                color: sel ? Colors.white : Colors.grey[600]),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
              ]),
            ),

            Divider(height: 1, color: Colors.grey.shade100),

            // ── Expense List ───────────────────────
            Expanded(
              child: expenses.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          Image.asset(
                            'assets/mascot/storeph_mascot_neutral_idle.png',
                            width: 72,
                            height: 72,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                                Icons.receipt_long_outlined,
                                size: 48,
                                color: Colors.grey[300]),
                          ),
                          const SizedBox(height: 12),
                          Text('No expenses yet',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 14)),
                        ]))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: expenses.length,
                      itemBuilder: (_, i) => _ExpenseTile(
                        expense: expenses[i],
                        onDelete: () =>
                            _confirmDelete(context, prov, expenses[i]),
                        onEdit: () => _showForm(context, prov, expenses[i]),
                      ),
                    ),
            ),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'expenses_fab',
          onPressed: () => _showForm(context, prov, null),
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Expense',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      );
    });
  }

  void _showForm(BuildContext context, AppProvider prov, Expense? existing) {
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final amountCtrl = TextEditingController(
        text: existing != null ? existing.amount.toStringAsFixed(2) : '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String category =
        existing?.category ?? FilipinoCategories.expenseCategories.first;
    DateTime expenseDate = existing?.date ?? DateTime.now();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
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
              Text(
                existing == null ? 'Add Expense' : 'Edit Expense',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
              const SizedBox(height: 16),
              _field(
                descCtrl,
                category == 'Others'
                    ? 'OTHERS — type the exact purpose *'
                    : 'Description *',
                Icons.description_outlined,
                hint: category == 'Others'
                    ? 'e.g. padlock for stall, umbrella repair...'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                borderRadius: BorderRadius.circular(10),
                items: FilipinoCategories.expenseCategories
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setS(() => category = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Amount *',
                  labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                  prefixText: '₱ ',
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
              _field(notesCtrl, 'Notes (optional)', Icons.notes_outlined),
              const SizedBox(height: 12),
              // ── Date Picker ──────────────────────
              StatefulBuilder(
                builder: (_, setDate) => GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: expenseDate,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setS(() => expenseDate = picked);
                    }
                  },
                  child: Builder(builder: (_) {
                    final isToday =
                        DateHelper.isSameDay(expenseDate, DateTime.now());
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isToday ? Colors.grey.shade300 : _blue,
                        ),
                      ),
                      child: Row(children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 18,
                            color: isToday ? Colors.grey[500] : _blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isToday
                                ? 'Today — ${DateHelper.formatDate(expenseDate)}'
                                : 'Past Date — ${DateHelper.formatDate(expenseDate)}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isToday ? Colors.black87 : _blue),
                          ),
                        ),
                        if (!isToday)
                          GestureDetector(
                            onTap: () =>
                                setS(() => expenseDate = DateTime.now()),
                            child: Icon(Icons.close,
                                size: 16, color: Colors.grey[400]),
                          ),
                      ]),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (descCtrl.text.trim().isEmpty) {
                            CenterToast.showError(
                                context, 'Description required.');
                            return;
                          }
                          final amount = double.tryParse(amountCtrl.text);
                          if (amount == null || amount <= 0) {
                            CenterToast.showError(
                                context, 'Enter a valid amount.');
                            return;
                          }
                          setS(() => isSaving = true);
                          if (existing == null) {
                            await prov.addExpense(
                              descCtrl.text.trim(),
                              category,
                              amount,
                              notes: notesCtrl.text.isEmpty
                                  ? null
                                  : notesCtrl.text,
                              date: expenseDate,
                            );
                          } else {
                            await prov.updateExpense(
                              existing.copyWith(
                                description: descCtrl.text.trim(),
                                category: category,
                                amount: amount,
                                date: expenseDate,
                                notes: notesCtrl.text.isEmpty
                                    ? null
                                    : notesCtrl.text,
                              ),
                            );
                          }
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            CenterToast.showSuccess(
                                context,
                                existing == null
                                    ? 'Expense added!'
                                    : 'Expense updated!');
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
                      : Text(
                          existing == null ? 'Save Expense' : 'Update Expense',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
          {String? hint}) =>
      TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          prefixIcon: Icon(icon, size: 18, color: Colors.grey[500]),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
      );

  void _confirmDelete(BuildContext context, AppProvider prov, Expense expense) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Expense?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(expense.description,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87)),
              const SizedBox(height: 4),
              Text(CurrencyFormatter.format(expense.amount),
                  style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('This cannot be undone.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          TextButton(
            onPressed: () async {
              await prov.deleteExpense(expense.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Expense Tile ──────────────────────────────────────────────
class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ExpenseTile({
    required this.expense,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            onTap: onEdit,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _blue.withValues(alpha: 0.15))),
              child: const Icon(Icons.receipt_long_outlined,
                  color: _blue, size: 18),
            ),
            title: Text(expense.description,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black87)),
            subtitle: Text(
                '${expense.category}  •  ${DateHelper.formatDate(expense.date)}'
                '${expense.notes != null ? '\n${expense.notes}' : ''}',
                style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(CurrencyFormatter.format(expense.amount),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 14)),
              PopupMenuButton(
                icon: Icon(Icons.more_vert_outlined,
                    color: Colors.grey[400], size: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text('Edit',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[700])),
                      ])),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(fontSize: 13, color: Colors.red)),
                      ])),
                ],
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
