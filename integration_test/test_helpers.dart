// Shared boot/navigation helpers for integration tests.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:store_ph/main.dart' as app;
import 'package:store_ph/providers/app_provider.dart';

// Home's mascot widget runs a `..repeat()` AnimationController, so the
// transient-callback queue never empties and pumpAndSettle() never
// converges — it just spins until its 10-minute timeout. Pump a bounded
// number of fixed-duration frames instead; `pumps` lets slower transitions
// (initial boot, dialog animations) get more real time without
// reintroducing the "wait until truly idle" hang.
Future<void> settle(WidgetTester tester, {int pumps = 10}) async {
  for (var i = 0; i < pumps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<AppProvider> bootToHome(WidgetTester tester) async {
  app.main();
  await settle(tester, pumps: 20);

  final skip = find.text('Skip');
  if (skip.evaluate().isNotEmpty) {
    await tester.tap(skip);
    await settle(tester);
  }

  final prov = Provider.of<AppProvider>(
      tester.element(find.byType(MaterialApp)),
      listen: false);
  prov.clearCart();
  return prov;
}

Future<void> goToTab(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(ValueKey('navtab_$label')));
  await settle(tester);
}
