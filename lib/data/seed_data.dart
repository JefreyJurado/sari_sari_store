import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../services/database_service.dart';

const _uuid = Uuid();

class SeedData {
  static Future<void> seedSampleCustomers() async {
    final existing = await DatabaseService.instance.getCustomers();
    if (existing.isNotEmpty) return;

    final samples = [
      Customer(
          id: _uuid.v4(),
          name: 'Ate Maria',
          phone: '09171234567',
          createdAt: DateTime.now()),
      Customer(
          id: _uuid.v4(),
          name: 'Kuya Ben',
          phone: '09281234567',
          createdAt: DateTime.now()),
      Customer(
          id: _uuid.v4(),
          name: 'Nanay Luz',
          creditLimit: 1000,
          createdAt: DateTime.now()),
    ];
    for (final c in samples) {
      await DatabaseService.instance.insertCustomer(c);
    }
  }
}