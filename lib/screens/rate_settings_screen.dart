import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_provider.dart';
import '../models/cico_transaction.dart';
import '../models/cico_rate.dart';
import '../utils/currency_formatter.dart';
import '../theme/app_theme.dart';
import '../widgets/center_toast.dart';
import '../widgets/help_sheet.dart';

const _uuid = Uuid();
const _indigo = Color(0xFF4F46E5);
// Same key cico_screen.dart writes to via its "Add Account" flow — read
// here too so a wallet registered there but never yet transacted (so it's
// absent from AppProvider.cicoKnownProviders) still shows up as a rate
// target instead of silently being unselectable.
const _registeredWalletsPrefKey = 'cico_registered_wallets';

String _rangeLabel(CicoRateRule r) => r.maxAmount == null
    ? '${CurrencyFormatter.format(r.minAmount)}+'
    : '${CurrencyFormatter.format(r.minAmount)} – '
        '${CurrencyFormatter.format(r.maxAmount!)}';

String _feeLabel(CicoRateRule r) => r.mode == CicoRateMode.fixed
    ? '${CurrencyFormatter.format(r.value)} flat'
    : '${r.value.toStringAsFixed(r.value == r.value.roundToDouble() ? 0 : 1)}%';

class RateSettingsScreen extends StatefulWidget {
  const RateSettingsScreen({super.key});
  @override
  State<RateSettingsScreen> createState() => _RateSettingsScreenState();
}

class _RateSettingsScreenState extends State<RateSettingsScreen> {
  Set<String> _registeredWallets = {};

  @override
  void initState() {
    super.initState();
    _loadRegisteredWallets();
  }

  Future<void> _loadRegisteredWallets() async {
    final prefs = await SharedPreferences.getInstance();
    final wallets = prefs.getStringList(_registeredWalletsPrefKey) ?? [];
    if (mounted) setState(() => _registeredWallets = wallets.toSet());
  }

  List<String> _allProviders(AppProvider prov) => {
        ...CicoTransaction.presetProviders,
        ...prov.cicoKnownProviders,
        ..._registeredWallets,
      }.toList();

  // Non-blocking, same spirit as the float warnings on the CICO screen —
  // flags an overlapping tier for the same provider+direction but never
  // stops the save, since a deliberate overlap (e.g. temporarily testing a
  // new tier) is the store owner's call, not this screen's.
  bool _overlaps(AppProvider prov, {
    required String provider,
    required CicoType type,
    required double min,
    required double? max,
    String? excludeId,
  }) {
    for (final r in prov.rates) {
      if (r.id == excludeId) continue;
      if (r.provider != provider || r.txnType != type) continue;
      final rMax = r.maxAmount ?? double.infinity;
      final newMax = max ?? double.infinity;
      if (min <= rMax && r.minAmount <= newMax) return true;
    }
    return false;
  }

