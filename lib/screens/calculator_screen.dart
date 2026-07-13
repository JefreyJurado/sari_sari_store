import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _display = '0';
  String _expression = '';
  double _firstNum = 0;
  String _operator = '';
  bool _newNum = true;

  void _onButton(String val) {
    setState(() {
      if (val == 'C') {
        _display = '0';
        _expression = '';
        _firstNum = 0;
        _operator = '';
        _newNum = true;
      } else if (val == '⌫') {
        if (_display.length > 1) {
          _display = _display.substring(0, _display.length - 1);
        } else {
          _display = '0';
          _newNum = true;
        }
      } else if (val == '%') {
        final n = double.tryParse(_display) ?? 0;
        _display = _formatNum(n / 100);
        _newNum = true;
      } else if (['+', '-', '×', '÷'].contains(val)) {
        _firstNum = double.tryParse(_display) ?? 0;
        _operator = val;
        _expression = '${_withCommas(_formatNum(_firstNum))} $val';
        _newNum = true;
      } else if (val == '=') {
        if (_operator.isEmpty) return;
        final second = double.tryParse(_display) ?? 0;
        double result = 0;
        switch (_operator) {
          case '+': result = _firstNum + second; break;
          case '-': result = _firstNum - second; break;
          case '×': result = _firstNum * second; break;
          case '÷':
            result = second != 0 ? _firstNum / second : 0;
            break;
        }
        _expression =
            '${_withCommas(_formatNum(_firstNum))} $_operator ${_withCommas(_formatNum(second))} =';
        _display = _formatNum(result);
        _operator = '';
        _newNum = true;
      } else if (val == '.') {
        if (_newNum) {
          _display = '0.';
          _newNum = false;
        } else if (!_display.contains('.')) {
          _display += '.';
        }
      } else {
        // Number
        if (_newNum) {
          _display = val;
          _newNum = false;
        } else {
          if (_display == '0') {
            _display = val;
          } else {
            if (_display.length < 12) _display += val;
          }
        }
      }
    });
  }

  String _formatNum(double n) {
    if (n == n.truncateToDouble()) {
      return n.toInt().toString();
    }
    String s = n.toStringAsFixed(8);
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
    return s;
  }

  /// Inserts thousands-separator commas into a plain numeric string for
  /// display only — the underlying `_display`/`_firstNum` values stay
  /// comma-free so double.tryParse keeps working unmodified.
  String _withCommas(String raw) {
    final isNegative = raw.startsWith('-');
    final unsigned = isNegative ? raw.substring(1) : raw;
    final dotIndex = unsigned.indexOf('.');
    final wholePart =
        dotIndex == -1 ? unsigned : unsigned.substring(0, dotIndex);
    final decimalPart = dotIndex == -1 ? '' : unsigned.substring(dotIndex);
    final buffer = StringBuffer();
    for (int i = 0; i < wholePart.length; i++) {
      if (i > 0 && (wholePart.length - i) % 3 == 0) buffer.write(',');
      buffer.write(wholePart[i]);
    }
    return '${isNegative ? '-' : ''}$buffer$decimalPart';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: const Text('Calculator',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
      ),
      body: Column(children: [

        // ── Display ────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.blue, AppColors.blueDark],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            boxShadow: AppShadows.colored(AppColors.blue),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Expression
              Text(
                _expression.isEmpty ? ' ' : _expression,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 16), // Slightly brighter for visibility
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 8),
              // Main display
              Text(
                _withCommas(_display),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Buttons ──────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: [
              _row(['C', '%', '⌫', '÷']),
              const SizedBox(height: 10),
              _row(['7', '8', '9', '×']),
              const SizedBox(height: 10),
              _row(['4', '5', '6', '-']),
              const SizedBox(height: 10),
              _row(['1', '2', '3', '+']),
              const SizedBox(height: 10),
              _row(['0', '.', '=', '']),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _row(List<String> btns) => Expanded(
    child: Row(children: btns.asMap().entries.map((e) {
      final i = e.key;
      final val = e.value;
      if (val.isEmpty) return const Expanded(child: SizedBox());
      return Expanded(
        child: Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
          child: _CalcButton(
            label: val,
            onTap: () => _onButton(val),
            isOperator: ['+', '-', '×', '÷', '='].contains(val),
            isSpecial: ['C', '%', '⌫'].contains(val),
            isEquals: val == '=',
          ),
        ),
      );
    }).toList()),
  );
}

class _CalcButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isOperator;
  final bool isSpecial;
  final bool isEquals;

  const _CalcButton({
    required this.label,
    required this.onTap,
    this.isOperator = false,
    this.isSpecial = false,
    this.isEquals = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    if (isEquals) {
      bg = AppColors.blue;
      fg = Colors.white;
    } else if (isOperator) {
      bg = AppColors.blue.withValues(alpha: 0.10);
      fg = AppColors.blue;
    } else if (isSpecial) {
      bg = Colors.grey.shade200;
      fg = Colors.grey.shade700;
    } else {
      bg = Colors.white;
      fg = AppColors.textPrimary;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}