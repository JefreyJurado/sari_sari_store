import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/cico_transaction.dart';
import '../models/cico_rate.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/center_toast.dart';
import '../widgets/help_sheet.dart';
import '../widgets/rate_ladder.dart';
import '../widgets/search_field.dart';
import '../utils/cico_type_meta.dart';
import 'padala_calculator_screen.dart';
import 'rate_settings_screen.dart';

const _indigo = Color(0xFF4F46E5);
// Fallback colors for accounts with no official logo asset below.
const _gcashBlue = Color(0xFF0072CE);
const _mayaGreen = Color(0xFF1DB58C);
const _bankColor = AppColors.purple;

// Official logos supplied by the store owner, matched case-insensitively
// against the account name. Falls back to a colored initial/icon for any
// name not in this list (custom banks, other wallets, etc.).
const _brandAssets = {
  'gcash': 'assets/banks-and-e-wallets/gcash.svg',
  'maya': 'assets/banks-and-e-wallets/maya.svg',
  'bdo': 'assets/banks-and-e-wallets/bdo.svg',
  'bpi': 'assets/banks-and-e-wallets/bpi.svg',
  'metrobank': 'assets/banks-and-e-wallets/metrobank.svg',
  'rcbc': 'assets/banks-and-e-wallets/rcbc.svg',
  'securitybank': 'assets/banks-and-e-wallets/security_bank.svg',
  'chinabank': 'assets/banks-and-e-wallets/chinabank.png',
  'pnb': 'assets/banks-and-e-wallets/pnb.svg',
  'unionbank': 'assets/banks-and-e-wallets/unionbank.svg',
  'psbank': 'assets/banks-and-e-wallets/psbank.svg',
  'eastwest': 'assets/banks-and-e-wallets/eastwest.png',
  'eastwestbank': 'assets/banks-and-e-wallets/eastwest.png',
};

// Strips spaces/punctuation before matching so "Metro Bank", "MetroBank",
// "metro-bank", etc. all resolve to the same logo regardless of exactly
// how the account name was typed.
String _brandKey(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String? _brandAssetFor(String name) => _brandAssets[_brandKey(name)];

// A small badge showing the account's real logo — white backdrop so it
// reads clearly on any colored surface, except Chinabank whose asset is a
// white-on-transparent mark and needs its actual brand-red backdrop instead.
Widget _brandBadge(String name, {double size = 22}) {
  final asset = _brandAssetFor(name);
  if (asset == null) return const SizedBox.shrink();
  final isChinabank = _brandKey(name) == 'chinabank';
  final content = asset.endsWith('.svg')
      ? SvgPicture.asset(asset, fit: BoxFit.contain)
      : ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: Image.asset(asset, fit: BoxFit.contain));
  return Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(size * 0.16),
    decoration: BoxDecoration(
      color: isChinabank ? AppColors.red : Colors.white,
      borderRadius: BorderRadius.circular(size * 0.26),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 2)
      ],
    ),
    child: content,
  );
}

Color _walletColor(String name) => switch (name) {
      'GCash' => _gcashBlue,
      'Maya' => _mayaGreen,
      _ => _indigo,
    };

// Type label/icon/color live in one shared place (cicoTypeMeta) so the
// ledger and the calculator can't drift apart on branding.
const _typeMeta = cicoTypeMeta;

// Top Up/Withdraw (rebalancing between your own accounts) are no longer
// offered as a new-transaction choice — Cash In/Cash Out (customer
// transactions) are the only thing this app records going forward. Any
// historical Top Up/Withdraw rows are left alone (still visible under the
// "All" filter, still editable) rather than deleted or hidden outright.
const _recordableTypes = [CicoType.cashIn, CicoType.cashOut];

final _filterLabels = [
  'All',
  for (final t in _recordableTypes) _typeMeta[t]!.label,
];

CicoType? _typeForFilter(String label) => _recordableTypes
    .cast<CicoType?>()
    .firstWhere((t) => _typeMeta[t]!.label == label, orElse: () => null);

String _providerLabel(String provider) => cicoProviderLabel(provider);

// Reference only — actual agent commission depends on your specific
// provider agreement and changes over time, so this is a rough guide,
// not an auto-calculated value.
String _rateHint(CicoType type, String provider) {
  if (type == CicoType.cashIn) {
    return switch (provider) {
      'GCash' => 'Typical: ~1% via GCash Pera Outlet, or a flat ₱10–₱205 '
          'tiered fee at informal over-the-counter agents.',
      'Maya' => 'Typical: often free up to ₱8,000/month, then ~2%.',
      _ => 'Rates vary by provider agreement — check with them directly.',
    };
  }
  return switch (provider) {
    'GCash' => 'Typical: ~2% of the cash-out amount.',
    'Maya' => 'Typical: ~1.5% via Maya Center.',
    _ => 'Rates vary by provider agreement — check with them directly.',
  };
}

