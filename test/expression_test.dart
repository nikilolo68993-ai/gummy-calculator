import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gummy_calculator/engine/expression.dart';

void main() {
  const engine = ExpressionEngine();
  group('Mathematical precedence and actual edge cases', () {
    const cases = {
      '2+3×4': 14.0,
      '(2+3)×4': 20.0,
      '12÷4×2': 6.0,
      '2^3^2': 512.0,
      '−2^2': -4.0,
      '(−2)^2': 4.0,
      '2^−3': 0.125,
      '2(3+4)': 14.0,
      '200+10%': 220.0,
      '200−10%': 180.0,
      '200×10%': 20.0,
      '200+10%+10%': 242.0,
      '10%': 0.1,
      'sqrt(144)': 12.0,
      '5!': 120.0,
      '0!': 1.0,
      'log(1000)': 3.0,
      'ln(e)': 1.0,
      'sin(30)': 0.5,
      'cos(60)': 0.5,
      'tan(45)': 1.0,
      'abs(−17)': 17.0,
      '1,5+2,5': 4.0,
      '1e−5×100000': 1.0,
      '3×−2': -6.0,
    };
    for (final entry in cases.entries) {
      test(
        entry.key,
        () => expect(engine.evaluate(entry.key), closeTo(entry.value, 1e-10)),
      );
    }
    test('Radians and constants', () {
      expect(engine.evaluate('sin(pi/2)', degrees: false), closeTo(1, 1e-12));
      expect(engine.evaluate('2π'), closeTo(2 * math.pi, 1e-12));
      expect(engine.evaluate('Ans+2', answer: 10), 12);
    });
    test('Readable decimal output', () {
      expect(ExpressionEngine.format(engine.evaluate('0.1+0.2')), '0.3');
      expect(
        ExpressionEngine.format(1234567.5, grouped: true),
        '1\u2009234\u2009567.5',
      );
      expect(ExpressionEngine.format(-0.0), '0');
    });
  });

  group('Invalid expressions fail predictably', () {
    for (final value in [
      '1/0',
      'sqrt(-1)',
      'ln(0)',
      'tan(90)',
      '171!',
      '2.5!',
      '(2+3',
      '1+',
      'wat(2)',
      '2..3',
      '9^999',
      'a;',
      '',
    ]) {
      test(
        value,
        () => expect(
          () => engine.evaluate(value),
          throwsA(isA<CalculationException>()),
        ),
      );
    }
    test(
      'Bounded pasted input',
      () => expect(
        () => engine.evaluate('1' * 513),
        throwsA(isA<CalculationException>()),
      ),
    );
  });
}
