import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/expense.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import '../utils/filipino_categories.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String _filterCat = 'Lahat';

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, prov, _) {
      var expenses = prov.expenses;
      if (_filterCat != 'Lahat') {
        expenses = expenses
            .where((e) => e.category == _filterCat)
            .toList();
      }
      final total =
          expenses.fold(0.0, (s, e) => s + e.amount);

      return Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(title: const Text('Mga Gastos')),
        body: Column(children: [
          // Header banner
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFB71C1C),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            padding:
                const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Row(children: [
              Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                const Text('Kabuuang Gastos',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70)),
                Text(
                  CurrencyFormatter.format(total),
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color:
                      Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(children: [
                  Text('${expenses.length}',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const Text('gastos',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white70)),
                ]),
              ),
            ]),
          ),

          // Category filter
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  'Lahat',
                  ...FilipinoCategories.expenseCategories
                ]
                    .map((cat) {
                      final sel = _filterCat == cat;
                      return GestureDetector(
                        onTap: () => setState(
                            () => _filterCat = cat),
                        child: AnimatedContainer(
                          duration: const Duration(
                              milliseconds: 150),
                          margin: const EdgeInsets.only(
                              right: 8),
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6),
                          decoration: BoxDecoration(
                            color: sel
                                ? const Color(0xFFB71C1C)
                                : Colors.white,
                            borderRadius:
                                BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: sel
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: sel
                                    ? Colors.white
                                    : Colors.grey[700]),
                          ),
                        ),
                      );
                    })
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // List
          Expanded(
            child: expenses.isEmpty
                ? Center(
                    child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Walang gastos',
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16)),
                    ]))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        16, 4, 16, 16),
                    itemCount: expenses.length,
                    itemBuilder: (_, i) => _ExpenseTile(
                      expense: expenses[i],
                      onDelete: () => _confirmDelete(
                          context, prov, expenses[i]),
                      onEdit: () => _showForm(
                          context, prov, expenses[i]),
                    ),
                  ),
          ),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showForm(context, prov, null),
          icon: const Icon(Icons.add),
          label: const Text('Dagdag Gastos'),
          backgroundColor: const Color(0xFFB71C1C),
        ),
      );
    });
  }

  void _showForm(
      BuildContext context, AppProvider prov, Expense? existing) {
    final descCtrl = TextEditingController(
        text: existing?.description ?? '');
    final amountCtrl = TextEditingController(
        text: existing != null
            ? existing.amount.toStringAsFixed(2)
            : '');
    final notesCtrl =
        TextEditingController(text: existing?.notes ?? '');
    String category = existing?.category ??
        FilipinoCategories.expenseCategories.first;

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
                  MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Text(
              existing == null
                  ? 'Dagdag Gastos'
                  : 'I-edit ang Gastos',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _field(descCtrl, 'Paliwanag *',
                Icons.description_outlined),
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
              items: FilipinoCategories.expenseCategories
                  .map((c) => DropdownMenuItem(
                      value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) =>
                  setS(() => category = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Halaga (₱) *',
                prefixText: '₱ ',
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            _field(notesCtrl, 'Tala (optional)',
                Icons.notes_outlined),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (descCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(
                      content:
                          Text('Lagyan ng paliwanag!'),
                      backgroundColor: Colors.red,
                    ));
                    return;
                  }
                  final amount =
                      double.tryParse(amountCtrl.text);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(
                      content: Text(
                          'Ilagay ang tamang halaga!'),
                      backgroundColor: Colors.red,
                    ));
                    return;
                  }
                  if (existing == null) {
                    await prov.addExpense(
                      descCtrl.text.trim(),
                      category,
                      amount,
                      notes: notesCtrl.text.isEmpty
                          ? null
                          : notesCtrl.text,
                    );
                  } else {
                    await prov.updateExpense(
                      existing.copyWith(
                        description: descCtrl.text.trim(),
                        category: category,
                        amount: amount,
                        notes: notesCtrl.text.isEmpty
                            ? null
                            : notesCtrl.text,
                      ),
                    );
                  }
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(
                      content: Text(existing == null
                          ? 'Naidagdag ang gastos!'
                          : 'Na-update ang gastos!'),
                      backgroundColor: Colors.green,
                    ));
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFB71C1C),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14)),
                child: Text(
                  existing == null
                      ? 'I-save ang Gastos'
                      : 'I-update ang Gastos',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
          IconData icon) =>
      TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      );

  void _confirmDelete(BuildContext context, AppProvider prov,
      Expense expense) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Burahin ang Gastos?'),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(expense.description,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 4),
          Text(CurrencyFormatter.format(expense.amount),
              style: const TextStyle(
                  color: Colors.red, fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Hindi na mababawi ito.',
              style: TextStyle(
                  color: Colors.grey[500], fontSize: 13)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kanselahin')),
          ElevatedButton(
            onPressed: () async {
              await prov.deleteExpense(expense.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('Burahin'),
          ),
        ],
      ),
    );
  }
}

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
      margin: const EdgeInsets.only(bottom: 10),
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
      child: ListTile(
        onTap: onEdit,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: const Center(
              child: Icon(Icons.receipt_long_outlined,
                  color: Colors.red, size: 22)),
        ),
        title: Text(expense.description,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${expense.category}  •  ${DateHelper.formatDate(expense.date)}',
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 12)),
            if (expense.notes != null)
              Text(expense.notes!,
                  style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11)),
          ],
        ),
        trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
          Text(CurrencyFormatter.format(expense.amount),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 15)),
          PopupMenuButton(
            icon: Icon(Icons.more_vert,
                color: Colors.grey[400], size: 20),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined,
                        size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('I-edit'),
                  ])),
              PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Burahin',
                        style:
                            TextStyle(color: Colors.red)),
                  ])),
            ],
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
          ),
        ]),
      ),
    );
  }
}