import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_ph/screens/inventory_screen.dart';

// "Clear Products" wraps to two lines on narrow phones; the fixed-height tile
// used to overflow by 8 px. A RenderFlex overflow is reported as an exception.
void main() {
  for (final scale in [1.0, 1.3]) {
    testWidgets('two-line tool tile fits at ${scale}x text', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Center(
            child: SizedBox(
              width: 72,
              child: inventoryToolTile(
                icon: Icons.delete_sweep_outlined,
                label: 'Clear Products',
                color: Colors.red,
                bg: Colors.white,
                border: Colors.red,
              ),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('Clear Products'), findsOneWidget);
    });
  }
}
