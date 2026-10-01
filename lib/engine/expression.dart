import 'dart:math' as math;

class CalculationException implements Exception {
  const CalculationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A small, bounded mathematical parser. No eval, network or code execution.
class ExpressionEngine {
  const ExpressionEngine();

  double evaluate(String input, {double answer = 0, bool degrees = true}) {
    if (input.length > 512) {
      throw const CalculationException('Выражение слишком длинное');
    }
    final normalized = input
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-')
        .replaceAll(',', '.')
        .replaceAll('π', 'pi')
        .replaceAll('√', 'sqrt');
    final parser = _Parser(normalized, answer, degrees);
    final value = parser.parse().value();
    if (!value.isFinite) {
      throw const CalculationException('Результат за пределами диапазона');
    }
    return value == 0 ? 0 : value;
  }

  static String format(double value, {bool grouped = false}) {
    if (!value.isFinite) return '—';
    if (value == 0) return '0';
    var result = value.toStringAsPrecision(12);
    final parts = result.split('e');
    if (parts[0].contains('.')) {
      parts[0] = parts[0].replaceFirst(RegExp(r'0+$'), '');
      parts[0] = parts[0].replaceFirst(RegExp(r'\.$'), '');
    }
    if (parts.length == 2) return '${parts[0]}e${parts[1]}';
    result = parts[0];
    if (grouped) {
      final decimal = result.split('.');
      decimal[0] = decimal[0].replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]}\u2009',
      );
      result = decimal.join('.');
    }
    return result;
  }
}

abstract class _Node {
  double value();
}

class _Number extends _Node {
  _Number(this.number);
  final double number;
  @override
  double value() => number;
}

class _Percent extends _Node {
  _Percent(this.child);
  final _Node child;
  @override
  double value() => child.value() / 100;
}

class _Unary extends _Node {
  _Unary(this.operator, this.child);
  final String operator;
  final _Node child;
  @override
  double value() => operator == '-' ? -child.value() : child.value();
}

class _Binary extends _Node {
  _Binary(this.operator, this.left, this.right);
  final String operator;
  final _Node left;
  final _Node right;
  @override
  double value() {
    final a = left.value();
    var b = right.value();
    // Familiar calculator semantics: 200 + 10% = 220.
    if ((operator == '+' || operator == '-') && right is _Percent) b *= a;
    switch (operator) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '*':
        return a * b;
      case '/':
        if (b == 0) {
          throw const CalculationException('На ноль делить нельзя');
        }
        return a / b;
      case '^':
        return math.pow(a, b).toDouble();
      default:
        throw const CalculationException('Неизвестная операция');
    }
  }
}

class _Function extends _Node {
  _Function(this.name, this.child, this.degrees);
  final String name;
  final _Node child;
  final bool degrees;
  @override
  double value() {
    final x = child.value();
    final angle = degrees ? x * math.pi / 180 : x;
    switch (name) {
      case 'sin':
        return math.sin(angle);
      case 'cos':
        return math.cos(angle);
      case 'tan':
        if (math.cos(angle).abs() < 1e-12) {
          throw const CalculationException('Тангенс здесь не определён');
        }
        return math.tan(angle);
      case 'sqrt':
        if (x < 0) {
          throw const CalculationException('Нужен неотрицательный корень');
        }
        return math.sqrt(x);
      case 'ln':
      case 'log':
        if (x <= 0) {
          throw const CalculationException('Логарифм ждёт число больше нуля');
        }
        return name == 'ln' ? math.log(x) : math.log(x) / math.ln10;
      case 'abs':
        return x.abs();
      case 'exp':
        return math.exp(x);
      case '!':
        if (x < 0 || x > 170 || x != x.truncateToDouble()) {
          throw const CalculationException(
            'Факториал: целое число от 0 до 170',
          );
        }
        var result = 1.0;
        for (var i = 2; i <= x; i++) {
          result *= i;
        }
        return result;
      default:
        throw const CalculationException('Неизвестная функция');
    }
  }
}

class _Parser {
  _Parser(String input, this.answer, this.degrees) {
    var offset = 0;
    final pattern = RegExp(
      r'(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?|[a-zA-Z]+|[+\-*/^()%!]',
    );
    while (offset < input.length) {
      if (input[offset].trim().isEmpty) {
        offset++;
        continue;
      }
      final match = pattern.matchAsPrefix(input, offset);
      if (match == null) {
        throw const CalculationException(
          'Используйте числа и математические операции',
        );
      }
      tokens.add(match.group(0)!.toLowerCase());
      offset = match.end;
    }
  }

  final double answer;
  final bool degrees;
  final List<String> tokens = [];
  int position = 0;
  String get current => position < tokens.length ? tokens[position] : '';
  bool consume(String value) {
    if (current != value) return false;
    position++;
    return true;
  }

  _Node parse() {
    if (tokens.isEmpty) throw const CalculationException('Введите выражение');
    final node = sum();
    if (position != tokens.length) {
      throw const CalculationException('Проверьте скобки и операции');
    }
    return node;
  }

  _Node sum() {
    var node = product();
    while (current == '+' || current == '-') {
      final operator = tokens[position++];
      node = _Binary(operator, node, product());
    }
    return node;
  }

  _Node product() {
    var node = unary();
    while (true) {
      if (current == '*' || current == '/') {
        final operator = tokens[position++];
        node = _Binary(operator, node, unary());
      } else if (current == '(' || RegExp(r'^[a-z]+$').hasMatch(current)) {
        node = _Binary('*', node, unary());
      } else {
        return node;
      }
    }
  }

  _Node unary() {
    if (current == '+' || current == '-') {
      final operator = tokens[position++];
      return _Unary(operator, unary());
    }
    return power();
  }

  _Node power() {
    final node = postfix();
    if (consume('^')) return _Binary('^', node, unary());
    return node;
  }

  _Node postfix() {
    var node = primary();
    while (current == '%' || current == '!') {
      node = consume('%')
          ? _Percent(node)
          : _Function(tokens[position++], node, degrees);
    }
    return node;
  }

  _Node primary() {
    if (consume('(')) {
      final node = sum();
      if (!consume(')')) {
        throw const CalculationException('Закройте скобку');
      }
      return node;
    }
    if (current.isEmpty) {
      throw const CalculationException('Допишите выражение');
    }
    final token = tokens[position++];
    final number = double.tryParse(token);
    if (number != null) return _Number(number);
    if (token == 'pi') return _Number(math.pi);
    if (token == 'e') return _Number(math.e);
    if (token == 'ans') return _Number(answer);
    const functions = {'sin', 'cos', 'tan', 'sqrt', 'ln', 'log', 'abs', 'exp'};
    if (functions.contains(token)) {
      if (!consume('(')) {
        throw const CalculationException('После функции нужна скобка');
      }
      final node = sum();
      if (!consume(')')) {
        throw const CalculationException('Закройте скобку');
      }
      return _Function(token, node, degrees);
    }
    throw const CalculationException('Проверьте выражение');
  }
}
