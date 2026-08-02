import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/cico_transaction.dart';
import '../models/cico_rate.dart';
import '../theme/app_theme.dart';
import '../utils/cico_type_meta.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import '../widgets/help_sheet.dart';
import '../widgets/rate_ladder.dart';
import 'cico_screen.dart';
import 'rate_settings_screen.dart';

const _darkNavy = Color(0xFF0F172A);
// Matches the reference mockup's literal Cash-In blue — scoped to this
// screen only. The rest of CICO (ledger, balances, rate settings) keeps the
// app's existing green so they still read as one consistent app.
const _mockupBlue = Color(0xFF2563EB);

// A fast, no-friction calculator matching the reference Padala Counter
// mockup: pick a provider and direction, type an amount, see the fee and
// total instantly. Unlike the full Add Transaction form (funding account,
// customer info, notes...), this never has to be "saved" — it's for
// quoting a customer on the spot. "Record as Transaction" hands the result
// off to that full form for anyone who does want to log it.
class PadalaCalculatorScreen extends StatefulWidget {
  const PadalaCalculatorScreen({super.key});

  @override
  State<PadalaCalculatorScreen> createState() => _PadalaCalculatorScreenState();
}

const _quickAmounts = [100, 200, 500, 1000, 2000, 5000];

class _PadalaCalculatorScreenState extends State<PadalaCalculatorScreen> {
  CicoType _type = CicoType.cashIn;
  String? _provider;
  final _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  // cicoKnownProviders already folds in CicoTransaction.presetProviders.
  List<String> _allProviders(AppProvider prov) => prov.cicoKnownProviders;

