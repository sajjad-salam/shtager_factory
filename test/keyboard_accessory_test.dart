import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shtager/ui.dart';

void main() {
  test('triple-zero shortcut inserts at the caret', () {
    final controller = TextEditingController(text: '10')
      ..selection = const TextSelection.collapsed(offset: 2);
    addTearDown(controller.dispose);

    appendTripleZeroTo(controller);

    expect(controller.text, '10000');
    expect(controller.selection.baseOffset, 5);
  });

  test('triple-zero shortcut replaces the selected digits', () {
    final controller = TextEditingController(text: '12500')
      ..selection = const TextSelection(baseOffset: 2, extentOffset: 5);
    addTearDown(controller.dispose);

    appendTripleZeroTo(controller);

    expect(controller.text, '12000');
    expect(controller.selection.baseOffset, 5);
  });

  testWidgets(
    'numeric accessory and bottom action stay available with keyboard',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      addTearDown(
        () => NumericKeyboardController.instance.deactivate(controller),
      );
      addTearDown(() => tester.view.resetViewInsets());

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => NumericKeyboardAccessoryHost(
            child: child ?? const SizedBox.shrink(),
          ),
          home: Scaffold(
            body: NumericKeyboardTarget(
              controller: controller,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
              ),
            ),
            bottomNavigationBar: const KeyboardSafeActionBar(
              child: Text('حفظ'),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '10');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();

      expect(find.text('+000'), findsOneWidget);
      expect(find.text('حفظ'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text('حفظ')).dy,
        lessThan(tester.getTopLeft(find.text('+000')).dy),
      );

      await tester.tap(find.text('+000'));
      await tester.pump();
      expect(controller.text, '10000');
    },
  );
}
