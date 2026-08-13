// Drives the real, compiled app on the Windows desktop target to verify
// the Grocery Budget flow — specifically adding a brand-new product
// inline from the product picker and confirming it updates Inventory
// stock by the logged quantity.
//
// Run with:
//   flutter test integration_test/grocery_flow_test.dart -d windows
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // main.dart's MaterialApp.builder unconditionally reassigns
  // ErrorWidget.builder on every build. That trips flutter_test's global
  // isolation check at the end of a test, so save/restore it ourselves.
  final defaultErrorBuilder = ErrorWidget.builder;
  tearDown(() => ErrorWidget.builder = defaultErrorBuilder);

  testWidgets(
      'grocery: add new product inline from picker and stock updates',
      (tester) async {
    final prov = await bootToHome(tester);

    await tester.ensureVisible(find.text('Grocery Budget'));
    await settle(tester);
    await tester.tap(find.text('Grocery Budget'));
    await settle(tester);

    await tester.tap(find.text('Add Grocery'));
    await settle(tester);

    await tester.tap(find.text('Select Product *'));
    await settle(tester);

    await tester.tap(find.text('Add New Product'));
    await settle(tester);

    final productName =
        'Integration Test Grocery Product ${DateTime.now().millisecondsSinceEpoch}';
    await tester.enterText(
        find.widgetWithText(TextField, 'Product Name *'), productName);
    await tester.enterText(
        find.widgetWithText(TextField, 'Buy Price *'), '10');
    await tester.enterText(
        find.widgetWithText(TextField, 'Sell Price *'), '15');
    await settle(tester);

    await tester.tap(find.text('Save Product'));
    await settle(tester, pumps: 15);

    // Both the picker sheet and the quick-add sheet should have closed,
    // landing back on the grocery form with the new product selected.
    expect(find.text(productName), findsOneWidget);

    expect(prov.products.any((p) => p.name == productName), isTrue);
    final createdProduct =
        prov.products.firstWhere((p) => p.name == productName);
    expect(createdProduct.stock, 0);

    const quantity = 12;
    await tester.enterText(
        find.widgetWithText(TextField, 'Quantity *'), '$quantity');
    await tester.enterText(
        find.widgetWithText(TextField, 'Budget *'), '200');
    await tester.enterText(
        find.widgetWithText(TextField, 'Expenses for Products *'), '150');
    await tester.enterText(find.widgetWithText(TextField, 'Transpo'), '20');
    await settle(tester);

    await tester.tap(find.text('Save Grocery Entry'));
    await settle(tester, pumps: 20);

    // The success toast is a ~1.4s animated overlay, timing-sensitive to
    // assert on directly — the sheet closing (form no longer present) is
    // the durable signal that the save actually went through rather than
    // failing validation silently.
    expect(find.text('Save Grocery Entry'), findsNothing);

    final restockedProduct =
        prov.products.firstWhere((p) => p.id == createdProduct.id);
    expect(restockedProduct.stock, quantity);

    final entry =
        prov.groceryEntries.firstWhere((g) => g.productId == createdProduct.id);
    expect(entry.quantity, quantity);
    expect(entry.budget, 200);
    expect(entry.expensesForProducts, 150);
    expect(entry.transpo, 20);
    expect(entry.totalExpenses, 170);
    expect(entry.change, 30);
    ErrorWidget.builder = defaultErrorBuilder;
  });
}