class CicoScreen extends StatefulWidget {
  // Set together when arriving from the Padala Calculator's "Record as
  // Transaction" button (pushed as a fresh screen rather than popped back
  // to, since the calculator has nothing to pop to when it's the root tab)
  // — opens the Add Transaction form pre-filled as soon as this screen
  // mounts.
  final CicoType? prefillType;
  final double? prefillAmount;
  final String? prefillProvider;

  const CicoScreen(
      {super.key, this.prefillType, this.prefillAmount, this.prefillProvider});
  @override
  State<CicoScreen> createState() => _CicoScreenState();
}

class _CicoScreenState extends State<CicoScreen> {
  String _filter = 'All';
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.prefillType != null && widget.prefillAmount != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        // This screen only exists here to host the prefilled form — once
        // it closes (saved or dismissed), go straight back to the
        // Calculator instead of leaving the user stranded on the ledger.
        await _showForm(context, context.read<AppProvider>(), null,
            initialType: widget.prefillType,
            prefillAmount: widget.prefillAmount,
            prefillProvider: widget.prefillProvider);
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, prov, _) {
      final filterType = _typeForFilter(_filter);
      var transactions = filterType == null
          ? prov.cico
          : prov.cico.where((t) => t.type == filterType).toList();
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        transactions = transactions
            .where((t) =>
                _providerLabel(t.provider).toLowerCase().contains(q) ||
                (t.customerName?.toLowerCase().contains(q) ?? false) ||
                (t.customerPhone?.toLowerCase().contains(q) ?? false) ||
                (t.notes?.toLowerCase().contains(q) ?? false))
            .toList();
      }

      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PADALA COUNTER',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Colors.grey[500])),
              const Text('Cash In-Cash Out',
                  style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: -0.5)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Padala Calculator',
              icon: const Icon(Icons.calculate_outlined, color: Colors.black87),
              onPressed: () async {
                final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PadalaCalculatorScreen()));
                if (result is Map && context.mounted) {
                  _showForm(context, prov, null,
                      initialType: result['type'] as CicoType,
                      prefillAmount: result['amount'] as double,
                      prefillProvider: result['provider'] as String);
                }
              },
            ),
            const HelpIconButton(
              title: 'Cash In-Cash Out (E-Wallet)',
              points: [
                'Use this to monitor your GCash/Maya agent side-business: log every Cash In (customer gives you cash, you send them e-money) and Cash Out (customer sends you e-money, you give them cash).',
                "If a customer's cash-in/out was funded via bank transfer instead of physical cash, pick the bank directly under \"Received Into\" (Cash In) or \"Paid From\" (Cash Out).",
                'Cash In/Out entries can also record the customer\'s name and number for your own recordkeeping — both are optional.',
                "Commission earned per transaction is tracked on its own — it's just a running total of what you've earned, shown up top.",
                'Tap "Manage Rates" to set up fixed or percentage fee tiers per provider and direction — once configured, the commission field on a new Cash In/Cash Out auto-fills based on the amount you enter (you can still edit it by hand).',
                'Record any amount — this screen is for monitoring your transactions, not validating them against a balance.',
                'Tap any transaction to view its full details; use the ⋮ menu on the row to edit or delete it.',
              ],
            ),
          ],
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
                  Text('Track cash-in/cash-out and e-wallet float',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Icon(Icons.percent_rounded, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      'Commission earned (all time): '
                      '${CurrencyFormatter.format(prov.cicoTotalCommission)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RateSettingsScreen())),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      color: _indigo.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Manage Rates',
                            style: TextStyle(
                                color: _indigo,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                        SizedBox(width: 3),
                        Icon(Icons.chevron_right_rounded,
                            size: 16, color: _indigo),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SearchField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                hintText: 'Search customer, provider, or notes...',
              ),
            ),
            const SizedBox(height: 10),

            // ── Filter chips ─────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _filterLabels.map((label) {
                    final sel = _filter == label;
                    return GestureDetector(
                      onTap: () => setState(() => _filter = label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel ? _indigo : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          label,
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
            ),
            const SizedBox(height: 10),

            Divider(height: 1, color: Colors.grey.shade100),

            // ── Transaction List ─────────────────────
            Expanded(
              child: transactions.isEmpty
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
                                Icons.account_balance_wallet_outlined,
                                size: 48,
                                color: Colors.grey[300]),
                          ),
                          const SizedBox(height: 12),
                          Text('No e-wallet transactions yet',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 14)),
                        ]))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: transactions.length,
                      itemBuilder: (_, i) => _CicoTile(
                        txn: transactions[i],
                        onView: () =>
                            _showDetail(context, prov, transactions[i]),
                        onDelete: () =>
                            _confirmDelete(context, prov, transactions[i]),
                        onEdit: () => _showForm(context, prov, transactions[i]),
                      ),
                    ),
            ),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'cico_fab',
          onPressed: () => _showTypeChooser(context, prov),
          backgroundColor: _indigo,
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Transaction',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      );
    });
  }

  List<String> _allBanks(AppProvider prov) => prov.cicoKnownBanks.toList();

  // cicoKnownProviders already folds in CicoTransaction.presetProviders.
  List<String> _allWallets(AppProvider prov) => prov.cicoKnownProviders;

  String? _floatWarning(
    AppProvider prov,
    CicoType type, {
    required String wallet,
    required String liquidAccount,
    required CicoAccountKind accountKind,
    required String targetAccount,
    String? transferAccount,
    required double amount,
  }) {
    if (amount <= 0) return null;
    switch (type) {
      // This screen is for monitoring/recording transactions, not
      // validating them against a running balance — record any amount,
      // regardless of the wallet/float balance. (Also: with Top Up removed,
      // a wallet balance here can no longer be topped up from within the
      // app at all, so "exceeds balance" would trigger on nearly every
      // entry and stop being meaningful.)
      case CicoType.cashIn:
      case CicoType.cashOut:
        return null;
      case CicoType.withdraw:
        final (bal, label) = switch (accountKind) {
          CicoAccountKind.cash => (prov.cicoCashFloatBalance, 'cash float'),
          CicoAccountKind.bank => (
              prov.cicoBankBalance(targetAccount),
              '$targetAccount balance'
            ),
          CicoAccountKind.wallet => (
              prov.cicoWalletBalance(targetAccount),
              '$targetAccount e-wallet balance'
            ),
        };
        if (amount > bal) {
          return 'This exceeds your current $label '
              '(${CurrencyFormatter.format(bal)}). You can still save, '
              'but it will go negative.';
        }
        return null;
      case CicoType.topUp:
        if (transferAccount == null) return null;
        final (bal, label) = transferAccount == CicoTransaction.cashAccount
            ? (prov.cicoCashFloatBalance, 'cash float')
            : _allBanks(prov).contains(transferAccount)
                ? (
                    prov.cicoBankBalance(transferAccount),
                    '$transferAccount balance'
                  )
                : (
                    prov.cicoWalletBalance(transferAccount),
                    '$transferAccount e-wallet balance'
                  );
        if (amount > bal) {
          return 'This exceeds your current $label '
              '(${CurrencyFormatter.format(bal)}). You can still save, '
              'but it will go negative.';
        }
        return null;
    }
  }

  void _showDetail(
      BuildContext context, AppProvider prov, CicoTransaction txn) {
    final meta = _typeMeta[txn.type]!;
    final isInOut = txn.type == CicoType.cashIn || txn.type == CicoType.cashOut;
    final fundedViaBank =
        isInOut && txn.liquidAccount != CicoTransaction.cashAccount;
    final fundedViaLabel =
        txn.type == CicoType.cashIn ? 'Received into' : 'Paid from';
    final transferLabel = txn.type == CicoType.topUp
        ? 'Funded from'
        : txn.type == CicoType.withdraw
            ? 'Sent to'
            : null;

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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                  child: Text('${meta.label} • ${_providerLabel(txn.provider)}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                ),
              ]),
              const SizedBox(height: 20),
              row('Amount', CurrencyFormatter.format(txn.amount)),
              if (isInOut) row('Provider', _providerLabel(txn.provider)),
              if (txn.commission > 0)
                row('Commission', CurrencyFormatter.format(txn.commission)),
              if (fundedViaBank) row(fundedViaLabel, txn.liquidAccount),
              if (transferLabel != null && txn.transferAccount != null)
                row(transferLabel, txn.transferAccount!),
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
              row('Date', DateHelper.formatDateTime(txn.createdAt)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetCtx),
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
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      _showForm(context, prov, txn);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _indigo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Edit',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  // Lets the "Add Transaction" FAB ask what kind of transaction this is
  // before opening the form, rather than always defaulting to Cash In and
  // relying on the type chips inside the form to be noticed and changed.
  void _showTypeChooser(BuildContext context, AppProvider prov) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text('Add Transaction',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87)),
              const SizedBox(height: 2),
              Text('What kind of transaction is this?',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 16),
              for (final t in _recordableTypes) ...[
                _typeChoiceTile(sheetCtx, context, prov, t),
                if (t != _recordableTypes.last) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChoiceTile(BuildContext sheetCtx, BuildContext pageContext,
      AppProvider prov, CicoType t) {
    final meta = _typeMeta[t]!;
    return GestureDetector(
      onTap: () {
        Navigator.pop(sheetCtx);
        _showForm(pageContext, prov, null, initialType: t);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: meta.color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: meta.color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(meta.icon, color: meta.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meta.label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(meta.description,
                      style:
                          TextStyle(fontSize: 11.5, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _showForm(
      BuildContext context, AppProvider prov, CicoTransaction? existing,
      {CicoType? initialType, double? prefillAmount, String? prefillProvider}) {
    CicoType type = existing?.type ?? initialType ?? CicoType.cashIn;
    final isInOutInitial = type == CicoType.cashIn || type == CicoType.cashOut;

    // Chip lists always include whatever account this transaction already
    // uses (even if it's since been removed from the registry), so editing
    // an older transaction never leaves it with nothing selected.
    List<String> banksFor(AppProvider p, String? current) => {
          ..._allBanks(p),
          if (current != null && current.isNotEmpty) current,
        }.toList();
    List<String> walletsFor(AppProvider p, String? current) => {
          ..._allWallets(p),
          if (current != null && current.isNotEmpty) current,
        }.toList();

    // 'Cash' | 'Bank' | 'Wallet' — for cashIn/cashOut this only ever toggles
    // between Cash/Bank (the funding side); for topUp/withdraw it can be any
    // of the three (the account being adjusted).
    String accountKindChoice;
    String? bankChoice =
        _allBanks(prov).isNotEmpty ? _allBanks(prov).first : null;
    String walletChoice = 'GCash';

    if (existing == null) {
      accountKindChoice = 'Cash';
      if (prefillProvider != null && prefillProvider.isNotEmpty) {
        walletChoice = prefillProvider;
      }
    } else if (isInOutInitial) {
      accountKindChoice = existing.liquidAccount == CicoTransaction.cashAccount
          ? 'Cash'
          : 'Bank';
      if (accountKindChoice == 'Bank') bankChoice = existing.liquidAccount;
      walletChoice = existing.provider;
    } else {
      accountKindChoice = switch (existing.accountKind) {
        CicoAccountKind.cash => 'Cash',
        CicoAccountKind.bank => 'Bank',
        CicoAccountKind.wallet => 'Wallet',
      };
      if (accountKindChoice == 'Bank') bankChoice = existing.provider;
      if (accountKindChoice == 'Wallet') walletChoice = existing.provider;
    }

    // topUp/withdraw only: the other side of the transfer, if any.
    // 'None' | 'Cash' | 'Bank' | 'Wallet'. Defaults to 'Cash' for new entries
    // since funding/receiving with cash from the drawer is the common case;
    // existing rows with no transferAccount recorded default to 'None' so
    // editing one doesn't invent a second side that was never there.
    String transferKind = 'Cash';
    String? transferBank =
        _allBanks(prov).isNotEmpty ? _allBanks(prov).first : null;
    String transferWallet = 'GCash';
    if (existing != null && !isInOutInitial) {
      final ta = existing.transferAccount;
      if (ta == null) {
        transferKind = 'None';
      } else if (ta == CicoTransaction.cashAccount) {
        transferKind = 'Cash';
      } else if (_allBanks(prov).contains(ta)) {
        transferKind = 'Bank';
        transferBank = ta;
      } else {
        transferKind = 'Wallet';
        transferWallet = ta;
      }
    }

    final amountCtrl = TextEditingController(
        text: existing != null
            ? existing.amount.toStringAsFixed(2)
            : (prefillAmount != null && prefillAmount > 0
                ? prefillAmount.toStringAsFixed(2)
                : ''));
    final commissionCtrl = TextEditingController(
        text: existing != null && existing.commission > 0
            ? existing.commission.toStringAsFixed(2)
            : '');
    // Auto-fill only ever kicks in while this stays true — flips to false
    // for good the moment the user types into the commission field
    // themselves, so a configured rate never clobbers a manual entry. Only
    // ever starts true for a brand-new transaction — never when editing an
    // existing one (even one with commission == 0), since rates can change
    // after the fact and silently rewriting a saved historical record's
    // commission just because it was reopened to fix an unrelated field
    // (e.g. a typo in notes) would be a real data-integrity surprise.
    bool commissionAutoFilled = existing == null;
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final customerNameCtrl =
        TextEditingController(text: existing?.customerName ?? '');
    final customerPhoneCtrl =
        TextEditingController(text: existing?.customerPhone ?? '');
    DateTime txnDate = existing?.createdAt ?? DateTime.now();

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(top: false, child: StatefulBuilder(
        builder: (ctx, setS) {
          final isInOut = type == CicoType.cashIn || type == CicoType.cashOut;
          final banks = banksFor(prov, bankChoice);
          final wallets = walletsFor(prov, walletChoice);
          final resolvedWallet = walletChoice;
          final resolvedBank = bankChoice ?? '';
          final resolvedLiquidAccount = isInOut
              ? (accountKindChoice == 'Bank'
                  ? resolvedBank
                  : CicoTransaction.cashAccount)
              : CicoTransaction.cashAccount;
          final resolvedAccountKind = switch (accountKindChoice) {
            'Cash' => CicoAccountKind.cash,
            'Bank' => CicoAccountKind.bank,
            _ => CicoAccountKind.wallet,
          };
          final resolvedTarget = accountKindChoice == 'Bank'
              ? resolvedBank
              : (accountKindChoice == 'Wallet' ? resolvedWallet : '');
          final resolvedTransferAccount = isInOut || transferKind == 'None'
              ? null
              : (transferKind == 'Cash'
                  ? CicoTransaction.cashAccount
                  : transferKind == 'Bank'
                      ? transferBank
                      : transferWallet);
          final amount = double.tryParse(amountCtrl.text) ?? 0;

          // Auto-fill the commission from a configured rate tier, but only
          // ever while the field hasn't been touched by hand — see the
          // commissionAutoFilled comment above.
          final matchedRate = isInOut && amount > 0
              ? prov.resolveRate(
                  type: type, provider: resolvedWallet, amount: amount)
              : null;
          if (isInOut && commissionAutoFilled) {
            final autoText = matchedRate != null
                ? matchedRate.commissionFor(amount).toStringAsFixed(2)
                : '';
            if (commissionCtrl.text != autoText) {
              commissionCtrl.text = autoText;
            }
          }
          final showAutoFillHint =
              isInOut && commissionAutoFilled && matchedRate != null;

          final warning = _floatWarning(prov, type,
              wallet: resolvedWallet,
              liquidAccount: resolvedLiquidAccount,
              accountKind: resolvedAccountKind,
              targetAccount: resolvedTarget,
              transferAccount: resolvedTransferAccount,
              amount: amount);
          final showsCommission = isInOut;
          final meta = _typeMeta[type]!;
          final rateLadderTiers = isInOut
              ? prov.rateTiersFor(provider: resolvedWallet, type: type)
              : <CicoRateRule>[];
          // cashIn: this account receives the customer's cash. cashOut: this
          // account pays it out. Same picker, but the label now says which.
          final fundedViaLabel =
              type == CicoType.cashIn ? 'Received Into' : 'Paid From';
          final fundedViaHint = type == CicoType.cashIn
              ? "Cash or bank where you received the customer's payment."
              : 'Cash or bank you paid the customer from.';
          final walletSideHint = type == CicoType.cashIn
              ? 'Which of your e-wallets you sent the e-money from.'
              : "Which of your e-wallets received the customer's e-money.";

          Widget namedChip(
              String label, bool selected, Color color, VoidCallback onTap) {
            return GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? color : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected ? Colors.white : Colors.grey[600])),
              ),
            );
          }

          Widget accountChip(
              String name, bool selected, Color color, VoidCallback onTap) {
            final hasBrand = _brandAssetFor(name) != null;
            return GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? color : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasBrand) ...[
                      _brandBadge(name, size: 20),
                      const SizedBox(width: 6),
                    ],
                    Text(name,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.normal,
                            color: selected ? Colors.white : Colors.grey[600])),
                  ],
                ),
              ),
            );
          }

          Widget sectionLabel(String text) => Align(
                alignment: Alignment.centerLeft,
                child: Text(text,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600)),
              );

          Widget hintRow(String text) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 13, color: Colors.grey[400]),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(text,
                          style: TextStyle(
                              fontSize: 10.5, color: Colors.grey[500])),
                    ),
                  ],
                ),
              );

          Widget rateLadderCard() {
            if (rateLadderTiers.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: RateLadderCard(
                tiers: rateLadderTiers,
                matched: matchedRate,
                color: meta.color,
                amount: amount,
                commission: double.tryParse(commissionCtrl.text) ?? 0,
              ),
            );
          }

          Widget fundedViaPicker() => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  namedChip(
                      'Cash',
                      accountKindChoice == 'Cash',
                      AppColors.green,
                      () => setS(() => accountKindChoice = 'Cash')),
                  for (final b in banks)
                    accountChip(
                        b,
                        accountKindChoice == 'Bank' && bankChoice == b,
                        _bankColor,
                        () => setS(() {
                              accountKindChoice = 'Bank';
                              bankChoice = b;
                            })),
                ],
              );

          Widget targetAccountPicker() => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  namedChip(
                      'Cash Float',
                      accountKindChoice == 'Cash',
                      AppColors.green,
                      () => setS(() {
                            accountKindChoice = 'Cash';
                            if (transferKind == 'Cash') transferKind = 'None';
                          })),
                  for (final b in banks)
                    accountChip(
                        b,
                        accountKindChoice == 'Bank' && bankChoice == b,
                        _bankColor,
                        () => setS(() {
                              accountKindChoice = 'Bank';
                              bankChoice = b;
                              if (transferKind == 'Bank' && transferBank == b) {
                                transferKind = 'None';
                              }
                            })),
                  for (final w in wallets)
                    accountChip(
                        w,
                        accountKindChoice == 'Wallet' && walletChoice == w,
                        _walletColor(w),
                        () => setS(() {
                              accountKindChoice = 'Wallet';
                              walletChoice = w;
                              if (transferKind == 'Wallet' &&
                                  transferWallet == w) {
                                transferKind = 'None';
                              }
                            })),
                ],
              );

          // topUp/withdraw only: the other side of the transfer — where the
          // top-up money came from, or where withdrawn money went. Excludes
          // whichever account is currently selected as the target above, so
          // an account can't fund/receive itself.
          final transferTargetName = accountKindChoice == 'Cash'
              ? CicoTransaction.cashAccount
              : resolvedTarget;
          Widget transferAccountPicker() => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  namedChip(
                      'None',
                      transferKind == 'None',
                      Colors.grey.shade400,
                      () => setS(() => transferKind = 'None')),
                  if (transferTargetName != CicoTransaction.cashAccount)
                    namedChip('Cash', transferKind == 'Cash', AppColors.green,
                        () => setS(() => transferKind = 'Cash')),
                  for (final b in banks)
                    if (b != transferTargetName)
                      accountChip(
                          b,
                          transferKind == 'Bank' && transferBank == b,
                          _bankColor,
                          () => setS(() {
                                transferKind = 'Bank';
                                transferBank = b;
                              })),
                  for (final w in wallets)
                    if (w != transferTargetName)
                      accountChip(
                          w,
                          transferKind == 'Wallet' && transferWallet == w,
                          _walletColor(w),
                          () => setS(() {
                                transferKind = 'Wallet';
                                transferWallet = w;
                              })),
                ],
              );

          Widget walletPicker() => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final w in wallets)
                    accountChip(w, walletChoice == w, _walletColor(w),
                        () => setS(() => walletChoice = w)),
                ],
              );

          final media = MediaQuery.of(ctx);
          final availableHeight = media.size.height - media.viewInsets.bottom;
          return Padding(
            // Only the keyboard inset — the footer Save button below has
            // its own SafeArea(top: false) already reserving space for the
            // system gesture/nav bar, so adding it here too would double it.
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: availableHeight * 0.88),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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
                          existing == null
                              ? 'Add Transaction'
                              : 'Edit Transaction',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87),
                        ),
                        const SizedBox(height: 16),

                        // Type chips — Cash In/Cash Out only for anything
                        // new; an existing Top Up/Withdraw entry keeps its
                        // own type selectable too so editing it (e.g. a
                        // typo in notes) doesn't force a type change.
                        sectionLabel('Type'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ..._recordableTypes,
                            if (existing != null &&
                                (existing.type == CicoType.topUp ||
                                    existing.type == CicoType.withdraw))
                              existing.type,
                          ].map((t) {
                            final sel = type == t;
                            final meta = _typeMeta[t]!;
                            return GestureDetector(
                              onTap: () => setS(() {
                                type = t;
                                final newIsInOut = type == CicoType.cashIn ||
                                    type == CicoType.cashOut;
                                if (newIsInOut &&
                                    accountKindChoice == 'Wallet') {
                                  accountKindChoice = 'Cash';
                                }
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color:
                                      sel ? meta.color : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(meta.label,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: sel
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: sel
                                            ? Colors.white
                                            : Colors.grey[600])),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        if (isInOut) ...[
                          sectionLabel(fundedViaLabel),
                          hintRow(fundedViaHint),
                          const SizedBox(height: 8),
                          fundedViaPicker(),
                          const SizedBox(height: 16),
                          sectionLabel('E-Wallet'),
                          hintRow(walletSideHint),
                          const SizedBox(height: 8),
                          walletPicker(),
                        ] else ...[
                          sectionLabel('Target Account'),
                          const SizedBox(height: 8),
                          targetAccountPicker(),
                          const SizedBox(height: 16),
                          sectionLabel(type == CicoType.topUp
                              ? 'Funded From (optional)'
                              : 'Sent To (optional)'),
                          const SizedBox(height: 8),
                          transferAccountPicker(),
                        ],
                        const SizedBox(height: 12),

                        TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setS(() {}),
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Amount *',
                            labelStyle: TextStyle(
                                color: Colors.grey[600], fontSize: 13),
                            prefixText: '₱ ',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300)),
                          ),
                        ),

                        if (warning != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color:
                                      AppColors.amber.withValues(alpha: 0.3)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 16, color: AppColors.amber),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(warning,
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey[700])),
                              ),
                            ]),
                          ),
                        ],

                        rateLadderCard(),

                        if (showsCommission) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: commissionCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) =>
                                setS(() => commissionAutoFilled = false),
                            decoration: InputDecoration(
                              labelText: 'Commission earned (optional)',
                              labelStyle: TextStyle(
                                  color: Colors.grey[600], fontSize: 13),
                              prefixText: '₱ ',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(children: [
                            Icon(
                                showAutoFillHint
                                    ? Icons.check_circle_outline
                                    : Icons.info_outline,
                                size: 13,
                                color: showAutoFillHint
                                    ? AppColors.green
                                    : Colors.grey[400]),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                  showAutoFillHint
                                      ? 'Auto-filled from your $resolvedWallet rate — edit it if this transaction is different.'
                                      : _rateHint(type, resolvedWallet),
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      color: showAutoFillHint
                                          ? AppColors.green
                                          : Colors.grey[500])),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          sectionLabel('Customer (optional)'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: customerNameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Customer name',
                              labelStyle: TextStyle(
                                  color: Colors.grey[600], fontSize: 13),
                              prefixIcon: Icon(Icons.person_outline,
                                  size: 18, color: Colors.grey[500]),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: customerPhoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Customer number',
                              labelStyle: TextStyle(
                                  color: Colors.grey[600], fontSize: 13),
                              prefixIcon: Icon(Icons.phone_outlined,
                                  size: 18, color: Colors.grey[500]),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300)),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),

                        TextField(
                          controller: notesCtrl,
                          decoration: InputDecoration(
                            labelText: 'Notes (optional)',
                            labelStyle: TextStyle(
                                color: Colors.grey[600], fontSize: 13),
                            prefixIcon: Icon(Icons.notes_outlined,
                                size: 18, color: Colors.grey[500]),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Date picker
                        GestureDetector(
                          onTap: () async {
                            final firstDate = DateTime.now()
                                .subtract(const Duration(days: 365));
                            final lastDate = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: txnDate.isBefore(firstDate)
                                  ? firstDate
                                  : (txnDate.isAfter(lastDate)
                                      ? lastDate
                                      : txnDate),
                              firstDate: firstDate,
                              lastDate: lastDate,
                            );
                            if (picked != null) {
                              // showDatePicker returns midnight for the
                              // chosen date — keep the time-of-day already
                              // on txnDate instead of losing it.
                              setS(() => txnDate = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  txnDate.hour,
                                  txnDate.minute,
                                  txnDate.second));
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: txnDate.day != DateTime.now().day
                                    ? _indigo
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 18,
                                  color: txnDate.day != DateTime.now().day
                                      ? _indigo
                                      : Colors.grey[500]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  txnDate.day == DateTime.now().day &&
                                          txnDate.month ==
                                              DateTime.now().month &&
                                          txnDate.year == DateTime.now().year
                                      ? 'Today — ${DateHelper.formatDate(txnDate)}'
                                      : 'Past Date — ${DateHelper.formatDate(txnDate)}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: txnDate.day != DateTime.now().day
                                          ? _indigo
                                          : Colors.black87),
                                ),
                              ),
                              if (txnDate.day != DateTime.now().day)
                                GestureDetector(
                                  onTap: () =>
                                      setS(() => txnDate = DateTime.now()),
                                  child: Icon(Icons.close,
                                      size: 16, color: Colors.grey[400]),
                                ),
                            ]),
                          ),
                        ),
                      ])),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border:
                        Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (accountKindChoice == 'Bank' &&
                              (bankChoice == null || bankChoice!.isEmpty)) {
                            CenterToast.showError(context,
                                'Add a bank account first from the main screen.');
                            return;
                          }
                          final parsedAmount = double.tryParse(amountCtrl.text);
                          if (parsedAmount == null || parsedAmount <= 0) {
                            CenterToast.showError(
                                context, 'Enter a valid amount.');
                            return;
                          }
                          final commission = showsCommission
                              ? (double.tryParse(commissionCtrl.text) ?? 0)
                              : 0.0;

                          final finalProvider = isInOut
                              ? resolvedWallet
                              : (accountKindChoice == 'Cash'
                                  ? CicoTransaction.cashAccount
                                  : resolvedTarget);
                          final finalLiquidAccount = resolvedLiquidAccount;
                          final finalAccountKind = resolvedAccountKind;
                          final finalTransferAccount = resolvedTransferAccount;
                          final customerName =
                              isInOut && customerNameCtrl.text.trim().isNotEmpty
                                  ? customerNameCtrl.text.trim()
                                  : null;
                          final customerPhone = isInOut &&
                                  customerPhoneCtrl.text.trim().isNotEmpty
                              ? customerPhoneCtrl.text.trim()
                              : null;

                          if (finalTransferAccount != null &&
                              finalTransferAccount == finalProvider) {
                            CenterToast.showError(context,
                                "Pick a different account — it can't fund or receive itself.");
                            return;
                          }

                          if (existing == null) {
                            await prov.addCicoTransaction(
                              type: type,
                              provider: finalProvider,
                              amount: parsedAmount,
                              commission: commission,
                              notes: notesCtrl.text.isEmpty
                                  ? null
                                  : notesCtrl.text,
                              date: txnDate,
                              liquidAccount: finalLiquidAccount,
                              accountKind: finalAccountKind,
                              customerName: customerName,
                              customerPhone: customerPhone,
                              transferAccount: finalTransferAccount,
                            );
                          } else {
                            await prov.updateCicoTransaction(CicoTransaction(
                              id: existing.id,
                              type: type,
                              provider: finalProvider,
                              amount: parsedAmount,
                              commission: commission,
                              createdAt: txnDate,
                              notes: notesCtrl.text.isEmpty
                                  ? null
                                  : notesCtrl.text,
                              liquidAccount: finalLiquidAccount,
                              accountKind: finalAccountKind,
                              customerName: customerName,
                              customerPhone: customerPhone,
                              transferAccount: finalTransferAccount,
                            ));
                          }
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            CenterToast.showSuccess(
                                context,
                                existing == null
                                    ? 'Transaction added!'
                                    : 'Transaction updated!');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _indigo,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          existing == null
                              ? 'Save Transaction'
                              : 'Update Transaction',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          );
        },
      )),
    );
  }

  void _confirmDelete(
      BuildContext context, AppProvider prov, CicoTransaction txn) {
    final meta = _typeMeta[txn.type]!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Transaction?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${meta.label} • ${_providerLabel(txn.provider)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87)),
              const SizedBox(height: 4),
              Text(CurrencyFormatter.format(txn.amount),
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
              await prov.deleteCicoTransaction(txn.id);
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

// ── Transaction Tile ──────────────────────────────────────────────
class _CicoTile extends StatelessWidget {
  final CicoTransaction txn;
  final VoidCallback onView;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _CicoTile({
    required this.txn,
    required this.onView,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _typeMeta[txn.type]!;
    final isInOut = txn.type == CicoType.cashIn || txn.type == CicoType.cashOut;
    final fundedViaBank =
        isInOut && txn.liquidAccount != CicoTransaction.cashAccount;
    final hasCustomerName =
        isInOut && txn.customerName != null && txn.customerName!.isNotEmpty;
    final hasCustomerPhone =
        isInOut && txn.customerPhone != null && txn.customerPhone!.isNotEmpty;
    final customerBit = hasCustomerName && hasCustomerPhone
        ? ' • ${txn.customerName} (${txn.customerPhone})'
        : hasCustomerName
            ? ' • ${txn.customerName}'
            : hasCustomerPhone
                ? ' • ${txn.customerPhone}'
                : '';
    final transferBit = txn.transferAccount == null
        ? ''
        : txn.type == CicoType.topUp
            ? ' • from ${txn.transferAccount}'
            : txn.type == CicoType.withdraw
                ? ' • to ${txn.transferAccount}'
                : '';
    final fundedViaBit = fundedViaBank
        ? (txn.type == CicoType.cashIn
            ? ' • received into ${txn.liquidAccount}'
            : ' • paid from ${txn.liquidAccount}')
        : '';

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
            onTap: onView,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: meta.color.withValues(alpha: 0.15))),
              child: Icon(meta.icon, color: meta.color, size: 18),
            ),
            title: Text('${meta.label} • ${_providerLabel(txn.provider)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black87)),
            subtitle: Text(
                '${DateHelper.formatDateTime(txn.createdAt)}'
                '$fundedViaBit'
                '$transferBit'
                '$customerBit'
                '${txn.notes != null && txn.notes!.isNotEmpty ? '\n${txn.notes}' : ''}',
                style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(CurrencyFormatter.format(txn.amount),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontSize: 14)),
                  if (txn.commission > 0)
                    Text('+${CurrencyFormatter.format(txn.commission)} comm.',
                        style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                ],
              ),
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
