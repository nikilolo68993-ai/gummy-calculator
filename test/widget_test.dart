import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gummy_calculator/engine/calculator.dart';
import 'package:gummy_calculator/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await font.load();
  });
  testWidgets('Keyboard entry, calculation and recovery work in the real UI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1180, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calc = Calculator()..gentleMotion = true;
    await tester.pumpWidget(GummyApp(calculator: calc));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2, character: '2');
    await tester.sendKeyEvent(LogicalKeyboardKey.equal, character: '+');
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3, character: '3');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calc.answer, 5);
    expect(find.byKey(const ValueKey('result')), findsOneWidget);
    expect(find.text('Красиво получилось.'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(calc.expression, '');
    expect(tester.takeException(), null);
  });

  testWidgets('Desktop, compact and scientific layouts do not overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calc = Calculator()..gentleMotion = true;
    for (final size in [
      const Size(1180, 860),
      const Size(860, 740),
      const Size(460, 720),
      const Size(390, 740),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(GummyApp(calculator: calc));
      await tester.pumpAndSettle();
      expect(tester.takeException(), null, reason: '$size basic');
      calc.toggleScientific();
      await tester.pumpAndSettle();
      expect(tester.takeException(), null, reason: '$size scientific');
      calc.toggleScientific();
      await tester.pumpAndSettle();
    }
  });
}
