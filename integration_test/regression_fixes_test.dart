// Drives the real, compiled app on the Windows desktop target to verify the
// two money/inventory-integrity bugs fixed together:
//  1. Oversell: a stale cart/credit-order/installment item list must be
//     rejected at the moment of writing if stock moved out from under it,
//     not clamp stock to zero and record the sale anyway.
//  2. Installment void guard: deleting an installment plan that already
//     collected a monthly payment (not just the down payment) must be
//     refused, not silently void the sale and erase the collected cash.
//
// Run with:
//   flutter test integration_test/regression_fixes_test.dart -d windows
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:store_ph/providers/app_provider.dart';
import 'package:store_ph/models/transaction.dart';
import 'package:store_ph/screens/sales_screen.dart';
import 'package:store_ph/screens/installment_screen.dart';
import 'package:store_ph/services/installment_service.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final defaultErrorBuilder = ErrorWidget.builder;
  tearDown(() => ErrorWidget.builder = defaultErrorBuilder);

  testWidgets(
      'completeSale rejects a stale cart when a rival sale already sold out the stock',
      (tester) async {
    final prov = await bootToHome(tester);

    await goToTab(tester, 'Sales');
    final salesScreen = find.byType(SalesScreen);

    expect(prov.products, isNotEmpty);
    final original = prov.products.first;
    await prov.updateProduct(original.copyWith(stock: 2));
    await settle(tester);

    Finder productCard() =>
        find.descendant(of: salesScreen, matching: find.text(original.name));
    await tester.tap(productCard());
    await tester.pump();
    await tester.tap(productCard());
    await tester.pump();
    expect(prov.cart.values.first, 2,
        reason: 'cart should hold both remaining units before the race');

    // Simulate a second, independent sale draining the same stock while
    // this cart sits open (e.g. a credit order for a different customer).
    final rivalCustomer =
        await prov.addCustomer('Integration Test Oversell Customer');
    final rivalSale = await prov.completeSaleWithItems(
      items: [
        {
          'product': prov.products.firstWhere((p) => p.id == original.id),
          'qty': 2,
        }
      ],
      cashPaid: 0,
      creditAmount: 120,
      customer: rivalCustomer,
    );
    await settle(tester);
    expect(prov.products.firstWhere((p) => p.id == original.id).stock, 0,
        reason: 'rival sale should have depleted stock to zero');

    // The stale cart still thinks it holds 2 units — completing it now must
    // be rejected instead of silently overselling (adjustProductStock would
    // otherwise clamp 0-2 to 0 with no error, recording a phantom sale).
    await expectLater(
      prov.completeSale(cashPaid: 120, creditAmount: 0, type: PaymentType.cash),
      throwsA(isA<InsufficientStockException>()),
    );
    await settle(tester);

    // Cart must be left untouched (not cleared) so the cashier can adjust,
    // and stock must not have moved any further from the rejected attempt.
    expect(prov.cart.values.first, 2);
    expect(prov.products.firstWhere((p) => p.id == original.id).stock, 0);

    // Clean up.
    prov.clearCart();
    await prov.voidSale(rivalSale!);
    await settle(tester);
    await prov.deleteCustomer(rivalCustomer.id);
    await settle(tester);
    await prov.updateProduct(prov.products
        .firstWhere((p) => p.id == original.id)
        .copyWith(stock: original.stock));
    await settle(tester);
    ErrorWidget.builder = defaultErrorBuilder;
  });

  testWidgets(
      'deleting an installment plan after a payment is collected is refused instead of erasing it',
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
        'Integration Test Void Guard ${DateTime.now().millisecondsSinceEpoch}';
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
    final pickerSheet = find.byType(DraggableScrollableSheet);
    await tester.tap(
        find.descendant(of: pickerSheet, matching: find.byIcon(Icons.add)));
    await settle(tester);

    final doneBtn = find.textContaining('Done (');
    await tester.tap(doneBtn);
    await settle(tester);

    await tester.ensureVisible(find.text('Save Installment'));
    await settle(tester);
    await tester.tap(find.text('Save Installment'));
    await settle(tester, pumps: 10);
    expect(find.text('Installment saved!'), findsOneWidget);
    await settle(tester);

    final nameInCard =
        find.descendant(of: instScreen, matching: find.text(customerName));
    expect(nameInCard, findsOneWidget);
    final cardContainer =
        find.ancestor(of: nameInCard, matching: find.byType(Container)).first;

    var saved = (await InstallmentService.instance.getAll())
        .firstWhere((i) => i.customerName == customerName);
    final saleId = saved.saleId!;
    final stockBeforePayment =
        prov.products.firstWhere((p) => p.id == product.id).stock;

    // Record one payment — this is the state the reported bug hit: an
    // "ongoing" plan (not yet fully paid off) that has nonetheless already
    // collected real cash beyond the down payment.
    final payBtn = find.descendant(
        of: cardContainer, matching: find.textContaining('Pay — '));
    await tester.tap(payBtn);
    await settle(tester);
    await tester.tap(find.textContaining('Pay ₱'));
    await settle(tester, pumps: 10);

    saved = (await InstallmentService.instance.getAll())
        .firstWhere((i) => i.customerName == customerName);
    expect(saved.paidMonths, 1);

    // Attempt to delete the plan through the real UI flow.
    await tester.tap(find.descendant(
        of: cardContainer, matching: find.byIcon(Icons.more_vert_outlined)));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await tester.tap(find.text('Delete').last);
    await settle(tester, pumps: 10);

    // The fix: this must now be refused, not silently deleted.
    expect(find.textContaining('Cannot void'), findsOneWidget,
        reason:
            'deleting a plan with a collected payment must show the void-guard error, not succeed silently');

    final stillThere = (await InstallmentService.instance.getAll())
        .where((i) => i.customerName == customerName)
        .toList();
    expect(stillThere, hasLength(1),
        reason: 'the installment record must survive a blocked delete');

    final saleAfter = prov.sales.firstWhere((s) => s.id == saleId);
    expect(saleAfter.isVoided, isFalse,
        reason: 'the underlying sale must not have been voided');
    expect(
        prov.products.firstWhere((p) => p.id == product.id).stock,
        stockBeforePayment,
        reason: 'stock must not have been restored for a blocked void');

    // Clean up: delete the plan record directly (bypassing the now-correct
    // UI guard, same as deleteCustomer's cascade does), which removes the
    // one thing blocking voidSale, then void the sale for real to restore
    // stock and reverse revenue.
    await InstallmentService.instance.delete(stillThere.first.id);
    await prov.voidSale(saleAfter);
    await settle(tester);
    expect(prov.products.firstWhere((p) => p.id == product.id).stock,
        stockBeforePayment + saleAfter.items.first.quantity);

    final testCustomers = prov.customers
        .where((c) => c.name.startsWith('Integration Test Void Guard'))
        .toList();
    for (final c in testCustomers) {
      await prov.deleteCustomer(c.id);
    }
    await settle(tester);
    ErrorWidget.builder = defaultErrorBuilder;
  });
}
