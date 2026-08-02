import 'package:flutter/material.dart';
import '../models/cico_rate.dart';
import '../utils/currency_formatter.dart';

String rateRangeLabel(CicoRateRule r) => r.maxAmount == null
    ? '${CurrencyFormatter.format(r.minAmount)}+'
    : '${CurrencyFormatter.format(r.minAmount)} – '
        '${CurrencyFormatter.format(r.maxAmount!)}';

String rateFeeLabel(CicoRateRule r) => r.mode == CicoRateMode.fixed
    ? '${CurrencyFormatter.format(r.value)} flat'
    : '${r.value.toStringAsFixed(r.value == r.value.roundToDouble() ? 0 : 1)}%';

// A single bracket row inside a rate-ladder preview. Once an amount is
// entered, the bracket it falls into is highlighted and the rest read as
// struck-through/inapplicable, matching the reference Padala Counter
// mockup. Before any amount is entered there's nothing to compare against
// yet, so every row instead reads as plain/neutral — showing the whole
// list crossed out by default (as if nothing qualified) would look broken.
class RateLadderRow extends StatelessWidget {
  final CicoRateRule rule;
  final bool matches;
  final bool hasAmount;
  final Color color;
  const RateLadderRow(
      {super.key,
      required this.rule,
      required this.matches,
      required this.color,
      this.hasAmount = true});

  @override
  Widget build(BuildContext context) {
    final dimmed = hasAmount && !matches;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: matches ? color.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Text(rateRangeLabel(rule),
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: matches ? FontWeight.w700 : FontWeight.normal,
                decoration: dimmed ? TextDecoration.lineThrough : null,
                decorationColor: Colors.grey[400],
                color: matches
                    ? color
                    : (dimmed ? Colors.grey[400] : Colors.grey[700]))),
        const Spacer(),
        Text(rateFeeLabel(rule),
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: matches ? FontWeight.w700 : FontWeight.w500,
                color: matches
                    ? color
                    : (dimmed ? Colors.grey[500] : Colors.grey[600]))),
      ]),
    );
  }
}

// The Service charge / Total payable summary plus the full rate ladder
// (matching bracket highlighted) — everything below the amount field in
// the mockup. Split out from RateLadderCard so a screen that already has
// its own bordered/accented container (like PadalaCalculatorScreen) can
// use just the body, while RateLadderCard wraps it for screens that don't.
class RateLadderBody extends StatelessWidget {
  final List<CicoRateRule> tiers;
  final CicoRateRule? matched;
  final Color color;
  final double amount;
  final double commission;

  const RateLadderBody({
    super.key,
    required this.tiers,
    required this.matched,
    required this.color,
    required this.amount,
    required this.commission,
  });

  @override
  Widget build(BuildContext context) {
    if (tiers.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      Row(children: [
        Text('Service charge',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const Spacer(),
        Text(CurrencyFormatter.format(commission),
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        const Text('Total payable',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        const Spacer(),
        Text(CurrencyFormatter.format(amount + commission),
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.black87)),
      ]),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, size: 12, color: Colors.grey[400]),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
              'These are your store\'s default rates — adjust them '
              'anytime in Manage Rates.',
              style: TextStyle(fontSize: 10.5, color: Colors.grey[500])),
        ),
      ]),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: Text('RATE LADDER',
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: Colors.grey[500])),
      ),
      const SizedBox(height: 6),
      for (final tier in tiers)
        RateLadderRow(
            rule: tier,
            matches: tier.id == matched?.id,
            hasAmount: amount > 0,
            color: color),
    ]);
  }
}

// The calculator-style card from the mockup: a colored top accent wrapped
// around RateLadderBody. Used by the Add Transaction form; the standalone
// Padala Calculator screen uses RateLadderBody directly since it already
// supplies its own bordered/accented container.
class RateLadderCard extends StatelessWidget {
  final List<CicoRateRule> tiers;
  final CicoRateRule? matched;
  final Color color;
  final double amount;
  final double commission;

  const RateLadderCard({
    super.key,
    required this.tiers,
    required this.matched,
    required this.color,
    required this.amount,
    required this.commission,
  });

  @override
  Widget build(BuildContext context) {
    if (tiers.isEmpty) return const SizedBox.shrink();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: [
        Container(height: 4, color: color),
        Padding(
          padding: const EdgeInsets.all(12),
          child: RateLadderBody(
            tiers: tiers,
            matched: matched,
            color: color,
            amount: amount,
            commission: commission,
          ),
        ),
      ]),
    );
  }
}
