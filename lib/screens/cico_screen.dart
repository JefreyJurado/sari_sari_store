import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';
import '../models/cico_transaction.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/center_toast.dart';
import '../widgets/help_sheet.dart';

const _indigo = Color(0xFF4F46E5);
// Fallback colors for accounts with no official logo asset below.
const _gcashBlue = Color(0xFF0072CE);
const _mayaGreen = Color(0xFF1DB58C);
const _bankColor = AppColors.purple;
const _accountNumbersPrefKey = 'cico_account_numbers';
const _registeredBanksPrefKey = 'cico_registered_banks';
const _registeredWalletsPrefKey = 'cico_registered_wallets';

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

class _TypeMeta {
  final String label;
  final IconData icon;
  final Color color;
  final String description;
  const _TypeMeta(this.label, this.icon, this.color, this.description);
}

const _typeMeta = {
  CicoType.cashIn: _TypeMeta('Cash In', Icons.south_west_rounded,
      AppColors.green, 'Customer gives you cash, you send them e-money'),
  CicoType.cashOut: _TypeMeta('Cash Out', Icons.north_east_rounded,
      AppColors.orange, 'Customer sends you e-money, you give them cash'),
  CicoType.topUp: _TypeMeta('Top Up', Icons.add_circle_outline, _indigo,
      'Add money into one of your own accounts'),
  CicoType.withdraw: _TypeMeta('Withdraw', Icons.remove_circle_outline,
      AppColors.red, 'Take money out of one of your own accounts'),
};

const _filterLabels = ['All', 'Cash In', 'Cash Out', 'Top Up', 'Withdraw'];

CicoType? _typeForFilter(String label) => switch (label) {
      'Cash In' => CicoType.cashIn,
      'Cash Out' => CicoType.cashOut,
      'Top Up' => CicoType.topUp,
      'Withdraw' => CicoType.withdraw,
      _ => null,
    };

String _providerLabel(String provider) =>
    provider == CicoTransaction.cashAccount ? 'Cash Float' : provider;

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
  const CicoScreen({super.key});
  @override
  State<CicoScreen> createState() => _CicoScreenState();
}

class _CicoScreenState extends State<CicoScreen> {
  String _filter = 'All';
  Map<String, String> _accountNumbers = {};
  Set<String> _registeredBanks = {};
  Set<String> _registeredWallets = {};

  @override
  void initState() {
    super.initState();
    _loadAccountNumbers();
    _loadRegisteredAccounts();
  }

