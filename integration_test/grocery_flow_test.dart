// Drives the real, compiled app on the Windows desktop target to verify
// the Grocery flow — specifically adding a brand-new product inline (name
// + category + this trip's quantity/price, all on one sheet) and
// confirming it updates Inventory stock and buy price by what was logged.
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
      'grocery: add new product inline and stock/buy price update',
      (tester) async {
    final prov = await bootToHome(tester);

    await tester.ensureVisible(find.text('Grocery'));
    await settle(tester);
    await tester.tap(find.text('Grocery'));
    await settle(tester);

    await tester.tap(find.text('Add Grocery'));
    await settle(tester);

    // "Add New Product" is visible directly on the Add Grocery sheet now —
    // no need to open the product picker first.
    await tester.ensureVisible(find.text('Add New Product'));
    await settle(tester);
    await tester.tap(find.text('Add New Product'));
    await settle(tester);

    final productName =
        'Integration Test Grocery Product ${DateTime.now().millisecondsSinceEpoch}';
    await tester.enterText(
        find.widgetWithText(TextField, 'Product Name *'), productName);
    await settle(tester);

    // New-product mode never asks for Buy/Sell Price — no separate "Save
    // Product" step either, it's all one save at the bottom of this sheet.
    expect(find.widgetWithText(TextField, 'Buy Price *'), findsNothing);
    expect(find.widgetWithText(TextField, 'Sell Price *'), findsNothing);
    expect(find.text('Save Product'), findsNothing);

    const quantity = 12;
    await tester.enterText(
        find.widgetWithText(TextField, 'Quantity *'), '$quantity');
    // Price per Unit × Quantity should auto-compute Expenses for Products
    // (12.5 × 12 = 150) rather than requiring that total typed in by hand.
    await tester.enterText(
        find.widgetWithText(TextField, 'Price per Unit *'), '12.5');
    await settle(tester);

    // Transpo is no longer entered per product.
    expect(find.widgetWithText(TextField, 'Transpo'), findsNothing);

    // New-product mode adds enough fields that the Save button can sit
    // below the fold — scroll it into view before tapping.
    await tester.ensureVisible(find.text('Save Grocery Entry'));
    await settle(tester);
    await tester.tap(find.text('Save Grocery Entry'));
    await settle(tester, pumps: 20);

    // The success toast is a ~1.4s animated overlay, timing-sensitive to
    // assert on directly — the sheet closing (form no longer present) is
    // the durable signal that the save actually went through rather than
    // failing validation silently.
    expect(find.text('Save Grocery Entry'), findsNothing);

    expect(prov.products.any((p) => p.name == productName), isTrue);
    final createdProduct =
        prov.products.firstWhere((p) => p.name == productName);
    expect(createdProduct.stock, quantity);
    // A brand-new product's buy price is set from this first trip's price
    // per unit, since it had none yet.
    expect(createdProduct.buyPrice, 12.5);
    expect(createdProduct.sellPrice, 0);

    final entry =
        prov.groceryEntries.firstWhere((g) => g.productId == createdProduct.id);
    expect(entry.quantity, quantity);
    expect(entry.expensesForProducts, 150);
    expect(entry.transpo, 0);
    expect(entry.totalExpenses, 150);

    // Budget/Sukli were removed from the flow entirely — back on the list
    // screen after save, neither should be findable anywhere.
    expect(find.textContaining('Budget'), findsNothing);
    expect(find.textContaining('Sukli'), findsNothing);

    // Tapping the tile opens it for editing — bump the quantity and confirm
    // stock moves by the delta rather than being replaced outright.
    await tester.tap(find.textContaining(productName).first);
    await settle(tester);
    expect(find.text('Edit Grocery Entry'), findsOneWidget);
    expect(find.textContaining('Budget'), findsNothing);

    const updatedQuantity = 15;
    await tester.enterText(
        find.widgetWithText(TextField, 'Quantity *'), '$updatedQuantity');
    await settle(tester);
    await tester.ensureVisible(find.text('Update Grocery Entry'));
    await settle(tester);
    await tester.tap(find.text('Update Grocery Entry'));
    await settle(tester, pumps: 20);
    expect(find.text('Update Grocery Entry'), findsNothing);

    final editedProduct =
        prov.products.firstWhere((p) => p.id == createdProduct.id);
    expect(editedProduct.stock, updatedQuantity);

    // Delete it via the tile's overflow menu, then confirm the dialog —
    // stock should be subtracted back to where it started (0).
    await tester.tap(find.byIcon(Icons.more_vert_outlined).first);
    await settle(tester);
    await tester.tap(find.text('Delete').first);
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await settle(tester, pumps: 15);

    expect(prov.groceryEntries.any((g) => g.id == entry.id), isFalse);
    final revertedProduct =
        prov.products.firstWhere((p) => p.id == createdProduct.id);
    expect(revertedProduct.stock, 0);

    ErrorWidget.builder = defaultErrorBuilder;
  });

  testWidgets('grocery: restock an existing product via search picker',
      (tester) async {
    final prov = await bootToHome(tester);

    await tester.ensureVisible(find.text('Grocery'));
    await settle(tester);
    await tester.tap(find.text('Grocery'));
    await settle(tester);

    await tester.tap(find.text('Add Grocery'));
    await settle(tester);

    // The existing-product path still goes through the search picker,
    // reached via the "Select Product *" box (not "Add New Product").
    await tester.tap(find.text('Select Product *'));
    await settle(tester);

    // The picker sheet stacks on top of (rather than replacing) the outer
    // Add Grocery sheet, so its "Add New Product" button is still mounted
    // underneath — just not duplicated by the picker itself.
    expect(find.text('Add New Product'), findsOneWidget);
    expect(find.textContaining('Restocking?'), findsOneWidget);

    expect(prov.products, isNotEmpty);
    final existingProduct = prov.products.first;
    final stockBefore = existingProduct.stock;

    await tester.tap(find.text(existingProduct.name).first);
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Quantity *'), '5');
    await tester.enterText(
        find.widgetWithText(TextField, 'Price per Unit *'), '3');
    await settle(tester);

    await tester.ensureVisible(find.text('Save Grocery Entry'));
    await settle(tester);
    await tester.tap(find.text('Save Grocery Entry'));
    await settle(tester, pumps: 20);
    expect(find.text('Save Grocery Entry'), findsNothing);

    final restocked =
        prov.products.firstWhere((p) => p.id == existingProduct.id);
    expect(restocked.stock, stockBefore + 5);

    ErrorWidget.builder = defaultErrorBuilder;
  });

  testWidgets(
      'grocery: Inventory "Restock (Grocery)" shortcut prefills the product',
      (tester) async {
    final prov = await bootToHome(tester);

    // Create a fresh, uniquely-named product via Grocery first so there's
    // a known single target to search for and restock from Inventory.
    await tester.ensureVisible(find.text('Grocery'));
    await settle(tester);
    await tester.tap(find.text('Grocery'));
    await settle(tester);
    await tester.tap(find.text('Add Grocery'));
    await settle(tester);
    await tester.ensureVisible(find.text('Add New Product'));
    await settle(tester);
    await tester.tap(find.text('Add New Product'));
    await settle(tester);

    final productName =
        'Integration Test Restock Shortcut ${DateTime.now().millisecondsSinceEpoch}';
    await tester.enterText(
        find.widgetWithText(TextField, 'Product Name *'), productName);
    await tester.enterText(find.widgetWithText(TextField, 'Quantity *'), '4');
    await tester.enterText(
        find.widgetWithText(TextField, 'Price per Unit *'), '2');
    await settle(tester);
    await tester.ensureVisible(find.text('Save Grocery Entry'));
    await settle(tester);
    await tester.tap(find.text('Save Grocery Entry'));
    await settle(tester, pumps: 20);
    expect(find.text('Save Grocery Entry'), findsNothing);

    final product = prov.products.firstWhere((p) => p.name == productName);
    expect(product.stock, 4);

    // Grocery was reached via a pushed route (from Home's quick action),
    // not the bottom nav — pop back to Home so the nav bar is visible
    // again before switching tabs.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);

    // Go to Inventory, search down to just this product, and use its
    // overflow menu's restock shortcut.
    await goToTab(tester, 'Products');
    await settle(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Search products...'), productName);
    await settle(tester);

    await tester.tap(find.byIcon(Icons.more_vert_outlined).first);
    await settle(tester);
    await tester.tap(find.text('Restock (Grocery)'));
    await settle(tester, pumps: 20);

    // Lands directly on the Add Grocery sheet with the product already
    // picked — no "Select Product *" placeholder, no picker needed.
    expect(find.text('Add Grocery Entry'), findsOneWidget);
    expect(find.text('Select Product *'), findsNothing);
    expect(find.text(productName), findsWidgets);

    await tester.enterText(find.widgetWithText(TextField, 'Quantity *'), '6');
    await tester.enterText(
        find.widgetWithText(TextField, 'Price per Unit *'), '2.5');
    await settle(tester);
    await tester.ensureVisible(find.text('Save Grocery Entry'));
    await settle(tester);
    await tester.tap(find.text('Save Grocery Entry'));
    await settle(tester, pumps: 20);
    expect(find.text('Save Grocery Entry'), findsNothing);

    final restockedViaShortcut =
        prov.products.firstWhere((p) => p.id == product.id);
    expect(restockedViaShortcut.stock, 10);

    ErrorWidget.builder = defaultErrorBuilder;
  });

  testWidgets(
      'grocery: restocking an already-priced product pins it in Inventory '
      'for one visit only',
      (tester) async {
    final prov = await bootToHome(tester);

    await goToTab(tester, 'Products');
    await settle(tester);

    final target = prov.products.firstWhere((p) => p.sellPrice > 0);

    await tester.enterText(
        find.widgetWithText(TextField, 'Search products...'), target.name);
    await settle(tester);
    await tester.tap(find.byIcon(Icons.more_vert_outlined).first);
    await settle(tester);
    await tester.tap(find.text('Restock (Grocery)'));
    await settle(tester, pumps: 20);

    await tester.enterText(find.widgetWithText(TextField, 'Quantity *'), '2');
    await tester.enterText(
        find.widgetWithText(TextField, 'Price per Unit *'), '5');
    await settle(tester);
    await tester.ensureVisible(find.text('Save Grocery Entry'));
    await settle(tester);
    await tester.tap(find.text('Save Grocery Entry'));
    await settle(tester, pumps: 20);
    expect(find.text('Save Grocery Entry'), findsNothing);

    // Pop back from Grocery (a pushed route, not a tab switch) to
    // Products — still the same visit, so the badge should already show.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'Search products...'), target.name);
    await settle(tester);
    expect(find.text('RESTOCKED'), findsOneWidget);

    // Leaving Products and coming back is a new visit — the pin/badge
    // should be gone even though nothing else changed about the product.
    await goToTab(tester, 'Home');
    await settle(tester);
    await goToTab(tester, 'Products');
    await settle(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'Search products...'), target.name);
    await settle(tester);
    expect(find.text('RESTOCKED'), findsNothing);

    ErrorWidget.builder = defaultErrorBuilder;
  });

  testWidgets(
      'grocery: Inventory\'s "Add Product" FAB opens Grocery in new-product '
      'mode directly, no dialog',
      (tester) async {
    await bootToHome(tester);

    await goToTab(tester, 'Products');
    await settle(tester);

    await tester.tap(find.text('Add Product'));
    await settle(tester, pumps: 20);

    // Straight into Grocery's new-product mode — name/category fields
    // already showing, no chooser dialog and no restock search in sight.
    expect(find.text('Add Grocery Entry'), findsOneWidget);
    expect(find.text('New Product'), findsOneWidget);
    expect(find.text('Select Product *'), findsNothing);
    expect(find.widgetWithText(TextField, 'Product Name *'), findsOneWidget);

    ErrorWidget.builder = defaultErrorBuilder;
  });

  testWidgets(
      'grocery: Inventory\'s "Manual Add" tool opens the direct '
      'no-cost-tracked catalog form',
      (tester) async {
    await bootToHome(tester);

    await goToTab(tester, 'Products');
    await settle(tester);

    await tester.tap(find.text('Manual Add'));
    await settle(tester);

    // An explanatory dialog shows first — no cost tracking here — with a
    // Continue step before the actual form opens.
    expect(find.textContaining('no purchase is logged'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await settle(tester);

    // The direct catalog form — Buy/Sell Price and Stock right there, no
    // Grocery quantity/price-per-unit flow involved.
    expect(find.text('Add to Catalog'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Cost price'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Sell price'), findsOneWidget);

    ErrorWidget.builder = defaultErrorBuilder;
  });
}
