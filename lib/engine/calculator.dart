import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'expression.dart';

class HistoryEntry {
  const HistoryEntry(this.expression, this.result, this.timestamp);
  final String expression;
  final double result;
  final DateTime timestamp;

  Map<String, Object> toJson() => {
    'expression': expression,
    'result': result,
    'time': timestamp.toIso8601String(),
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    json['expression'] as String,
    (json['result'] as num).toDouble(),
    DateTime.parse(json['time'] as String),
  );
}

class Calculator extends ChangeNotifier {
  Calculator({SharedPreferences? preferences}) : _preferences = preferences {
    flavor = _preferences?.getInt('flavor') ?? 0;
    if (flavor < 0 || flavor > 2) flavor = 0;
    gentleMotion = _preferences?.getBool('gentleMotion') ?? false;
    degrees = _preferences?.getBool('degrees') ?? true;
    try {
      final saved =
          jsonDecode(_preferences?.getString('history') ?? '[]') as List;
      history.addAll(
        saved
            .take(80)
            .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>)),
      );
    } catch (_) {
      // A damaged history must never prevent opening the calculator.
    }
  }

  final SharedPreferences? _preferences;
  final ExpressionEngine engine = const ExpressionEngine();
  final List<HistoryEntry> history = [];
  String expression = '';
  String? error;
  String? storageError;
  double answer = 0;
  double? memory;
  bool evaluated = false;
  bool degrees = true;
  bool scientific = false;
  bool gentleMotion = false;
  int flavor = 0;
  int resultRevision = 0;
  Future<void> _saveQueue = Future.value();

  double? get preview {
    if (expression.isEmpty) return 0;
    try {
      return engine.evaluate(expression, answer: answer, degrees: degrees);
    } on CalculationException {
      return null;
    }
  }

  String get resultText =>
      ExpressionEngine.format(preview ?? answer, grouped: true);
  bool get _endsOperand =>
      RegExp(r'[0-9)%!πe]$').hasMatch(expression) || expression.endsWith('Ans');
  bool get _endsOperator => RegExp(r'[+−×÷^]$').hasMatch(expression);

  void _update() {
    error = null;
    notifyListeners();
  }

  void input(String token) {
    if (expression.length >= 500) return;
    const operators = {'+', '−', '×', '÷', '^'};
    if (evaluated) {
      if (!operators.contains(token) &&
          token != '%' &&
          token != '!' &&
          token != ')') {
        expression = '';
      }
      evaluated = false;
    }
    if (operators.contains(token)) {
      if (expression.isEmpty) {
        if (token == '−') expression = token;
      } else if (_endsOperator) {
        if (token == '−' && !expression.endsWith('−')) {
          expression += token;
        } else {
          expression = expression.substring(0, expression.length - 1) + token;
        }
      } else {
        expression += token;
      }
    } else if (token == '.') {
      final last =
          RegExp(r'(\d*\.?\d*)$').firstMatch(expression)?.group(0) ?? '';
      if (!last.contains('.')) {
        if (last.isEmpty && _endsOperand) expression += '×';
        expression += last.isEmpty ? '0.' : '.';
      }
    } else if (token == ')') {
      final opened = '('.allMatches(expression).length;
      final closed = ')'.allMatches(expression).length;
      if (opened > closed && _endsOperand) expression += ')';
    } else if (token == '%' || token == '!') {
      if (_endsOperand) expression += token;
    } else {
      if (expression.endsWith(')') ||
          expression.endsWith('%') ||
          expression.endsWith('!') ||
          expression.endsWith('π') ||
          expression.endsWith('Ans') ||
          expression.endsWith('e')) {
        expression += '×';
      } else if (token == '(' && _endsOperand) {
        expression += '×';
      }
      expression += token;
    }
    _update();
  }

  void function(String name) {
    if (evaluated) {
      expression = '$name($expression)';
      evaluated = false;
    } else {
      if (_endsOperand) expression += '×';
      expression += '$name(';
    }
    _update();
  }

  void clear() {
    expression = '';
    evaluated = false;
    _update();
  }

  void backspace() {
    if (expression.isNotEmpty) {
      final function = RegExp(
        r'(sin|cos|tan|sqrt|ln|log|abs|exp)\($',
      ).firstMatch(expression);
      expression = expression.substring(
        0,
        function?.start ?? expression.length - 1,
      );
    }
    evaluated = false;
    _update();
  }

  void negate() {
    if (expression.isEmpty) {
      expression = '−';
    } else {
      final last = RegExp(
        r'(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?$',
      ).firstMatch(expression);
      if (last != null) {
        expression =
            '${expression.substring(0, last.start)}(−${last.group(0)})';
      } else if (expression.endsWith(')')) {
        var depth = 0;
        var start = expression.length - 1;
        for (; start >= 0; start--) {
          if (expression[start] == ')') depth++;
          if (expression[start] == '(') depth--;
          if (depth == 0) break;
        }
        if (start >= 0) {
          final function = RegExp(
            r'[a-z]+$',
          ).firstMatch(expression.substring(0, start));
          if (function != null) start = function.start;
          final atom = expression.substring(start);
          final inverted = atom.startsWith('(−')
              ? atom.substring(2, atom.length - 1)
              : '(−$atom)';
          expression = expression.substring(0, start) + inverted;
        }
      } else if (_endsOperand) {
        final last = RegExp(r'(π|Ans|e)$').firstMatch(expression);
        if (last != null) {
          expression =
              '${expression.substring(0, last.start)}(−${last.group(0)})';
        }
      }
    }
    evaluated = false;
    _update();
  }

  bool equals() {
    if (expression.isEmpty || evaluated) return false;
    try {
      final value = engine.evaluate(
        expression,
        answer: answer,
        degrees: degrees,
      );
      history.insert(0, HistoryEntry(expression, value, DateTime.now()));
      if (history.length > 80) history.removeLast();
      answer = value;
      expression = ExpressionEngine.format(value);
      evaluated = true;
      resultRevision++;
      error = null;
      _saveHistory();
      notifyListeners();
      return true;
    } on CalculationException catch (exception) {
      error = exception.message;
      notifyListeners();
      return false;
    }
  }

  void paste(String value) {
    final candidate = value
        .trim()
        .replaceAll('\u2009', '')
        .replaceAll('\u00a0', '');
    if (candidate.isEmpty) return;
    if (candidate.length > 500) {
      error = 'Выражение слишком длинное';
    } else {
      expression = candidate
          .replaceAll('*', '×')
          .replaceAll('/', '÷')
          .replaceAll('-', '−')
          .replaceAll(',', '.');
      evaluated = false;
      error = null;
    }
    notifyListeners();
  }

  void recall(HistoryEntry entry) {
    expression = entry.expression;
    evaluated = false;
    _update();
  }

  void clearHistory() {
    history.clear();
    _saveHistory();
    notifyListeners();
  }

  void changeFlavor(int value) {
    flavor = value;
    _save(() async {
      await _preferences?.setInt('flavor', value);
    });
    notifyListeners();
  }

  void toggleMotion() {
    gentleMotion = !gentleMotion;
    final value = gentleMotion;
    _save(() async {
      await _preferences?.setBool('gentleMotion', value);
    });
    notifyListeners();
  }

  void toggleDegrees() {
    degrees = !degrees;
    final value = degrees;
    _save(() async {
      await _preferences?.setBool('degrees', value);
    });
    _update();
  }

  void toggleScientific() {
    scientific = !scientific;
    notifyListeners();
  }

  void memoryAction(String action) {
    switch (action) {
      case 'MC':
        memory = null;
      case 'MR':
        if (memory != null) {
          final number = ExpressionEngine.format(memory!);
          if (evaluated || expression.isEmpty) {
            expression = number;
          } else {
            final trailing = RegExp(
              r'(?:\d+(?:\.\d*)?|\.\d+)(?:e[+−-]?\d+)?$',
            ).firstMatch(expression);
            if (trailing != null) {
              expression = expression.substring(0, trailing.start) + number;
            } else {
              if (_endsOperand) expression += '×';
              expression += number;
            }
          }
          evaluated = false;
          error = null;
        }
      case 'M+':
        memory = (memory ?? 0) + (preview ?? answer);
      case 'M−':
        memory = (memory ?? 0) - (preview ?? answer);
    }
    notifyListeners();
  }

  void _saveHistory() {
    final payload = jsonEncode(history.map((e) => e.toJson()).toList());
    _save(() async {
      await _preferences?.setString('history', payload);
    });
  }

  void _save(Future<void> Function() operation) {
    _saveQueue = _saveQueue.then((_) async {
      try {
        await operation();
      } catch (_) {
        storageError = 'Не удалось сохранить настройки';
        notifyListeners();
      }
    });
  }
}
