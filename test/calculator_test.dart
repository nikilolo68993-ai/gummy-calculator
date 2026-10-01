import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gummy_calculator/engine/calculator.dart';

void main() {
  test('Sign changes affect the last operand and Ans survives clear', () {
    final c = Calculator();
    c.paste('5+2');
    c.negate();
    expect(c.preview, 3);
    c.negate();
    expect(c.preview, 7);
    c.equals();
    c.clear();
    c.input('Ans');
    expect(c.preview, 7);
    c.clear();
    c.input('π');
    c.input('2');
    expect(c.expression, 'π×2');
  });

  test(
    'Memory recall replaces the current number rather than joining digits',
    () {
      final c = Calculator();
      c.paste('42');
      c.memoryAction('M+');
      c.paste('5+17');
      c.memoryAction('MR');
      expect(c.expression, '5+42');
      expect(c.preview, 47);
    },
  );
  test('Results can continue an operation or start a fresh number', () {
    final c = Calculator();
    c.input('2');
    c.input('+');
    c.input('3');
    expect(c.equals(), true);
    expect(c.answer, 5);
    c.input('×');
    c.input('4');
    c.equals();
    expect(c.answer, 20);
    c.input('7');
    expect(c.expression, '7');
    expect(c.history.length, 2);
    expect(c.equals(), true);
    expect(c.equals(), false);
    expect(c.history.length, 3);
  });

  test('Decimal input and negative factors remain valid', () {
    final c = Calculator();
    for (final key in ['3', '×', '−', '2', '.', '.', '5']) {
      c.input(key);
    }
    expect(c.expression, '3×−2.5');
    expect(c.preview, -7.5);
  });

  test('Division error is recoverable', () {
    final c = Calculator();
    c.paste('1/0');
    expect(c.equals(), false);
    expect(c.error, 'На ноль делить нельзя');
    c.backspace();
    c.input('2');
    expect(c.error, null);
    expect(c.equals(), true);
    expect(c.answer, 0.5);
  });

  test('Scientific result, memory and history recall', () {
    final c = Calculator();
    c.paste('200 + 10%');
    c.equals();
    c.memoryAction('M+');
    c.clear();
    c.memoryAction('MR');
    expect(c.preview, 220);
    c.function('sqrt');
    c.clear();
    c.recall(c.history.first);
    expect(c.expression, '200 + 10%');
    expect(c.preview, 220);
    c.clearHistory();
    expect(c.history, isEmpty);
  });

  test('Preferences and history survive restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = Calculator(preferences: prefs);
    c.changeFlavor(2);
    c.toggleMotion();
    c.toggleDegrees();
    c.paste('6×7');
    c.equals();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final next = Calculator(preferences: prefs);
    expect(next.flavor, 2);
    expect(next.gentleMotion, true);
    expect(next.degrees, false);
    expect(next.history.single.result, 42);
  });
}
