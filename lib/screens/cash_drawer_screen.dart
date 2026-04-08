import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/cash_drawer.dart';
import '../providers/app_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';

const _uuid = Uuid();

class CashDrawerScreen extends StatefulWidget {
  const CashDrawerScreen({super.key});
  @override
  State<CashDrawerScreen> createState() =>
      _CashDrawerScreenState();
}

class _CashDrawerScreenState extends State<CashDrawerScreen> {
  CashDrawer? _currentDrawer;
  List<CashDrawer> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final drawerJson = prefs.getString('current_drawer');
    final historyList =
        prefs.getStringList('drawer_history') ?? [];

    if (drawerJson != null) {
      try {
        final map =
            jsonDecode(drawerJson) as Map<String, dynamic>;
        _currentDrawer = CashDrawer.fromMap(map);
      } catch (_) {}
    }

    _history = historyList.map((j) {
      try {
        return CashDrawer.fromMap(
            jsonDecode(j) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<CashDrawer>().toList();

    setState(() => _loading = false);
  }

  Future<void> _saveDrawer(CashDrawer drawer) async {
    final prefs = await SharedPreferences.getInstance();
    if (drawer.isOpen) {
      await prefs.setString(
          'current_drawer', jsonEncode(drawer.toMap()));
    } else {
      await prefs.remove('current_drawer');
      final history =
          prefs.getStringList('drawer_history') ?? [];
      history.insert(0, jsonEncode(drawer.toMap()));
      if (history.length > 30) history.removeLast();
      await prefs.setStringList('drawer_history', history);
    }
  }

  void _openDrawer() {
    final ctrl = TextEditingController(text: '0.00');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Buksan ang Cash Drawer'),
        content:
            Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Ilang cash ang nasa kahon sa simula?',
              style: TextStyle(
                  color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            keyboardType:
                const TextInputType.numberWithOptions(
                    decimal: true),
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: '₱ ',
              labelText: 'Opening Float',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kanselahin')),
          ElevatedButton(
            onPressed: () async {
              final float =
                  double.tryParse(ctrl.text) ?? 0;
              final drawer = CashDrawer(
                id: _uuid.v4(),
                openingFloat: float,
                closingFloat: 0,
                totalSales: 0,
                totalExpenses: 0,
                expectedCash: float,
                actualCash: 0,
                variance: 0,
                openedAt: DateTime.now(),
              );
              await _saveDrawer(drawer);
              setState(() => _currentDrawer = drawer);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Buksan'),
          ),
        ],
      ),
    );
  }

  void _closeDrawer() {
    final prov = context.read<AppProvider>();
    final ctrl = TextEditingController();

    final todayCashSales = prov.todaySales
        .where((s) => s.type.name == 'cash')
        .fold(0.0, (s, t) => s + t.cashPaid);

    final todayExpenses = prov.expenses
        .where((e) =>
            DateHelper.isSameDay(e.date, DateTime.now()))
        .fold(0.0, (s, e) => s + e.amount);

    final expectedCash = (_currentDrawer?.openingFloat ?? 0) +
        todayCashSales -
        todayExpenses;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Isara ang Cash Drawer'),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          _dialogRow('Opening Float:',
              CurrencyFormatter.format(
                  _currentDrawer?.openingFloat ?? 0)),
          _dialogRow('Cash Sales:',
              CurrencyFormatter.format(todayCashSales)),
          _dialogRow('Gastos:',
              '-${CurrencyFormatter.format(todayExpenses)}'),
          const Divider(height: 16),
          _dialogRow('Expected Cash:',
              CurrencyFormatter.format(expectedCash),
              bold: true),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            keyboardType:
                const TextInputType.numberWithOptions(
                    decimal: true),
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: '₱ ',
              labelText: 'Actual Cash sa Kahon',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kanselahin')),
          ElevatedButton(
            onPressed: () async {
              final actual =
                  double.tryParse(ctrl.text) ?? 0;
              final variance = actual - expectedCash;
              final closed = CashDrawer(
                id: _currentDrawer!.id,
                openingFloat: _currentDrawer!.openingFloat,
                closingFloat: actual,
                totalSales: todayCashSales,
                totalExpenses: todayExpenses,
                expectedCash: expectedCash,
                actualCash: actual,
                variance: variance,
                openedAt: _currentDrawer!.openedAt,
                closedAt: DateTime.now(),
              );
              await _saveDrawer(closed);
              setState(() {
                _history.insert(0, closed);
                _currentDrawer = null;
              });
              if (mounted) {
                Navigator.pop(context);
                _showVarianceResult(variance);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('Isara'),
          ),
        ],
      ),
    );
  }

