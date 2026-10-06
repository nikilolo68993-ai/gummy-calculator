import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gummy_calculator/engine/calculator.dart';
import 'package:gummy_calculator/main.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await font.load();
  });

  void expectIdle(WidgetTester tester) {
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
  }

  testWidgets('Normal motion stops scheduling frames while idle', (tester) async {
    tester.view.physicalSize = const Size(1180, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calc = Calculator();
    addTearDown(calc.dispose);
    await tester.pumpWidget(GummyApp(calculator: calc));
    await tester.pumpAndSettle(timeout: const Duration(seconds: 4));
    expectIdle(tester);

    calc.paste('2+3');
    await tester.pumpAndSettle(timeout: const Duration(seconds: 4));
    await tester.tap(find.byKey(const ValueKey('key-=')));
    await tester.pump();
    expect(calc.answer, 5);
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpAndSettle(timeout: const Duration(seconds: 4));
    expectIdle(tester);

    calc.changeFlavor(1);
    calc.toggleScientific();
    await tester.pumpAndSettle(timeout: const Duration(seconds: 4));
    expectIdle(tester);
    await tester.pump(const Duration(seconds: 2));
    expectIdle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Jelly keys still squash and recover without an idle loop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(460, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calc = Calculator();
    addTearDown(calc.dispose);
    await tester.pumpWidget(GummyApp(calculator: calc));
    await tester.pumpAndSettle(timeout: const Duration(seconds: 4));
    final button = find.byKey(const ValueKey('key-2'));
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final transforms = find.descendant(
      of: button,
      matching: find.byType(Transform),
    );
    final matrix = tester.widget<Transform>(transforms.last).transform;
    expect(matrix.entry(1, 1), lessThan(0.99));
    await gesture.up();
    await tester.pumpAndSettle(timeout: const Duration(seconds: 4));
    expect(calc.expression, '2');
    expectIdle(tester);
    expect(tester.takeException(), isNull);
  });
}
