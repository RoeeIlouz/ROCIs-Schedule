import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/shared/widgets/bouncy_checkbox.dart';

void main() {
  group('BouncyCheckbox Component Tests', () {
    testWidgets('renders unchecked state properly', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BouncyCheckbox(
                isChecked: false,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(BouncyCheckbox), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);

      await tester.tap(find.byType(BouncyCheckbox));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tapped, isTrue);
    });

    testWidgets('renders checked state with check icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BouncyCheckbox(
                isChecked: true,
                onTap: () {},
                activeColor: Colors.deepPurple,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(BouncyCheckbox), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });
}