  Future<void> _confirmDelete(AppProvider prov, CicoRateRule rule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete this rate?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        content: const Text('This cannot be undone.',
            style: TextStyle(fontSize: 13, color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await prov.deleteRateRule(rule.id);
    if (mounted) CenterToast.showWarning(context, 'Rate deleted.');
  }

  void _showForm(AppProvider prov, {CicoRateRule? existing}) {
    final providers = _allProviders(prov);
    String provider = existing?.provider ?? providers.first;
    // "Both" only ever applies when adding a brand-new rule — editing an
    // existing row always edits that exact direction, so there's never
    // ambiguity about which paired row (if any) is meant.
    String direction = existing == null
        ? 'Both'
        : existing.txnType == CicoType.cashIn
            ? 'Cash In'
            : 'Cash Out';
    CicoRateMode mode = existing?.mode ?? CicoRateMode.fixed;
    bool isActive = existing?.isActive ?? true;
    final valueCtrl = TextEditingController(
        text: existing != null ? existing.value.toString() : '');
    final minCtrl = TextEditingController(
        text: existing != null ? existing.minAmount.toString() : '0');
    final maxCtrl = TextEditingController(
        text: existing?.maxAmount != null ? existing!.maxAmount.toString() : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          final value = double.tryParse(valueCtrl.text) ?? 0;
          final min = double.tryParse(minCtrl.text) ?? 0;
          final max = maxCtrl.text.trim().isEmpty
              ? null
              : double.tryParse(maxCtrl.text);

          final directionsToCheck = direction == 'Both'
              ? [CicoType.cashIn, CicoType.cashOut]
              : [direction == 'Cash In' ? CicoType.cashIn : CicoType.cashOut];
          final overlapWarning = directionsToCheck.any((t) => _overlaps(
                prov,
                provider: provider,
                type: t,
                min: min,
                max: max,
                excludeId: existing?.id,
              ));

          Widget chip(String label, bool selected, VoidCallback onTap) =>
              GestureDetector(
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? _indigo : Colors.grey.shade100,
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

          Widget sectionLabel(String text) => Align(
                alignment: Alignment.centerLeft,
                child: Text(text,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600)),
              );

          Widget field(TextEditingController c, String label,
                  {String? prefix, String? suffix}) =>
              TextField(
                controller: c,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setS(() {}),
                decoration: InputDecoration(
                  labelText: label,
                  prefixText: prefix,
                  suffixText: suffix,
                  labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
              );

          Future<void> save() async {
            if (value <= 0) {
              CenterToast.showError(context, 'Enter a valid fee amount.');
              return;
            }
            if (max != null && max <= min) {
              CenterToast.showError(
                  context, 'Max amount must be greater than min.');
              return;
            }
            final now = DateTime.now();
            if (existing != null) {
              await prov.updateRateRule(existing.copyWith(
                provider: provider,
                mode: mode,
                value: value,
                minAmount: min,
                maxAmount: max,
                isActive: isActive,
              ));
            } else {
              for (final t in directionsToCheck) {
                await prov.addRateRule(CicoRateRule(
                  id: _uuid.v4(),
                  provider: provider,
                  txnType: t,
                  mode: mode,
                  value: value,
                  minAmount: min,
                  maxAmount: max,
                  isActive: isActive,
                  createdAt: now,
                ));
              }
            }
            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) {
              CenterToast.showSuccess(
                  context, existing == null ? 'Rate added!' : 'Rate updated!');
            }
          }

          final media = MediaQuery.of(ctx);
          return Padding(
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
                Text(existing == null ? 'Add Rate' : 'Edit Rate',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const SizedBox(height: 16),

                sectionLabel('Provider'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in providers)
                      chip(p, provider == p, () => setS(() => provider = p)),
                  ],
                ),
                const SizedBox(height: 16),

                sectionLabel('Applies To'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (existing == null)
                      chip('Both', direction == 'Both',
                          () => setS(() => direction = 'Both')),
                    chip('Cash In', direction == 'Cash In',
                        () => setS(() => direction = 'Cash In')),
                    chip('Cash Out', direction == 'Cash Out',
                        () => setS(() => direction = 'Cash Out')),
                  ],
                ),
                const SizedBox(height: 16),

                sectionLabel('Fee Type'),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  chip('Fixed ₱', mode == CicoRateMode.fixed,
                      () => setS(() => mode = CicoRateMode.fixed)),
                  chip('Percentage %', mode == CicoRateMode.percentage,
                      () => setS(() => mode = CicoRateMode.percentage)),
                ]),
                const SizedBox(height: 12),

                field(valueCtrl,
                    mode == CicoRateMode.fixed ? 'Fee Amount' : 'Fee',
                    prefix: mode == CicoRateMode.fixed ? '₱ ' : null,
                    suffix: mode == CicoRateMode.percentage ? '%' : null),
                const SizedBox(height: 12),

                sectionLabel('Transaction Amount Range'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: field(minCtrl, 'Min', prefix: '₱ ')),
                  const SizedBox(width: 12),
                  Expanded(
                      child: field(maxCtrl, 'Max (optional)', prefix: '₱ ')),
                ]),

                if (overlapWarning) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 14, color: Colors.amber.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This range overlaps another $provider tier. '
                            'You can still save, but a transaction inside '
                            'the overlap will use the lower-tier rate.',
                            style: TextStyle(
                                fontSize: 11, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isActive,
                  onChanged: (v) => setS(() => isActive = v),
                  activeThumbColor: _indigo,
                  title: const Text('Active',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                  subtitle: Text(
                      'Inactive rates are kept but never auto-applied.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _indigo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(existing == null ? 'Add Rate' : 'Save Changes',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, prov, _) {
      final byProvider = <String, List<CicoRateRule>>{};
      for (final r in prov.rates) {
        byProvider.putIfAbsent(r.provider, () => []).add(r);
      }

      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('GCash & E-Wallet Rates',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          actions: const [
            HelpIconButton(
              title: 'GCash & E-Wallet Rates',
              points: [
                'Define fee tiers per provider and direction (Cash In / Cash Out) — fixed peso amount or a percentage of the transaction.',
                'When a transaction amount falls inside a tier\'s range, a brand-new Cash In/Cash Out entry auto-fills the commission for you — you can still edit it manually, and editing an existing entry never overwrites its saved commission on its own.',
                'A wallet you\'ve registered from the Cash In/Cash Out screen\'s "Add Account" shows up here as a provider option even before its first transaction.',
                'Overlapping ranges are allowed but flagged — the lower-tier rate wins for amounts inside the overlap.',
                'Turn a rate off with the Active switch to keep it on record without it being applied.',
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
        ),
        body: SafeArea(
          top: false,
          child: byProvider.isEmpty
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.percent_rounded,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No rates configured yet',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Tap + to add your first fee tier',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 12)),
                      ]))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  children: [
                    for (final entry in byProvider.entries) ...[
                      Text(entry.key,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87)),
                      const SizedBox(height: 8),
                      for (final t in [CicoType.cashIn, CicoType.cashOut])
                        if (entry.value.any((r) => r.txnType == t)) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6, top: 4),
                            child: Text(
                                t == CicoType.cashIn ? 'Cash In' : 'Cash Out',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: t == CicoType.cashIn
                                        ? AppColors.green
                                        : AppColors.orange)),
                          ),
                          for (final r in entry.value
                              .where((r) => r.txnType == t)
                              .toList()
                            ..sort(
                                (a, b) => a.minAmount.compareTo(b.minAmount)))
                            _rateRow(prov, r),
                        ],
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'rates_fab',
          onPressed: () => _showForm(prov),
          backgroundColor: _indigo,
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Rate',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      );
    });
  }

  Widget _rateRow(AppProvider prov, CicoRateRule r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: r.isActive ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_rangeLabel(r),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: r.isActive ? Colors.black87 : Colors.grey[400])),
              const SizedBox(height: 2),
              Text(_feeLabel(r),
                  style: TextStyle(
                      fontSize: 11,
                      color: r.isActive ? Colors.grey[500] : Colors.grey[400])),
            ],
          ),
        ),
        if (!r.isActive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text('INACTIVE',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[600])),
          ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_outlined, size: 16, color: Colors.grey[400]),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit_outlined, size: 16, color: Colors.black54),
                SizedBox(width: 8),
                Text('Edit', style: TextStyle(fontSize: 13)),
              ]),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline, size: 16, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red, fontSize: 13)),
              ]),
            ),
          ],
          onSelected: (v) {
            if (v == 'edit') {
              _showForm(prov, existing: r);
            } else if (v == 'delete') {
              _confirmDelete(prov, r);
            }
          },
        ),
      ]),
    );
  }
}
