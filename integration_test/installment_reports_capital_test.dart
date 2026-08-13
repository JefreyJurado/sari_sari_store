// Drives the real, compiled app on the Windows desktop target to verify
// the installment, reports, and capital flows end-to-end.
//
// See sales_credit_flow_test.dart for notes on why finders are scoped to
// find.byType(<Screen>) — IndexedStack keeps all tabs mounted, and pushed
// routes stay mounted (offstage) beneath the current one.
//
// Run with:
//   flutter test integration_test/installment_reports_capital_test.dart -d windows
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:store_ph/models/transaction.dart';
import 'package:store_ph/screens/sales_screen.dart';
import 'package:store_ph/screens/installment_screen.dart';
import 'package:store_ph/screens/capital_screen.dart';
import 'package:store_ph/services/report_service.dart';
import 'package:store_ph/services/installment_service.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final defaultErrorBuilder = ErrorWidget.builder;
  tearDown(() => ErrorWidget.builder = defaultErrorBuilder);

  testWidgets(
      'installment: create a plan and record a payment updates balance correctly',
      (tester) async {
    final prov = await bootToHome(tester);

    await tester.ensureVisible(find.text('Installment'));
    await settle(tester);
    await tester.tap(find.text('Installment'));
    await settle(tester);

    final instScreen = find.byType(InstallmentScreen);
    await tester.tap(find.text('New Installment'));
    await settle(tester);

    final customerName =
        'Integration Test Installment ${DateTime.now().millisecondsSinceEpoch}';
    await tester.enterText(
        find.widgetWithText(TextField, 'Customer name *'), customerName);
    await settle(tester);

    await tester.tap(find.text('Select Products'));
    await settle(tester);

    expect(prov.products, isNotEmpty);
    final product = prov.products.first;
    await tester.enterText(
        find.widgetWithText(TextField, 'Search products...'), product.name);
    await settle(tester);
    // The product row itself has no tap handler in this picker — only the
    // trailing "+" icon adds it. Scope to the picker sheet so this doesn't
    // collide with the InstallmentScreen FAB, which also uses Icons.add.
    final pickerSheet = find.byType(DraggableScrollableSheet);
    await tester.tap(
        find.descendant(of: pickerSheet, matching: find.byIcon(Icons.add)));
    await settle(tester);

    final doneBtn = find.textContaining('Done (');
    await tester.tap(doneBtn);
    await settle(tester);

    final totalAmount = product.sellPrice;
    const down = 0.0;

    await tester.ensureVisible(find.text('Save Installment'));
    await settle(tester);
    await tester.tap(find.text('Save Installment'));
    await settle(tester, pumps: 10);

    expect(find.text('Installment saved!'), findsOneWidget);
    await settle(tester);

    // Freshly saved plan should be on the "Ongoing" tab (index 0, default).
    final nameInCard =
        find.descendant(of: instScreen, matching: find.text(customerName));
    expect(nameInCard, findsOneWidget);
    // Scope subsequent lookups to this specific card so a coincidental
    // match on another pre-existing installment's amount can't collide.
    final cardContainer =
        find.ancestor(of: nameInCard, matching: find.byType(Container)).first;

    final expectedMonthly = (totalAmount - down) / 3; // default 3 months
    final expectedBalance = totalAmount - down;

    // Verify against the actual persisted record rather than scraping
    // rendered text, which sidesteps any formatting/collision fragility.
    var saved = (await InstallmentService.instance.getAll())
        .firstWhere((i) => i.customerName == customerName);
    expect(saved.remainingBalance, closeTo(expectedBalance, 0.01),
        reason: 'remaining balance should be totalAmount - downPayment');
    expect(saved.monthlyPayment, closeTo(expectedMonthly, 0.01),
        reason: 'monthly payment should be (totalAmount - down) / months');

    // Record one payment via the UI and confirm the balance drops by
    // exactly one monthly installment.
    final payBtn = find.descendant(
        of: cardContainer, matching: find.textContaining('Pay — '));
    await tester.tap(payBtn);
    await settle(tester);
    expect(find.text('Accept Payment'), findsOneWidget,
        reason:
            'tapping the card\'s Pay button should open the confirm dialog');
    await tester.tap(find.textContaining('Pay ₱'));
    await settle(tester, pumps: 10);

    // Verify against the persisted record rather than the confirmation
    // SnackBar — a still-visible "Installment saved!" SnackBar from
    // earlier in this test queues ahead of it in ScaffoldMessenger, so it
    // may not be showing yet even though the payment has already applied.
    saved = (await InstallmentService.instance.getAll())
        .firstWhere((i) => i.customerName == customerName);
    expect(saved.paidMonths, 1);
    expect(saved.remainingBalance,
        closeTo(expectedBalance - expectedMonthly, 0.01),
        reason: 'balance should decrease by exactly one monthly payment');

    // Clean up: delete the installment, the test customer, and any
    // "Integration Test Installment" stragglers left by earlier failed
    // debugging runs of this test.
    await tester.tap(find.descendant(
        of: cardContainer, matching: find.byIcon(Icons.more_vert_outlined)));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await tester.tap(find.text('Delete').last);
    await settle(tester);

    final stragglers = (await InstallmentService.instance.getAll())
        .where((i) => i.customerName.startsWith('Integration Test Installment'))
        .toList();
    for (final s in stragglers) {
      await InstallmentService.instance.delete(s.id);
    }
    final testCustomers = prov.customers
        .where((c) => c.name.startsWith('Integration Test Installment'))
        .toList();
    for (final c in testCustomers) {
      await prov.deleteCustomer(c.id);
    }
    await settle(tester);
    ErrorWidget.builder = defaultErrorBuilder;
  });

  testWidgets(
      'reports "Today" total matches Home screen todayRevenue (date-window fix)',
      (tester) async {
    final prov = await bootToHome(tester);

    await goToTab(tester, 'Sales');
    final salesScreen = find.byType(SalesScreen);
    expect(prov.products, isNotEmpty);
    final product = prov.products[1];
    final originalStock = product.stock;
    await prov.updateProduct(product.copyWith(stock: 10));
    await settle(tester);

    final productCard =
        find.descendant(of: salesScreen, matching: find.text(product.name));
    await tester.tap(productCard);
    await tester.pump();

    final cartIcons = find.descendant(
        of: salesScreen, matching: find.byIcon(Icons.shopping_cart_rounded));
    await tester.tap(cartIcons.first);
    await settle(tester);

    final cartSheet = find.byType(DraggableScrollableSheet);
    final cartListView =
        find.descendant(of: cartSheet, matching: find.byType(ListView)).first;
    for (var i = 0; i < 5; i++) {
      await tester.drag(cartListView, const Offset(0, -400));
      await settle(tester);
    }
    final checkoutBtn = find.descendant(
        of: cartSheet, matching: find.textContaining('Process Order Summary'));
    await tester.tap(checkoutBtn);
    await settle(tester, pumps: 10);
    await tester.tap(find.text('Dismiss'));
    await settle(tester);

    // Sanity: the sale really landed in "today".
    expect(prov.todayRevenue, greaterThan(0));

    await goToTab(tester, 'Reports');
    await settle(tester, pumps: 20);

    expect(find.textContaining('Total Sales'), findsOneWidget,
        reason: 'reports screen should render its stat cards without error');

    // Precisely verify the date-window fix: Reports "Today" (a single-day
    // since/until window) must equal Home/AppProvider's calendar-day
    // todayRevenue, not a rolling 24h window that could double-count or
    // miss part of today's sales.
    final startOfToday =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final todayReport = await ReportService.instance.generateReport(
      expenses: prov.expenses,
      groceryEntries: prov.groceryEntries,
      cico: prov.cico,
      since: startOfToday,
      until: startOfToday,
    );
    expect(todayReport.totalRevenue, prov.todayRevenue,
        reason:
            'Reports "Today" total must match Home screen todayRevenue after the date-window fix');

    // Clean up: void the sale and restore stock.
    final createdSale = prov.sales
        .where((s) =>
            s.status == TxStatus.completed &&
            s.items.length == 1 &&
            s.items.first.productId == product.id)
        .reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
    await prov.voidSale(createdSale);
    await settle(tester);
    await prov.updateProduct(prov.products
        .firstWhere((p) => p.id == product.id)
        .copyWith(stock: originalStock));
    await settle(tester);
    ErrorWidget.builder = defaultErrorBuilder;
  });

  testWidgets(
      'capital: adding a setup cost item updates Total Investment correctly',
      (tester) async {
    final prov = await bootToHome(tester);

    final originalCapital = prov.capital;
    final originalInvestment = prov.totalInvestment;

    final capitalEntry = originalCapital == null
        ? find.text('Set up Beginning Balance')
        : find.text('Capital Overview').first;
    await tester.ensureVisible(capitalEntry);
    await settle(tester);
    await tester.tap(capitalEntry);
    await settle(tester);

    final capitalScreen = find.byType(CapitalScreen);

    // Adding an item opens a dedicated bottom sheet (one item's fields at a
    // time) straight from "Add Item" — there's no separate whole-list edit
    // mode to enter first, and the sheet always starts with exactly 3 empty
    // fields (Description, Amount, Vendor) regardless of how many items
    // already exist, since existing items are a read-only tap-to-edit list
    // rather than inline fields.
    final addItemBtn =
        find.descendant(of: capitalScreen, matching: find.text('Add Item'));
    await tester.ensureVisible(addItemBtn);
    await settle(tester);
    await tester.tap(addItemBtn);
    await settle(tester);

    final descField = find.byType(TextField).at(0);
    final amountField = find.byType(TextField).at(1);
    await tester.enterText(descField, 'Integration Test Equipment');
    await settle(tester);
    const addedAmount = 250.0;
    await tester.enterText(amountField, addedAmount.toStringAsFixed(2));
    await settle(tester);

    await tester.tap(find.text('Save'));
    await settle(tester, pumps: 10);

    expect(find.text('Item added!'), findsOneWidget);
    await settle(tester);

    final expectedInvestment = originalInvestment + addedAmount;
    expect(prov.totalInvestment, expectedInvestment,
        reason:
            'Total Investment should increase by exactly the new setup cost item\'s amount');

    // Clean up: restore the original capital record.
    await prov.saveCapital(
      setupCosts: originalCapital?.computedSetupCosts ?? 0,
      inventoryValue: originalCapital?.inventoryValue ?? 0,
      setupItems: originalCapital?.setupItems ?? [],
    );
    await settle(tester);
    expect(prov.totalInvestment, originalInvestment);
    ErrorWidget.builder = defaultErrorBuilder;
  });
}
