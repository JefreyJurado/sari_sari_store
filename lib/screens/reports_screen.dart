import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/report_service.dart';
import '../utils/currency_formatter.dart';
import '../widgets/profit_chart.dart';
import '../services/pdf_report_service.dart';
import 'sales_history_screen.dart';
import 'expenses_screen.dart';
import 'period_summary_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/center_toast.dart';
import '../widgets/help_sheet.dart';

const _blue = AppColors.blue;
const _green = Color(0xFF059669);
const _red = Color(0xFFDC2626);
const _purple = Color(0xFF7C3AED);

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _days = 7;
  ReportData? _report;
  bool _loading = false;
  bool _isPrinting = false;
  int? _lastComputedDays;
  int? _lastSalesHash;
  int? _lastExpensesHash;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _load(force: true));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prov = context.watch<AppProvider>();
    final currentSalesHash = Object.hashAll(prov.sales);
    final currentExpensesHash = Object.hashAll(prov.expenses);
    if (!_loading &&
        (currentSalesHash != _lastSalesHash ||
            currentExpensesHash != _lastExpensesHash)) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load({bool force = false}) async {
    if (!mounted) return;
    final prov = context.read<AppProvider>();
    final currentSalesHash = Object.hashAll(prov.sales);
    final currentExpensesHash =
        Object.hashAll(prov.expenses);
    if (!force &&
        _report != null &&
        _days == _lastComputedDays &&
        currentSalesHash == _lastSalesHash &&
        currentExpensesHash == _lastExpensesHash) {
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await ReportService.instance.generateReport(
        expenses: prov.expenses,
        days: _days,
      );
      if (mounted) {
        setState(() {
          _report = r;
          _lastComputedDays = _days;
          _lastSalesHash = currentSalesHash;
          _lastExpensesHash = currentExpensesHash;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _periodLabel {
    final now = DateTime.now();
    final months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December'
    ];
    switch (_days) {
      case 1:
        return 'Today — ${months[now.month - 1]} ${now.day}, ${now.year}';
      case 7:
        final start = now.subtract(const Duration(days: 6));
        return '${months[start.month - 1]} ${start.day} – ${months[now.month - 1]} ${now.day}, ${now.year}';
      case 14:
        final start = now.subtract(const Duration(days: 13));
        return '${months[start.month - 1]} ${start.day} – ${months[now.month - 1]} ${now.day}, ${now.year}';
      case 30:
        final start = now.subtract(const Duration(days: 29));
        return '${months[start.month - 1]} ${start.day} – ${months[now.month - 1]} ${now.day}, ${now.year}';
      case 60:
        final start = now.subtract(const Duration(days: 59));
        return '${months[start.month - 1]} ${start.day} – ${months[now.month - 1]} ${now.day}, ${now.year}';
      case 90:
        final start = now.subtract(const Duration(days: 89));
        return '${months[start.month - 1]} ${start.day} – ${months[now.month - 1]} ${now.day}, ${now.year}';
      case 180:
        final start = now.subtract(const Duration(days: 179));
        return '${months[start.month - 1]} ${start.day} – ${months[now.month - 1]} ${now.day}, ${now.year}';
      case 365:
        final start = now.subtract(const Duration(days: 364));
        return '${months[start.month - 1]} ${start.day}, ${start.year} – ${months[now.month - 1]} ${now.day}, ${now.year}';
      default:
        final start = now.subtract(Duration(days: _days - 1));
        return '${months[start.month - 1]} ${start.day} – ${months[now.month - 1]} ${now.day}, ${now.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(force: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Non-sticky Header ─────────────────
                const Row(children: [
                  Expanded(
                    child: Text('Reports',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: -0.5)),
                  ),
                  HelpIconButton(
                    title: 'Reading Your Reports',
                    points: [
                      'Pick a period (today, week, month, etc.) at the top — every card and chart below recalculates for that exact window.',
                      'Total Profit is revenue minus cost of goods sold; Net Income subtracts your logged expenses from that profit too, so it can be lower — or even negative if expenses outweigh profit.',
                      'Tap Total Profit or Net Income to see a full breakdown: where sales came from, profit by product, and expenses by category for that same period.',
                      'Export PDF Report generates a shareable summary of everything on this screen for your own records.',
                    ],
                  ),
                ]),
                Text(
                    'Analyze business performance trends',
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13)),
                const SizedBox(height: 16),

                // ── Period Selector ───────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.grey.shade200),
                  ),
                  child: Row(children: [
                    const Text('Analysis Period',
                        style: TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.grey.shade300),
                      ),
                      child: DropdownButton<int>(
                        value: _days,
                        isDense: true,
                        underline: const SizedBox(),
                        style: const TextStyle(
                            color: _blue,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                        icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: _blue,
                            size: 18),
                        items: const [
                          DropdownMenuItem(
                              value: 1,
                              child: Text('Today')),
                          DropdownMenuItem(
                              value: 7,
                              child: Text('7 Days')),
                          DropdownMenuItem(
                              value: 14,
                              child: Text('14 Days')),
                          DropdownMenuItem(
                              value: 30,
                              child: Text('1 Month')),
                          DropdownMenuItem(
                              value: 60,
                              child: Text('2 Months')),
                          DropdownMenuItem(
                              value: 90,
                              child: Text('3 Months')),
                          DropdownMenuItem(
                              value: 365,
                              child: Text('1 Year')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _days = v);
                            _load();
                          }
                        },
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),

                // ── Export PDF Button ─────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _report == null || _isPrinting
                            ? null
                            : () => _printReport(
                                context.read<AppProvider>()),
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2))
                        : const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 16),
                    label: Text(
                        _isPrinting
                            ? 'Generating PDF...'
                            : 'Export PDF Report',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10)),
                      disabledBackgroundColor:
                          Colors.grey.shade300,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Data ──────────────────────────────
                if (_loading && _report == null)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: CircularProgressIndicator()))
                else if (_report == null)
                  Center(
                      child: Padding(
                          padding: const EdgeInsets.only(
                              top: 60),
                          child: Text('No data available',
                              style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14))))
                else ...[
                  Row(children: [
                    _statCard(
                        'Total Sales',
                        CurrencyFormatter.format(
                            _report!.totalRevenue),
                        Icons.shopping_bag_outlined,
                        accentColor: _green,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const SalesHistoryScreen()))),
                    const SizedBox(width: 10),
                    _statCard(
                        'Total Profit',
                        CurrencyFormatter.format(
                            _report!.totalProfit),
                        Icons.trending_up_outlined,
                        accentColor: _green,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => PeriodSummaryScreen(
                                    periodLabel: _periodLabel,
                                    report: _report!)))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _statCard(
                        'Expenses',
                        CurrencyFormatter.format(
                            _report!.totalExpenses),
                        Icons.receipt_outlined,
                        accentColor: _red,
                        isAlert:
                            _report!.totalExpenses > 0,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const ExpensesScreen()))),
                    const SizedBox(width: 10),
                    _statCard(
                        'Net Income',
                        CurrencyFormatter.format(
                            _report!.netIncome),
                        Icons
                            .account_balance_wallet_outlined,
                        accentColor: _purple,
                        isAlert: _report!.netIncome < 0,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => PeriodSummaryScreen(
                                    periodLabel: _periodLabel,
                                    report: _report!)))),
                  ]),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.grey.shade200)),
                    child: Row(children: [
                      Icon(Icons.assignment_outlined,
                          color: Colors.grey[400],
                          size: 18),
                      const SizedBox(width: 10),
                      Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                        const Text('Transactions Volume',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.black87)),
                        Text(
                            'Processed within $_periodLabel',
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11)),
                      ]),
                      const Spacer(),
                      Text(
                          '${_report!.transactionCount}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: Colors.black87)),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader('Sales Performance Trend'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.grey.shade200)),
                    child: ProfitChart(
                        dailyData: _report!.dailyRevenue),
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader('Top Selling Products'),
                  const SizedBox(height: 10),

                  if (_report!.topProducts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.grey.shade200)),
                      child: Center(
                          child: Text(
                              'No product metrics yet',
                              style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13))),
                    )
                  else
                    ..._report!.topProducts
                        .asMap()
                        .entries
                        .map((e) => Container(
                              margin: const EdgeInsets.only(
                                  bottom: 8),
                              padding:
                                  const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(
                                          12),
                                  border: Border.all(
                                      color: Colors
                                          .grey.shade200)),
                              child: Row(children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                      color: Colors
                                          .grey.shade100,
                                      borderRadius:
                                          BorderRadius
                                              .circular(6)),
                                  child: Center(
                                      child: Text(
                                          '${e.key + 1}',
                                          style: TextStyle(
                                              fontWeight:
                                                  FontWeight
                                                      .bold,
                                              color: Colors
                                                  .grey[600],
                                              fontSize:
                                                  12))),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                    Text(
                                        e.value[
                                                'productName'] ??
                                            '',
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .w600,
                                            fontSize: 13,
                                            color: Colors
                                                .black87)),
                                    Text(
                                        '${e.value['totalQty']} units sold',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors
                                                .grey[500])),
                                  ]),
                                ),
                                Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .end,
                                    children: [
                                  Text(
                                      CurrencyFormatter
                                          .format((e.value[
                                                      'totalRevenue']
                                                  as num?)
                                              ?.toDouble() ??
                                          0),
                                      style: const TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 13,
                                          color:
                                              Colors.black87)),
                                  Text(
                                      'profit: ${CurrencyFormatter.format((e.value['totalProfit'] as num?)?.toDouble() ?? 0)}',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors
                                              .grey[500])),
                                ]),
                              ]),
                            )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value,
          IconData icon,
          {bool isAlert = false,
          Color? accentColor,
          VoidCallback? onTap}) {
    final color = isAlert ? Colors.red.shade600 : (accentColor ?? _blue);
    final colorDark = Color.lerp(color, Colors.black, 0.18)!;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, colorDark],
            ),
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            boxShadow: AppShadows.colored(color),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(icon, color: Colors.white, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: -0.5,
                      color: Colors.white),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(title,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87));

  Future<void> _printReport(AppProvider prov) async {
    if (_report == null || _isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      await PdfReportService.instance.generateAndPrint(
        prov: prov,
        days: _days,
        periodLabel: _periodLabel,
        report: _report!,
      );
    } catch (e) {
      if (mounted) {
        CenterToast.showError(context, 'Error: $e');
      }
    }
    if (mounted) setState(() => _isPrinting = false);
  }
}