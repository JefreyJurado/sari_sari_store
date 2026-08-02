import 'package:flutter/material.dart';
import '../models/cico_transaction.dart';
import '../theme/app_theme.dart';

// Shared CICO brand indigo — same value used across cico_screen.dart,
// rate_settings_screen.dart, padala_calculator_screen.dart and
// reports_screen.dart (each keeps its own local copy of this constant since
// it's used for more than just type metadata in some of those files).
const cicoIndigo = Color(0xFF4F46E5);

class CicoTypeMeta {
  final String label;
  final IconData icon;
  final Color color;
  final String description;
  const CicoTypeMeta(this.label, this.icon, this.color, this.description);
}

// Single source of truth for how each CicoType is labeled/colored/iconed,
// shared between the ledger (cico_screen.dart) and the calculator
// (padala_calculator_screen.dart) so a rebrand only has to happen once.
const cicoTypeMeta = {
  CicoType.cashIn: CicoTypeMeta('Cash In', Icons.south_west_rounded,
      AppColors.green, 'Customer gives you cash, you send them e-money'),
  CicoType.cashOut: CicoTypeMeta('Cash Out', Icons.north_east_rounded,
      AppColors.orange, 'Customer sends you e-money, you give them cash'),
  CicoType.topUp: CicoTypeMeta('Top Up', Icons.add_circle_outline, cicoIndigo,
      'Add money into one of your own accounts'),
  CicoType.withdraw: CicoTypeMeta('Withdraw', Icons.remove_circle_outline,
      AppColors.red, 'Take money out of one of your own accounts'),
};

String cicoProviderLabel(String provider) =>
    provider == CicoTransaction.cashAccount ? 'Cash Float' : provider;