  void _showVarianceResult(double variance) {
    final isOver = variance > 0;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(variance.abs() < 0.01
            ? 'Tama ang Cash!'
            : isOver
                ? 'May Sobra'
                : 'May Kulang'),
        content:
            Column(mainAxisSize: MainAxisSize.min, children: [
          if (variance.abs() < 0.01)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Icon(Icons.check_circle_outline,
                    color: Colors.green, size: 32),
                SizedBox(width: 10),
                Text('Perpekto!',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isOver
                    ? Colors.green.withValues(alpha: 0.08)
                    : Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                Text(
                  isOver ? 'SOBRA' : 'KULANG',
                  style: TextStyle(
                      color: isOver ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
                Text(
                  CurrencyFormatter.format(variance.abs()),
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color:
                          isOver ? Colors.green : Colors.red),
                ),
              ]),
            ),
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar:
          AppBar(title: const Text('Cash Drawer')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header banner
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _currentDrawer != null
                          ? const Color(0xFF2E7D32)
                          : Colors.grey[600],
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(28),
                        bottomRight: Radius.circular(28),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                        20, 16, 20, 28),
                    child: Column(children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color:
                              Colors.white.withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _currentDrawer != null
                              ? Icons.lock_open_outlined
                              : Icons.lock_outlined,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _currentDrawer != null
                            ? 'Drawer ay Bukas'
                            : 'Drawer ay Sarado',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                      if (_currentDrawer != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Binuksan: ${DateHelper.formatTime(_currentDrawer!.openedAt)}  •  Float: ${CurrencyFormatter.format(_currentDrawer!.openingFloat)}',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12),
                        ),
                      ],
                    ]),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // Action button
                        SizedBox(
                          width: double.infinity,
                          child: _currentDrawer == null
                              ? ElevatedButton.icon(
                                  onPressed: _openDrawer,
                                  icon: const Icon(
                                      Icons.lock_open_outlined),
                                  label: const Text(
                                      'Buksan ang Drawer',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight:
                                              FontWeight.bold)),
                                  style:
                                      ElevatedButton.styleFrom(
                                          padding:
                                              const EdgeInsets
                                                  .symmetric(
                                                  vertical: 14)),
                                )
                              : ElevatedButton.icon(
                                  onPressed: _closeDrawer,
                                  icon: const Icon(
                                      Icons.lock_outlined),
                                  label: const Text(
                                      'Isara ang Drawer',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight:
                                              FontWeight.bold)),
                                  style:
                                      ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.red,
                                          padding:
                                              const EdgeInsets
                                                  .symmetric(
                                                  vertical: 14)),
                                ),
                        ),
                        const SizedBox(height: 24),

                        // History
                        const Text('Kasaysayan ng Drawer',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        const SizedBox(height: 10),

                        if (_history.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(children: [
                              Icon(Icons.history_outlined,
                                  size: 48,
                                  color: Colors.grey[300]),
                              const SizedBox(height: 8),
                              Text('Walang kasaysayan pa',
                                  style: TextStyle(
                                      color: Colors.grey[400])),
                            ]),
                          )
                        else
                          ..._history.map((d) {
                            final isCorrect =
                                d.variance.abs() < 0.01;
                            final isShort = d.variance < 0;
                            Color varColor = isCorrect
                                ? Colors.green
                                : isShort
                                    ? Colors.red
                                    : Colors.orange;

                            return Container(
                              margin: const EdgeInsets.only(
                                  bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Row(children: [
                                    Text(
                                        DateHelper.formatDate(
                                            d.openedAt),
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 14)),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets
                                          .symmetric(
                                          horizontal: 8,
                                          vertical: 4),
                                      decoration: BoxDecoration(
                                        color: varColor
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(
                                                8),
                                      ),
                                      child: Text(
                                        isCorrect
                                            ? 'Tama'
                                            : isShort
                                                ? 'Kulang ${CurrencyFormatter.format(d.variance.abs())}'
                                                : 'Sobra ${CurrencyFormatter.format(d.variance.abs())}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight:
                                                FontWeight.w600,
                                            color: varColor),
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 10),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),
                                  _histRow('Opening Float:',
                                      CurrencyFormatter.format(
                                          d.openingFloat)),
                                  _histRow('Cash Sales:',
                                      CurrencyFormatter.format(
                                          d.totalSales)),
                                  _histRow('Gastos:',
                                      CurrencyFormatter.format(
                                          d.totalExpenses)),
                                  _histRow('Expected:',
                                      CurrencyFormatter.format(
                                          d.expectedCash)),
                                  _histRow('Actual:',
                                      CurrencyFormatter.format(
                                          d.actualCash)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding:
                                        const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: varColor
                                          .withValues(alpha: 0.08),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Row(children: [
                                      Text('Variance:',
                                          style: TextStyle(
                                              color: varColor,
                                              fontWeight:
                                                  FontWeight.w600)),
                                      const Spacer(),
                                      Text(
                                        '${d.variance >= 0 ? '+' : ''}${CurrencyFormatter.format(d.variance)}',
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            color: varColor,
                                            fontSize: 16),
                                      ),
                                    ]),
                                  ),
                                ]),
                              ),
                            );
                          }),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _dialogRow(String label, String value,
          {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(label,
              style: TextStyle(color: Colors.grey[600])),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontWeight: bold
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: bold ? 16 : 14)),
        ]),
      );

  Widget _histRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey[500], fontSize: 12)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}