  Widget _headerIconToggle() {
    Widget iconBtn(IconData icon, bool active, VoidCallback onTap) =>
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: active ? _darkNavy : Colors.white,
              borderRadius: BorderRadius.circular(9),
            ),
            child:
                Icon(icon, size: 17, color: active ? Colors.white : _darkNavy),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        iconBtn(Icons.calculate_outlined, true, () {}),
        const SizedBox(width: 3),
        iconBtn(
            Icons.settings_outlined,
            false,
            () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RateSettingsScreen()))),
      ]),
    );
  }

  Widget _dotStrip() {
    return Row(
      children: List.generate(
        16,
        (i) => Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillTab(String label, CicoType type, Color color) {
    final selected = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : Colors.grey[600])),
      ),
    );
  }

  Widget _recentTxnTile(BuildContext context, CicoTransaction txn) {
    final meta = cicoTypeMeta[txn.type]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () => _showTxnDetail(context, txn),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: meta.color.withValues(alpha: 0.15))),
          child: Icon(meta.icon, color: meta.color, size: 16),
        ),
        title: Text('${meta.label} • ${cicoProviderLabel(txn.provider)}',
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: Colors.black87)),
        subtitle: Text(DateHelper.formatDate(txn.createdAt),
            style: TextStyle(color: Colors.grey[500], fontSize: 10.5)),
        trailing: Text(CurrencyFormatter.format(txn.amount),
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 13)),
      ),
    );
  }

  // Tapping a recent transaction shows its details right here — no reason
  // to leave the Calculator and land on the full ledger just to see one
  // entry.
  void _showTxnDetail(BuildContext context, CicoTransaction txn) {
    final meta = cicoTypeMeta[txn.type]!;
    final isInOut = txn.type == CicoType.cashIn || txn.type == CicoType.cashOut;
    final fundedViaBank =
        isInOut && txn.liquidAccount != CicoTransaction.cashAccount;
    final fundedViaLabel =
        txn.type == CicoType.cashIn ? 'Received into' : 'Paid from';

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: Text(value,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.black87)),
              ),
            ],
          ),
        );

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: meta.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: meta.color.withValues(alpha: 0.15))),
                    child: Icon(meta.icon, color: meta.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        '${meta.label} • ${cicoProviderLabel(txn.provider)}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87)),
                  ),
                ]),
                const SizedBox(height: 20),
                row('Amount', CurrencyFormatter.format(txn.amount)),
                if (txn.commission > 0)
                  row('Commission', CurrencyFormatter.format(txn.commission)),
                if (fundedViaBank) row(fundedViaLabel, txn.liquidAccount),
                if (isInOut &&
                    txn.customerName != null &&
                    txn.customerName!.isNotEmpty)
                  row('Customer', txn.customerName!),
                if (isInOut &&
                    txn.customerPhone != null &&
                    txn.customerPhone!.isNotEmpty)
                  row('Number', txn.customerPhone!),
                if (txn.notes != null && txn.notes!.isNotEmpty)
                  row('Notes', txn.notes!),
                row('Date', DateHelper.formatDate(txn.createdAt)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Close',
                        style:
                            TextStyle(color: Colors.grey[700], fontSize: 13)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, prov, _) {
      final providers = _allProviders(prov);
      final provider = _provider != null && providers.contains(_provider)
          ? _provider!
          : (providers.isNotEmpty ? providers.first : null);
      final color = _type == CicoType.cashIn ? _mockupBlue : AppColors.orange;
      final amount = double.tryParse(_amountCtrl.text) ?? 0;

      final tiers = provider == null
          ? const <CicoRateRule>[]
          : prov.rateTiersFor(provider: provider, type: _type);
      final matched = provider == null || amount <= 0
          ? null
          : prov.resolveRate(type: _type, provider: provider, amount: amount);
      final commission = matched?.commissionFor(amount) ?? 0;

      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: providers.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calculate_outlined,
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('No providers set up yet',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 14)),
                        ]),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Row(
                      children: [
                        if (Navigator.canPop(context))
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.black87),
                          )
                        else
                          const SizedBox(width: 12),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PADALA COUNTER',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                      color: Colors.grey[500])),
                              const Text('Cash-In / Cash-Out',
                                  style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      letterSpacing: -0.5)),
                              if (prov.cicoTodayCommission > 0) ...[
                                const SizedBox(height: 3),
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.celebration_outlined,
                                      size: 12, color: AppColors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                      '${CurrencyFormatter.format(prov.cicoTodayCommission)} earned today',
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.green)),
                                ]),
                              ],
                            ],
                          ),
                        ),
                        _headerIconToggle(),
                        const SizedBox(width: 4),
                        const HelpIconButton(
                          title: 'Padala Calculator',
                          points: [
                            'Pick a provider and Cash In/Cash Out, then type an amount — the fee and total update instantly from your configured rate tiers.',
                            'The full rate ladder for that provider and direction is shown below, with the bracket your amount falls into highlighted.',
                            'This is just a quick quote tool — nothing is saved until you tap "Record as Transaction", which opens the full entry form pre-filled.',
                            'No rates showing? Tap the gear icon above to add fee tiers for this provider and direction.',
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (providers.length > 1) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in providers)
                            GestureDetector(
                              onTap: () => setState(() => _provider = p),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: p == provider
                                      ? _darkNavy
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(p,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: p == provider
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: p == provider
                                            ? Colors.white
                                            : Colors.grey[600])),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],

                    // ── Card ─────────────────────────────────────
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: AppShadows.soft,
                      ),
                      child: Column(children: [
                        Container(height: 5, color: color),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                          child: Column(children: [
                            _dotStrip(),
                            const SizedBox(height: 16),

                            // Big pill toggle
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Row(children: [
                                Expanded(
                                    child: _pillTab('Cash-In', CicoType.cashIn,
                                        _mockupBlue)),
                                Expanded(
                                    child: _pillTab('Cash-Out',
                                        CicoType.cashOut, AppColors.orange)),
                              ]),
                            ),
                            const SizedBox(height: 20),

                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  _type == CicoType.cashIn
                                      ? 'AMOUNT TO CASH IN'
                                      : 'AMOUNT TO CASH OUT',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: Colors.grey[500])),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _amountCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                              decoration: InputDecoration(
                                prefixText: '₱ ',
                                prefixStyle: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54),
                                hintText: 'Enter amount',
                                hintStyle: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade400),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                        color: Colors.grey.shade300)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                        color: Colors.grey.shade300)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide:
                                        BorderSide(color: color, width: 1.5)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final quick in _quickAmounts)
                                  GestureDetector(
                                    onTap: () => setState(
                                        () => _amountCtrl.text = '$quick'),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: amount == quick
                                            ? color.withValues(alpha: 0.12)
                                            : Colors.grey.shade100,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: amount == quick
                                            ? Border.all(
                                                color: color.withValues(
                                                    alpha: 0.4))
                                            : null,
                                      ),
                                      child: Text('₱$quick',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: amount == quick
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: amount == quick
                                                  ? color
                                                  : Colors.grey[600])),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            if (tiers.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Column(children: [
                                  Text(
                                      provider == null
                                          ? 'No provider available.'
                                          : 'No rates configured for $provider '
                                              '(${_type == CicoType.cashIn ? 'Cash In' : 'Cash Out'}) yet.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          color: Colors.grey[600])),
                                  const SizedBox(height: 10),
                                  OutlinedButton(
                                    onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const RateSettingsScreen())),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                          color: Colors.grey.shade300),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Set Up Rates',
                                        style: TextStyle(fontSize: 12.5)),
                                  ),
                                ]),
                              )
                            else
                              RateLadderBody(
                                tiers: tiers,
                                matched: matched,
                                color: color,
                                amount: amount,
                                commission: commission,
                              ),

                            const SizedBox(height: 6),
                            Text(
                                'Rates are set from Manage Rates and may differ '
                                'from other agents/tellers.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[400])),
                          ]),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: amount <= 0 || provider == null
                            ? null
                            : () {
                                // Pushed from CicoScreen/RateSettingsScreen's
                                // calculator icon: pop back with the result
                                // and let that screen open the prefilled
                                // form. Reached via the bottom-nav tab
                                // instead (nothing to pop to): push CicoScreen
                                // directly, which prefills itself on mount.
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context, {
                                    'type': _type,
                                    'provider': provider,
                                    'amount': amount,
                                  });
                                } else {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => CicoScreen(
                                              prefillType: _type,
                                              prefillProvider: provider,
                                              prefillAmount: amount)));
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade200,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Record as Transaction',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),

                    if (prov.cico.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Row(children: [
                        Text('RECENT TRANSACTIONS',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: Colors.grey[500])),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const CicoScreen())),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('View All',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _darkNavy)),
                              Icon(Icons.chevron_right_rounded,
                                  size: 16, color: _darkNavy),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      for (final txn in prov.cico.take(6))
                        _recentTxnTile(context, txn),
                    ],
                  ],
                ),
        ),
      );
    });
  }
}
