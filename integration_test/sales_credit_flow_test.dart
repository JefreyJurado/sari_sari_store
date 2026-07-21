// Drives the real, compiled app on the Windows desktop target to verify
// the sales cart, credit order, and void/loyalty fixes end-to-end.
//
// Products are picked dynamically from whatever is currently in the local
// database (rather than hardcoded seed names) so this test is robust
// against real, edited catalog data. Each test restores the product(s) it
// touches and voids/removes any sale, debt, or customer it created.
//
// Note: main.dart's `_MainShell` keeps all 5 tabs mounted simultaneously
// via IndexedStack, and pushed routes stay mounted (offstage) beneath the
// current one — so bare `find.text(...)` / `find.byType(TextField)` can
// match widgets in a screen that isn't even visible. Finders below are
// scoped with `find.descendant(of: find.byType(<Screen>), ...)` to avoid
// that cross-contamination.
//
// Run with:
//   flutter test integration_test/sales_credit_flow_test.dart -d windows
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:store_ph/main.dart' as app;
import 'package:store_ph/providers/app_provider.dart';
import 'package:store_ph/models/transaction.dart';
import 'package:store_ph/screens/sales_screen.dart';
import 'package:store_ph/screens/credit_order_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // main.dart's MaterialApp.builder unconditionally reassigns
  // ErrorWidget.builder on every build. That trips flutter_test's global
  // isolation check at the end of a test, so save/restore it ourselves.
  final defaultErrorBuilder = ErrorWidget.builder;
  tearDown(() => ErrorWidget.builder = defaultErrorBuilder);

  // Home's mascot widget runs a `..repeat()` AnimationController, so the
  // transient-callback queue never empties and pumpAndSettle() never
  // converges — it just spins until its 10-minute timeout. Pump a bounded
  // number of fixed-duration frames instead; `pumps` lets slower
  // transitions (initial boot, dialog animations) get more real time
  // without reintroducing the "wait until truly idle" hang.
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

  testWidgets(
      'cart entry survives a product reload instead of duplicating (Product equality fix)',
      (tester) async {
    final prov = await bootToHome(tester);

    await goToTab(tester, 'Sales');
    final salesScreen = find.byType(SalesScreen);

    expect(prov.products, isNotEmpty,
        reason: 'need at least one product in the catalog to run this test');
    final original = prov.products.first;
    await prov.updateProduct(original.copyWith(stock: 24));
    await settle(tester);

    Finder productCard() =>
        find.descendant(of: salesScreen, matching: find.text(original.name));
    expect(productCard(), findsOneWidget);

    await tester.tap(productCard());
    await tester.pump();

    expect(prov.cart.length, 1);
    expect(prov.cartItemCount, 1);

    // Simulate "cashier edits an unrelated product / a reload happens while
    // the cart is open" — this reassigns AppProvider.products to fresh
    // Product instances, which used to orphan the cart entry (identity
    // equality on the old Product class).
    final refreshed = prov.products.firstWhere((p) => p.id == original.id);
    await prov.updateProduct(refreshed.copyWith());
    await settle(tester);

    await tester.tap(productCard());
    await tester.pump();

    expect(prov.cart.length, 1,
        reason:
            'cart must not gain a second, orphaned entry for the same product after a reload');
    expect(prov.cartItemCount, 2,
        reason:
            'the existing entry should have been incremented, not duplicated');

    prov.clearCart();
    await prov.updateProduct(prov.products
        .firstWhere((p) => p.id == original.id)
        .copyWith(stock: original.stock));
    await settle(tester);
    ErrorWidget.builder = defaultErrorBuilder;
  });

  testWidgets('a cash sale completes and decrements stock correctly',
      (tester) async {
    final prov = await bootToHome(tester);

    await goToTab(tester, 'Sales');
    final salesScreen = find.byType(SalesScreen);

    expect(prov.products.length, greaterThan(1));
    final original = prov.products[1];
    await prov.updateProduct(original.copyWith(stock: 48));
    await settle(tester);

    Finder productCard() =>
        find.descendant(of: salesScreen, matching: find.text(original.name));
    await tester.tap(productCard());
    await tester.pump();
    await tester.tap(productCard());
    await tester.pump();
    expect(prov.cart.values.first, 2);

    // Two shopping_cart_rounded icons render once the cart is non-empty
    // (the app-bar badge button and a floating cart summary bar) — either
    // opens the same cart sheet, so just tap the first match.
    final cartIcons = find.descendant(
        of: salesScreen, matching: find.byIcon(Icons.shopping_cart_rounded));
    await tester.tap(cartIcons.first);
    await settle(tester);

    // The cart sheet's checkout button is below the fold in a
    // DraggableScrollableSheet, so it isn't mounted until scrolled into the
    // sliver's cache range. Drag manually on content known to already be
    // mounted (scrollUntilVisible's internal machinery gets confused here).
    final cartSheet = find.byType(DraggableScrollableSheet);
    // The sheet also contains a horizontal ListView (customer chips) —
    // the outer vertical one we want to drag is the first match.
    final cartListView =
        find.descendant(of: cartSheet, matching: find.byType(ListView)).first;
    for (var i = 0; i < 5; i++) {
      await tester.drag(cartListView, const Offset(0, -400));
      await settle(tester);
    }
    final checkoutBtn = find.descendant(
        of: cartSheet, matching: find.textContaining('Process Order Summary'));
    expect(checkoutBtn, findsOneWidget,
        reason: 'checkout button should be scrolled into view by now');
    await tester.tap(checkoutBtn);
    await settle(tester, pumps: 10);

    expect(find.text('Sale complete'), findsOneWidget,
        reason: 'checkout should succeed and show the confirmation dialog');

    await tester.tap(find.text('Dismiss'));
    await settle(tester);

    final afterSale = prov.products.firstWhere((p) => p.id == original.id);
    expect(afterSale.stock, 46,
        reason: 'stock should be decremented by exactly the quantity sold');

    // Clean up: void the sale this test created (also exercises the
    // void-sale fix: stock restore + debt/loyalty reversal), then restore
    // the product's original stock.
    final createdSale = prov.sales
        .where((s) =>
            s.status == TxStatus.completed &&
            s.items.length == 1 &&
            s.items.first.productId == original.id)
        .reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
    await prov.voidSale(createdSale);
    await settle(tester);
    await prov.updateProduct(prov.products
        .firstWhere((p) => p.id == original.id)
        .copyWith(stock: original.stock));
    await settle(tester);
    ErrorWidget.builder = defaultErrorBuilder;
  });

  testWidgets(
      'credit order caps quantity at available stock and warns when exceeding the credit limit',
      (tester) async {
    final prov = await bootToHome(tester);
    final salesBefore = prov.sales.map((s) => s.id).toSet();

    expect(prov.products.length, greaterThan(2));
    final original = prov.products[2];
    // Force deterministic stock + price so the order is guaranteed to both
    // exceed available stock (cap test) and exceed the customer's default
    // 500-peso credit limit (warning test).
    await prov.updateProduct(original.copyWith(stock: 10, sellPrice: 60));
    await settle(tester);

    await goToTab(tester, 'Credit');

    await tester.tap(find.text('New Credit'));
    await settle(tester);

    final orderScreen = find.byType(CreditOrderScreen);
    await tester.enterText(
        find
            .descendant(of: orderScreen, matching: find.byType(TextField))
            .first,
        'Integration Test Customer');
    await settle(tester);

    await tester.tap(find.descendant(
        of: orderScreen, matching: find.text('Select Items →')));
    await settle(tester);

    final productScreen = find.byType(CreditProductScreen);

    // Filter down to the target product so repeated taps can't land on a
    // different card.
    await tester.enterText(
        find
            .descendant(of: productScreen, matching: find.byType(TextField))
            .first,
        original.name);
    await settle(tester);

    // Match only the product card's Text widget, not the EditableText of
    // the search field we just typed this same name into.
    Finder productCard() => find.descendant(
        of: productScreen,
        matching: find
            .byWidgetPredicate((w) => w is Text && w.data == original.name));
    expect(productCard(), findsOneWidget);

    // Stock is 10 — tap well past that to confirm the fix caps the order
    // instead of letting it go negative.
    for (var i = 0; i < 15; i++) {
      await tester.tap(productCard());
      await settle(tester);
    }

    // Sanity check: the on-screen quantity counter should read exactly the
    // capped stock value before we proceed.
    expect(find.descendant(of: productScreen, matching: find.text('10')),
        findsWidgets,
        reason: 'quantity should have been capped at the available stock (10)');

    // Step 2's "Save Credit →" only navigates to the summary screen — the
    // actual save (and credit-limit check) happens when that screen's own
    // "Save Credit" button is tapped.
    final saveCreditStep2 = find.descendant(
        of: productScreen, matching: find.textContaining('Save Credit →'));
    await tester.ensureVisible(saveCreditStep2);
    await settle(tester);
    await tester.tap(saveCreditStep2);
    await settle(tester);

    final summaryScreen = find.byType(CreditSummaryScreen);
    final saveCreditSummary =
        find.descendant(of: summaryScreen, matching: find.text('Save Credit'));
    await tester.ensureVisible(saveCreditSummary);
    await settle(tester);
    await tester.tap(saveCreditSummary);
    await settle(tester, pumps: 10);

    // 10 units x 60 pesos = 600, over the new customer's default 500 limit.
    expect(find.text('Credit Limit Exceeded'), findsOneWidget,
        reason:
            'ordering 10 x a 60-peso item (₱600) should trip the 500-peso default credit limit warning');

    await tester.tap(find.text('Proceed'));
    await settle(tester, pumps: 10);

    expect(
        find.descendant(
            of: summaryScreen, matching: find.text('Credit saved!')),
        findsOneWidget);

    final afterOrder = prov.products.firstWhere((p) => p.id == original.id);
    expect(afterOrder.stock, 0,
        reason:
            'stock should be depleted to exactly zero, never negative, even though 15 taps were attempted against 10 units');

    // Clean up: void the created credit sale (restores stock, cancels the
    // debt, reverses loyalty points — exercising that fix too), remove the
    // test customer, and restore the product's original stock/price. Found
    // by diffing sales rather than matching by customer name, since stray
    // "Integration Test Customer" rows may exist from earlier failed runs.
    final createdSale =
        prov.sales.firstWhere((s) => !salesBefore.contains(s.id));
    final testCustomerId = createdSale.customerId!;
    await prov.voidSale(createdSale);
    await settle(tester);
    await prov.deleteCustomer(testCustomerId);
    await settle(tester);
    await prov.updateProduct(prov.products
        .firstWhere((p) => p.id == original.id)
        .copyWith(stock: original.stock, sellPrice: original.sellPrice));
    await settle(tester);

    expect(prov.debts.where((d) => d.saleId == createdSale.id), isEmpty,
        reason: 'voiding the credit sale should have cancelled its debt');
    ErrorWidget.builder = defaultErrorBuilder;
  });
}
