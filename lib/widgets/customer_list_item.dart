import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../models/debt.dart';
import '../utils/currency_formatter.dart';

// Your app's signature blue color
const _blue = Color(0xFF1E3A8A);

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
    final unpaid =
        debts.where((d) => d.status != DebtStatus.paid).toList();
    final totalOwed =
        unpaid.fold(0.0, (s, d) => s + d.remaining);
    final hasOverdue = unpaid.any((d) => d.isOverdue);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: hasOverdue
            ? Border.all(
                color: Colors.red.withValues(alpha: 0.3),
                width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: hasOverdue
              ? Colors.red.withValues(alpha: 0.12)
              : _blue.withValues(alpha: 0.12), // Swapped green for blue
          child: Text(
            customer.name[0].toUpperCase(),
            style: TextStyle(
              color: hasOverdue ? Colors.red : _blue, // Swapped green for blue
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(children: [
          Expanded(
              child: Text(customer.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14))),
          if (hasOverdue)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('Overdue',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
        ]),
        subtitle: Text(
            customer.phone ?? 'No phone number', // Translated from 'Walang numero'
            style: TextStyle(
                color: Colors.grey[500], fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyFormatter.format(totalOwed),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: totalOwed > 0 ? Colors.red : _blue, // Swapped green for blue
              ),
            ),
            // Translated from 'utang' to plural-sensitive English text
            Text(unpaid.length == 1 ? '1 balance' : '${unpaid.length} balances',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}