  Future<void> _loadAccountNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountNumbersPrefKey);
    if (raw == null) return;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    if (mounted) {
      setState(() => _accountNumbers = decoded.cast<String, String>());
    }
  }

  Future<void> _loadRegisteredAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final banks = prefs.getStringList(_registeredBanksPrefKey) ?? [];
    final wallets = prefs.getStringList(_registeredWalletsPrefKey) ?? [];
    if (mounted) {
      setState(() {
        _registeredBanks = banks.toSet();
        _registeredWallets = wallets.toSet();
      });
    }
  }

  Future<void> _registerAccount(String name, {required bool isBank}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = isBank ? _registeredBanksPrefKey : _registeredWalletsPrefKey;
    final updated = {...(isBank ? _registeredBanks : _registeredWallets), name};
    await prefs.setStringList(key, updated.toList());
    if (mounted) {
      setState(() {
        if (isBank) {
          _registeredBanks = updated;
        } else {
          _registeredWallets = updated;
        }
      });
    }
  }

  Future<void> _removeRegisteredAccount(String name,
      {required bool isBank}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = isBank ? _registeredBanksPrefKey : _registeredWalletsPrefKey;
    final updated = {...(isBank ? _registeredBanks : _registeredWallets)}
      ..remove(name);
    await prefs.setStringList(key, updated.toList());
    if (mounted) {
      setState(() {
        if (isBank) {
          _registeredBanks = updated;
        } else {
          _registeredWallets = updated;
        }
      });
    }
  }

  void _addAccountDialog(AppProvider prov) {
    bool isBank = true;
    final nameCtrl = TextEditingController();
    final numberCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dCtx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          scrollable: true,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Add Account',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 8, children: [
                GestureDetector(
                  onTap: () => setD(() => isBank = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isBank ? _bankColor : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Bank',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isBank ? FontWeight.w600 : FontWeight.normal,
                            color: isBank ? Colors.white : Colors.grey[600])),
                  ),
                ),
                GestureDetector(
                  onTap: () => setD(() => isBank = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: !isBank ? _indigo : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('E-Wallet',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                !isBank ? FontWeight.w600 : FontWeight.normal,
                            color: !isBank ? Colors.white : Colors.grey[600])),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: isBank ? 'Bank name *' : 'Wallet name *',
                  hintText: isBank
                      ? 'e.g. BDO, BPI'
                      : 'e.g. GCash 2, Maya (Business)',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                  labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: numberCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Mobile/account number (optional)',
                  labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text('Cancel',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13))),
            TextButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  CenterToast.showError(context, 'Account name required.');
                  return;
                }
                await _registerAccount(name, isBank: isBank);
                if (numberCtrl.text.trim().isNotEmpty) {
                  await _saveAccountNumber(name, numberCtrl.text);
                }
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              },
              child: const Text('Add',
                  style: TextStyle(
                      color: _indigo,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAccountNumber(String account, String number) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = {..._accountNumbers};
    if (number.trim().isEmpty) {
      updated.remove(account);
    } else {
      updated[account] = number.trim();
    }
    await prefs.setString(_accountNumbersPrefKey, jsonEncode(updated));
    if (mounted) setState(() => _accountNumbers = updated);
  }

  void _editAccountNumber(AppProvider prov, String account,
      {required bool isBank}) {
    final ctrl = TextEditingController(text: _accountNumbers[account] ?? '');
    // "Remove" is only meaningful for accounts you explicitly registered —
    // GCash/Maya are permanent presets, and anything else only exists here
    // because it's in _registeredBanks/_registeredWallets in the first place.
    final hasHistory = isBank
        ? prov.cicoKnownBanks.contains(account)
        : prov.cicoKnownProviders.contains(account);
    final canRemove =
        (isBank ? _registeredBanks : _registeredWallets).contains(account);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('$account Number',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Mobile/account number',
                labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
            if (canRemove && hasHistory) ...[
              const SizedBox(height: 10),
              Text(
                "This account has past transactions, so it'll keep appearing "
                'in your history and balances until those are deleted too.',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
        actions: [
          if (canRemove)
            TextButton(
              onPressed: () async {
                await _removeRegisteredAccount(account, isBank: isBank);
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              },
              child: const Text('Remove',
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          TextButton(
            onPressed: () async {
              await _saveAccountNumber(account, ctrl.text);
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text('Save',
                style: TextStyle(
                    color: _indigo, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, prov, _) {
      final filterType = _typeForFilter(_filter);
      final transactions = filterType == null
          ? prov.cico
          : prov.cico.where((t) => t.type == filterType).toList();

      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Cash In-Cash Out',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87)),
          actions: const [
            HelpIconButton(
              title: 'Cash In-Cash Out (E-Wallet)',
              points: [
                'Use this to track your GCash/Maya agent side-business: cash-in sends e-money to a customer for cash they hand you; cash-out gives a customer cash for e-money they send you.',
                'Cash In raises your Cash Float and lowers the wallet you sent from. Cash Out does the opposite.',
                "If a customer's cash-in/out was funded via bank transfer instead of physical cash, tap the bank directly under \"Received Into\" (Cash In) or \"Paid From\" (Cash Out) — each shows its registered number so you can confirm you picked the right one.",
                'Tap the "Add Account" tile at the end of the balance row to register a new bank or e-wallet before it shows up here as an option — with an optional number too.',
                'Need more than one GCash or Maya (e.g. a personal and a business number)? Register it from "Add Account" with its own name, like "GCash 2" — it gets tracked separately from the start.',
                'Top Up and Withdraw are for rebalancing — moving cash, bank funds, or e-wallet balance between your own accounts, separate from a customer transaction. Pick a "Funded From" (Top Up) or "Sent To" (Withdraw) account to have both sides update together; leave it as "None" to just adjust one account on its own.',
                'Tap any GCash/Maya/bank balance card to add or edit the actual mobile/account number for your reference — a "Remove" option there lets you delete an account you registered by mistake or no longer use.',
                'Cash In/Out entries can also record the customer\'s name and number for your own recordkeeping — both are optional.',
                "Commission earned per transaction is tracked on its own and doesn't affect the float balances — it's just a running total of what you've earned.",
                "If an amount would push a float negative, you'll see a warning, but you can still save it — you may be topping up right after.",
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

            // ── Balance summary ─────────────────────
            // Tall enough for the 4th line (account number) plus the
            // taller 26px brand-logo badge (vs. the plain 18px icon) that
            // some cards show instead of the generic icon.
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _balanceCard('Cash Float', prov.cicoCashFloatBalance,
                      Icons.payments_outlined, AppColors.green, null),
                  for (final b in _allBanks(prov))
                    _balanceCard(
                        b,
                        prov.cicoBankBalance(b),
                        Icons.account_balance_outlined,
                        _bankColor,
                        () => _editAccountNumber(prov, b, isBank: true)),
                  for (final p in _allWallets(prov))
                    _balanceCard(
                        p,
                        prov.cicoWalletBalance(p),
                        Icons.account_balance_wallet_outlined,
                        _walletColor(p),
                        () => _editAccountNumber(prov, p, isBank: false)),
                  _addAccountCard(prov),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Icon(Icons.percent_rounded, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                    'Commission earned (all time): '
                    '${CurrencyFormatter.format(prov.cicoTotalCommission)}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ]),
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

  List<String> _allBanks(AppProvider prov) =>
      {..._registeredBanks, ...prov.cicoKnownBanks}.toList();

  List<String> _allWallets(AppProvider prov) =>
      {...prov.cicoKnownProviders, ..._registeredWallets}.toList();

  Widget _addAccountCard(AppProvider prov) {
    return GestureDetector(
      onTap: () => _addAccountDialog(prov),
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: Colors.grey.shade300,
              width: 1.5,
              style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: Colors.grey[400], size: 24),
            const SizedBox(height: 6),
            Text('Add\nAccount',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _balanceCard(String label, double value, IconData icon, Color color,
      VoidCallback? onTap) {
    final number = _accountNumbers[label];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, Color.lerp(color, Colors.black, 0.25)!],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.colored(color),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _brandAssetFor(label) != null
                ? _brandBadge(label, size: 26)
                : Icon(icon,
                    color: Colors.white.withValues(alpha: 0.85), size: 18),
            const SizedBox(height: 8),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(CurrencyFormatter.format(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            if (number != null) ...[
              const SizedBox(height: 1),
              Text(number,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 9.5)),
            ],
          ],
        ),
      ),
    );
  }

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
      case CicoType.cashIn:
        final bal = prov.cicoWalletBalance(wallet);
        if (amount > bal) {
          return 'This exceeds your $wallet e-wallet balance '
              '(${CurrencyFormatter.format(bal)}). You can still save, '
              'but the balance will go negative.';
        }
        return null;
      case CicoType.cashOut:
        final isBank = liquidAccount != CicoTransaction.cashAccount;
        final bal = isBank
            ? prov.cicoBankBalance(liquidAccount)
            : prov.cicoCashFloatBalance;
        final label = isBank ? '$liquidAccount balance' : 'cash float';
        if (amount > bal) {
          return 'This exceeds your current $label '
              '(${CurrencyFormatter.format(bal)}). You can still save, '
              'but it will go negative.';
        }
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
              row('Date', DateHelper.formatDate(txn.createdAt)),
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
              for (final t in CicoType.values) ...[
                _typeChoiceTile(sheetCtx, context, prov, t),
                if (t != CicoType.values.last) const SizedBox(height: 10),
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

  void _showForm(
      BuildContext context, AppProvider prov, CicoTransaction? existing,
      {CicoType? initialType}) {
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
        text: existing != null ? existing.amount.toStringAsFixed(2) : '');
    final commissionCtrl = TextEditingController(
        text: existing != null && existing.commission > 0
            ? existing.commission.toStringAsFixed(2)
            : '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final customerNameCtrl =
        TextEditingController(text: existing?.customerName ?? '');
    final customerPhoneCtrl =
        TextEditingController(text: existing?.customerPhone ?? '');
    DateTime txnDate = existing?.createdAt ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
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
          final warning = _floatWarning(prov, type,
              wallet: resolvedWallet,
              liquidAccount: resolvedLiquidAccount,
              accountKind: resolvedAccountKind,
              targetAccount: resolvedTarget,
              transferAccount: resolvedTransferAccount,
              amount: amount);
          final showsCommission = isInOut;
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

          // Shows the registered number under the name (when saved via the
          // main screen's "Add Account"/balance-card tap), so you can
          // confirm you're picking the right account at a glance.
          Widget accountChip(
              String name, bool selected, Color color, VoidCallback onTap) {
            final number = _accountNumbers[name];
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
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: selected
                                    ? Colors.white
                                    : Colors.grey[600])),
                        if (number != null && number.isNotEmpty)
                          Text(number,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: selected
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : Colors.grey[500])),
                      ],
                    ),
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

                        // Type chips
                        sectionLabel('Type'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: CicoType.values.map((t) {
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

                        if (showsCommission) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: commissionCtrl,
                            keyboardType: TextInputType.number,
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
                            Icon(Icons.info_outline,
                                size: 13, color: Colors.grey[400]),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(_rateHint(type, resolvedWallet),
                                  style: TextStyle(
                                      fontSize: 10.5, color: Colors.grey[500])),
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
                              setS(() => txnDate = picked);
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
      ),
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
                '${DateHelper.formatDate(txn.createdAt)}'
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
