import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k_store/core/widgets/pressable_card.dart';

void main() {
  testWidgets('PressableCard tap and scale test', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PressableCard(
              onTap: () {
                tapped = true;
              },
              child: const Text('Press Me'),
            ),
          ),
        ),
      ),
    );

    // Verify child is rendered
    expect(find.text('Press Me'), findsOneWidget);

    // Tap the PressableCard
    await tester.tap(find.text('Press Me'));
    await tester.pumpAndSettle();

    // Verify onTap was triggered
    expect(tapped, isTrue);
  });
}
