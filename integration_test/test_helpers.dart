// Shared boot/navigation helpers for integration tests.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:store_ph/main.dart' as app;
import 'package:store_ph/providers/app_provider.dart';

Future<AppProvider> bootToHome(WidgetTester tester) async {
  app.main();
  await tester.pumpAndSettle(const Duration(seconds: 2));

  final skip = find.text('Skip');
  if (skip.evaluate().isNotEmpty) {
    await tester.tap(skip);
    await tester.pumpAndSettle();
  }

  final prov = Provider.of<AppProvider>(
      tester.element(find.byType(MaterialApp)),
      listen: false);
  prov.clearCart();
  return prov;
}

Future<void> goToTab(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(ValueKey('navtab_$label')));
  await tester.pumpAndSettle();
}
