import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_provider.dart';
import '../models/cico_transaction.dart' show CicoType;
import '../models/cico_rate.dart';
import '../theme/app_theme.dart';
import '../widgets/center_toast.dart';
import '../widgets/help_sheet.dart';
import '../widgets/rate_ladder.dart';
import 'padala_calculator_screen.dart';

const _uuid = Uuid();
const _indigo = Color(0xFF4F46E5);

// The standard fixed-fee rate ladder from the reference Padala Counter
// mockup — identical for Cash In and Cash Out there, so it's loaded the
// same for both directions here too. (min, max, fee).
const _standardTiers = <(double, double, double)>[
  (1, 100, 5),
  (101, 500, 10),
  (501, 750, 15),
  (751, 1000, 20),
  (1001, 1500, 30),
  (1501, 2000, 40),
  (2001, 2500, 50),
  (2501, 3000, 60),
  (3001, 3500, 70),
  (3501, 4000, 80),
  (4001, 4500, 90),
  (4501, 5000, 100),
  (5001, 5500, 110),
  (5501, 6000, 120),
];
const _standardProviders = ['GCash', 'Maya'];

class RateSettingsScreen extends StatefulWidget {
  const RateSettingsScreen({super.key});
  @override
  State<RateSettingsScreen> createState() => _RateSettingsScreenState();
}

class _RateSettingsScreenState extends State<RateSettingsScreen> {
  // cicoKnownProviders already folds in CicoTransaction.presetProviders.
  List<String> _allProviders(AppProvider prov) => prov.cicoKnownProviders;

