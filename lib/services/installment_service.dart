import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/installment.dart';

class InstallmentService {
  static final InstallmentService instance = InstallmentService._();
  InstallmentService._();

  Future<List<Installment>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('installments') ?? '[]';
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((m) => Installment.fromMap(m as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));
    } catch (_) {
      return [];
    }
  }

  Future<void> save(Installment installment) async {
    final all = await getAll();
    final idx = all.indexWhere((i) => i.id == installment.id);
    if (idx != -1) {
      all[idx] = installment;
    } else {
      all.insert(0, installment);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'installments', jsonEncode(all.map((i) => i.toMap()).toList()));
  }

  Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((i) => i.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'installments', jsonEncode(all.map((i) => i.toMap()).toList()));
  }
}