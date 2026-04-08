import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../models/debt.dart';
import '../utils/currency_formatter.dart';

class CustomerListItem extends StatelessWidget {
  final Customer customer;
  final List<Debt> debts;
  final VoidCallback onTap;

  const CustomerListItem({
    super.key,
    required this.customer,
    required this.debts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unpaid = debts.where((d) => d.status != DebtStatus.paid).toList();
    final totalOwed = unpaid.fold(0.0, (s, d) => s + d.remaining);
    final hasOverdue = unpaid.any((d) => d.isOverdue);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: hasOverdue
              ? Colors.red.withOpacity(0.15)
              : const Color(0xFF2E7D32).withOpacity(0.15),
          child: Text(
            customer.name[0].toUpperCase(),
            style: TextStyle(
              color: hasOverdue ? Colors.red : const Color(0xFF2E7D32),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(children: [
          Expanded(
              child: Text(customer.name,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          if (hasOverdue)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('Overdue',
                  style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
        ]),
        subtitle: Text(customer.phone ?? 'Walang numero',
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyFormatter.format(totalOwed),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: totalOwed > 0 ? Colors.red[700] : Colors.green,
              ),
            ),
            Text('${unpaid.length} utang',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}