  // Non-blocking, same spirit as the float warnings on the CICO screen —
  // flags an overlapping tier for the same provider+direction but never
  // stops the save, since a deliberate overlap (e.g. temporarily testing a
  // new tier) is the store owner's call, not this screen's.
  bool _overlaps(
    AppProvider prov, {
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

  // Standard-tier (provider, direction, range) combos not yet present in
  // prov.rates — shared by _loadStandardRates (what to insert) and
  // _standardRatesLoaded (whether anything's left to insert), so the two
  // never disagree about what "already loaded" means.
  Iterable<(String, CicoType, (double, double, double))> _missingStandardTiers(
      AppProvider prov) sync* {
    for (final provider in _standardProviders) {
      for (final type in [CicoType.cashIn, CicoType.cashOut]) {
        for (final tier in _standardTiers) {
          final exists = prov.rates.any((r) =>
              r.provider == provider &&
              r.txnType == type &&
              r.minAmount == tier.$1 &&
              r.maxAmount == tier.$2);
          if (!exists) yield (provider, type, tier);
        }
      }
    }
  }

  // Adds the standard mockup rate ladder for GCash + Maya, both directions.
  // Skips any (provider, direction, range) combo that already exists so
  // tapping this again after tweaking one provider doesn't create
  // duplicates or false overlap warnings. One batched insert + one reload,
  // not one of each per tier.
  Future<void> _loadStandardRates(AppProvider prov) async {
    final now = DateTime.now();
    final missing = _missingStandardTiers(prov)
        .map((m) => CicoRateRule(
              id: _uuid.v4(),
              provider: m.$1,
              txnType: m.$2,
              mode: CicoRateMode.fixed,
              value: m.$3.$3,
              minAmount: m.$3.$1,
              maxAmount: m.$3.$2,
              isActive: true,
              createdAt: now,
            ))
        .toList();
    await prov.addRateRules(missing);
    if (!mounted) return;
    if (missing.isNotEmpty) {
      CenterToast.showSuccess(context,
          'Loaded ${missing.length} standard rate tiers for GCash & Maya.');
    } else {
      CenterToast.showWarning(context, 'Standard rates are already loaded.');
    }
  }

  bool _standardRatesLoaded(AppProvider prov) =>
      _missingStandardTiers(prov).isEmpty;

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

  Future<void> _confirmClearAll(AppProvider prov) async {
    final count = prov.rates.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Clear all rates?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        content: Text(
            'This deletes all $count rate tiers across every provider. '
            'This cannot be undone.',
            style: const TextStyle(fontSize: 13, color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All',
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await prov.deleteAllRateRules();
    if (mounted) CenterToast.showWarning(context, 'All rates cleared.');
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
        text:
            existing?.maxAmount != null ? existing!.maxAmount.toString() : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(top: false, child: StatefulBuilder(
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

          // Colors the sheet's top accent + the "Applies To" chips by
          // direction, same green/orange convention as the CICO screen —
          // "Both" stays neutral indigo since it isn't one direction.
          final directionColor = direction == 'Cash In'
              ? AppColors.green
              : direction == 'Cash Out'
                  ? AppColors.orange
                  : _indigo;

          Widget chip(String label, bool selected, VoidCallback onTap,
                  {Color color = _indigo}) =>
              GestureDetector(
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
            // viewInsets.bottom clears the keyboard; padding.bottom clears
            // the system gesture/nav bar on edge-to-edge Android — without
            // it the Add Rate button sat right at the screen edge, behind
            // or flush against the gesture area, making it hard to tap.
            padding: EdgeInsets.only(
                bottom: media.viewInsets.bottom + media.padding.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: directionColor,
                      borderRadius: BorderRadius.circular(2)),
                ),
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
                        () => setS(() => direction = 'Cash In'),
                        color: AppColors.green),
                    chip('Cash Out', direction == 'Cash Out',
                        () => setS(() => direction = 'Cash Out'),
                        color: AppColors.orange),
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
                const SizedBox(height: 8),
              ]),
            ),
          );
        },
      )),
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
              const Text('GCash & E-Wallet Rates',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87)),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              tooltip: 'Padala Calculator',
              icon: const Icon(Icons.calculate_outlined, color: Colors.black87),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PadalaCalculatorScreen())),
            ),
            const HelpIconButton(
              title: 'GCash & E-Wallet Rates',
              points: [
                'Define fee tiers per provider and direction (Cash In / Cash Out) — fixed peso amount or a percentage of the transaction.',
                'When a transaction amount falls inside a tier\'s range, a brand-new Cash In/Cash Out entry auto-fills the commission for you — you can still edit it manually, and editing an existing entry never overwrites its saved commission on its own.',
                'A wallet you\'ve registered from the Cash In/Cash Out screen\'s "Add Account" shows up here as a provider option even before its first transaction.',
                'Overlapping ranges are allowed but flagged — the lower-tier rate wins for amounts inside the overlap.',
                'Turn a rate off with the Active switch to keep it on record without it being applied.',
              ],
            ),
            if (prov.rates.isNotEmpty)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.black87),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'clear_all',
                    child: Row(children: [
                      Icon(Icons.delete_sweep_outlined,
                          size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Clear All Rates',
                          style: TextStyle(color: Colors.red, fontSize: 13)),
                    ]),
                  ),
                ],
                onSelected: (v) {
                  if (v == 'clear_all') _confirmClearAll(prov);
                },
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
                  child: Padding(
                  padding: const EdgeInsets.all(24),
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
                        Text(
                            'Tap + to add your first fee tier, or load '
                            'the standard rates below.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 12)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _loadStandardRates(prov),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _indigo,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Load Standard Rates',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                ))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                                'These are your store\'s default rates — '
                                'edit, deactivate, or delete any tier below '
                                'to match how you actually charge.',
                                style: TextStyle(
                                    fontSize: 10.5, color: Colors.grey[500])),
                          ),
                        ],
                      ),
                    ),
                    if (!_standardRatesLoaded(prov))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: OutlinedButton.icon(
                          onPressed: () => _loadStandardRates(prov),
                          icon: const Icon(Icons.playlist_add, size: 16),
                          label: const Text('Load Standard Rates',
                              style: TextStyle(fontSize: 12.5)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _indigo,
                            side: BorderSide(
                                color: _indigo.withValues(alpha: 0.4)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
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
    final accentColor =
        r.txnType == CicoType.cashIn ? AppColors.green : AppColors.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: r.isActive ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          Container(
              width: 3,
              color: accentColor.withValues(alpha: r.isActive ? 1 : 0.3)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rateRangeLabel(r),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              decoration: r.isActive
                                  ? null
                                  : TextDecoration.lineThrough,
                              decorationColor: Colors.grey[400],
                              color: r.isActive
                                  ? Colors.black87
                                  : Colors.grey[400])),
                      const SizedBox(height: 2),
                      Text(rateFeeLabel(r),
                          style: TextStyle(
                              fontSize: 11,
                              color: r.isActive
                                  ? Colors.grey[500]
                                  : Colors.grey[400])),
                    ],
                  ),
                ),
                if (!r.isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                  icon: Icon(Icons.more_vert_outlined,
                      size: 16, color: Colors.grey[400]),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined,
                            size: 16, color: Colors.black54),
                        SizedBox(width: 8),
                        Text('Edit', style: TextStyle(fontSize: 13)),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(color: Colors.red, fontSize: 13)),
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
            ),
          ),
        ]),
      ),
    );
  }
}
