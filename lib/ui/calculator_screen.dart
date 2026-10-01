import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../engine/calculator.dart';
import '../engine/expression.dart';
import 'flavor.dart';
import 'jelly_art.dart';
import 'jelly_button.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({
    super.key,
    required this.calculator,
    required this.desktop,
  });
  final Calculator calculator;
  final bool desktop;
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final FocusNode _keyboard = FocusNode(debugLabel: 'calculator keyboard');
  final Map<String, int> _pulses = {};
  int _pulse = 0;
  Calculator get calc => widget.calculator;
  Flavor get flavor => Flavor.all[calc.flavor];
  bool get gentle =>
      calc.gentleMotion || MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    calc.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    calc.removeListener(_changed);
    _keyboard.dispose();
    super.dispose();
  }

  void _activate(String key) {
    setState(() => _pulses[key] = ++_pulse);
    switch (key) {
      case 'AC':
        calc.clear();
      case '⌫':
        calc.backspace();
      case '=':
        calc.equals();
      case '±':
        calc.negate();
      case 'sin':
      case 'cos':
      case 'tan':
      case 'ln':
      case 'log':
      case 'abs':
        calc.function(key);
      case '√':
        calc.function('sqrt');
      case 'x²':
        calc.input('^');
        calc.input('2');
      case 'x^y':
        calc.input('^');
      case '1/x':
        calc.paste('1/(${calc.expression.isEmpty ? '1' : calc.expression})');
      case 'n!':
        calc.input('!');
      case 'MC':
      case 'MR':
      case 'M+':
      case 'M−':
        calc.memoryAction(key);
      default:
        calc.input(key);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final command =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (command) {
      if (key == LogicalKeyboardKey.keyC) {
        _copy();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyV) {
        _paste();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyH) {
        _historyDialog();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _activate('=');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _activate('⌫');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.delete) {
      _activate('AC');
      return KeyEventResult.handled;
    }
    final char = event.character;
    const map = {'*': '×', '/': '÷', '-': '−', ',': '.', '=': '='};
    if (char != null && RegExp(r'^[0-9.+\-*/(),%^!=]$').hasMatch(char)) {
      _activate(map[char] ?? char);
      return KeyEventResult.handled;
    }
    if (char?.toLowerCase() == 'p') {
      _activate('π');
      return KeyEventResult.handled;
    }
    if (char?.toLowerCase() == 'r') {
      _activate('√');
      return KeyEventResult.handled;
    }
    if (char?.toLowerCase() == 'a') {
      _activate('Ans');
      return KeyEventResult.handled;
    }
    if (char?.toLowerCase() == 's') {
      calc.toggleScientific();
      return KeyEventResult.handled;
    }
    if (char == '?') {
      _help();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(text: ExpressionEngine.format(calc.preview ?? calc.answer)),
    );
    if (mounted) _toast('Результат скопирован');
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (mounted && data?.text != null) calc.paste(data!.text!);
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 2),
        width: 300,
      ),
    );
  }

  Future<void> _help() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(
        'Всё под пальцами',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final pair in const [
              ('0–9  + − × ÷', 'Числа и операции'),
              ('Enter / =', 'Посчитать'),
              ('Backspace', 'Удалить символ'),
              ('Esc / Delete', 'Очистить'),
              ('Ctrl / ⌘ + C', 'Копировать результат'),
              ('Ctrl / ⌘ + V', 'Вставить выражение'),
              ('Ctrl / ⌘ + H', 'Открыть историю'),
              ('S · P · R · A', 'Наука · π · √ · Ans'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    SizedBox(
                      width: 145,
                      child: Text(
                        pair.$1,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        pair.$2,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Flavor.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            const Text(
              'Проценты: 200 + 10% = 220.\nНаучные функции используют DEG или RAD.\nНажмите запись в истории, чтобы вернуть выражение.',
              style: TextStyle(fontSize: 12, height: 1.8, color: Flavor.muted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Понятно'),
        ),
      ],
    ),
  );

  Future<void> _historyDialog() => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: SizedBox(
        width: 380,
        height: 600,
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: AnimatedBuilder(
            animation: calc,
            builder: (context, _) =>
                _history(onRecall: () => Navigator.pop(context)),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _keyboard,
    autofocus: true,
    onKeyEvent: _onKey,
    child: Scaffold(
      body: CandyBackground(
        flavor: flavor,
        gentle: gentle,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, bounds) {
              final compact = bounds.maxWidth < 760;
              final padding = compact ? 18.0 : 30.0;
              return Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  children: [
                    _topbar(compact),
                    SizedBox(height: compact ? 20 : 30),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, content) {
                          final roomy = content.maxWidth >= 1040;
                          final sideHistory = content.maxWidth >= 790;
                          final cardHeight = calc.scientific ? 798.0 : 666.0;
                          final height = math.max(
                            content.maxHeight,
                            cardHeight,
                          );
                          return SingleChildScrollView(
                            child: SizedBox(
                              height: height,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (roomy) ...[
                                    SizedBox(
                                      width: 240,
                                      height: math.min(height, 690),
                                      child: _intro(),
                                    ),
                                    const SizedBox(width: 30),
                                  ],
                                  Flexible(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 452,
                                      ),
                                      child: _calculatorCard(cardHeight),
                                    ),
                                  ),
                                  if (sideHistory) ...[
                                    const SizedBox(width: 30),
                                    SizedBox(
                                      width: roomy ? 252 : 270,
                                      height: math.min(height, 666),
                                      child: _history(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 17),
                    _bottomBar(compact),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _topbar(bool compact) => SizedBox(
    height: 44,
    child: Row(
      children: [
        if (widget.desktop)
          Expanded(child: DragToMoveArea(child: _brand(compact)))
        else
          Expanded(child: _brand(compact)),
        _iconButton(Icons.keyboard_alt_outlined, 'Горячие клавиши', _help),
        if (compact)
          _iconButton(Icons.history_rounded, 'История', _historyDialog),
        _iconButton(
          gentle
              ? Icons.motion_photos_off_rounded
              : Icons.motion_photos_on_rounded,
          gentle ? 'Включить анимации' : 'Уменьшить анимации',
          calc.toggleMotion,
        ),
        if (widget.desktop) ...[
          const SizedBox(width: 12),
          _windowButton(
            Icons.remove_rounded,
            'Свернуть',
            () => windowManager.minimize(),
          ),
          _windowButton(Icons.crop_square_rounded, 'Развернуть', () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          }),
          _windowButton(
            Icons.close_rounded,
            'Закрыть',
            () => windowManager.close(),
          ),
        ],
      ],
    ),
  );

  Widget _brand(bool compact) => Row(
    children: [
      JellyMascot(flavor: flavor, gentle: gentle, compact: true),
      const SizedBox(width: 9),
      const Text(
        'gummy',
        style: TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.4,
        ),
      ),
      Text(
        '.',
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: flavor.accent,
        ),
      ),
      if (!compact) ...[
        const SizedBox(width: 20),
        Container(
          width: 1,
          height: 18,
          color: Flavor.ink.withValues(alpha: 0.12),
        ),
        const SizedBox(width: 20),
        const Text(
          'МЯГКАЯ МАТЕМАТИКА',
          style: TextStyle(
            fontSize: 10,
            color: Flavor.muted,
            letterSpacing: 1.9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ],
  );

  Widget _windowButton(IconData icon, String label, VoidCallback onTap) =>
      SizedBox(width: 33, child: _iconButton(icon, label, onTap, size: 15));

  Widget _iconButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    double size = 20,
  }) => Tooltip(
    message: label,
    child: IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: size, color: Flavor.muted),
      visualDensity: VisualDensity.compact,
      splashRadius: 20,
    ),
  );

  Widget _intro() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 8),
      Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: flavor.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'A SOFTER WAY TO THINK',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.6,
                color: flavor.deep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      const FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          'Считай.\nСмакуй.',
          style: TextStyle(
            fontSize: 43,
            fontWeight: FontWeight.w800,
            letterSpacing: -2.5,
            height: 1.17,
          ),
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'Немного желе.\nМного возможностей.',
        style: TextStyle(fontSize: 14, height: 1.7, color: Flavor.muted),
      ),
      const SizedBox(height: 15),
      SizedBox(
        width: 210,
        height: 160,
        child: JellyMascot(
          flavor: flavor,
          gentle: gentle,
          revision: calc.resultRevision,
        ),
      ),
      const Spacer(),
      const Text(
        'ВЫБЕРИ СВОЙ ВКУС',
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 1.7,
          color: Flavor.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 17),
      _flavors(),
      const SizedBox(height: 15),
      AnimatedSwitcher(
        duration: gentle ? Duration.zero : const Duration(milliseconds: 250),
        child: Text(
          '${flavor.name} мармелад',
          key: ValueKey(flavor.name),
          style: const TextStyle(fontSize: 12, color: Flavor.muted),
        ),
      ),
      const SizedBox(height: 22),
      const Text(
        'Точная математика.\nМягкий характер.',
        style: TextStyle(fontSize: 11, color: Flavor.muted, height: 1.8),
      ),
      const SizedBox(height: 12),
    ],
  );

  Widget _flavors() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < Flavor.all.length; i++)
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Tooltip(
            message: Flavor.all[i].name,
            child: Semantics(
              label: '${Flavor.all[i].name} вкус',
              button: true,
              selected: calc.flavor == i,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => calc.changeFlavor(i),
                child: AnimatedContainer(
                  duration: gentle
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: calc.flavor == i
                          ? Flavor.all[i].accent
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Flavor.all[i].light, Flavor.all[i].accent],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Flavor.all[i].accent.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: calc.flavor == i
                        ? Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: Flavor.all[i].deep,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _calculatorCard(double height) => Container(
    height: height,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.57),
      borderRadius: BorderRadius.circular(40),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.94),
        width: 1.4,
      ),
      boxShadow: [
        BoxShadow(
          color: flavor.orb.withValues(alpha: 0.16),
          blurRadius: 50,
          offset: const Offset(0, 22),
          spreadRadius: -12,
        ),
        BoxShadow(
          color: Flavor.ink.withValues(alpha: 0.045),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      children: [
        _cardToolbar(),
        const SizedBox(height: 14),
        _display(),
        const SizedBox(height: 14),
        _memoryRow(),
        const SizedBox(height: 12),
        if (calc.scientific) ...[_scientificPad(), const SizedBox(height: 14)],
        Expanded(child: _keypad()),
        const SizedBox(height: 13),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: flavor.accent,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Нажми. Почувствуй. Посчитай.',
              style: TextStyle(
                fontSize: 9,
                color: flavor.deep.withValues(alpha: 0.7),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _cardToolbar() => SizedBox(
    height: 31,
    child: Row(
      children: [
        Icon(Icons.auto_awesome_rounded, size: 14, color: flavor.deep),
        const SizedBox(width: 7),
        Text(
          flavor.label,
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            color: flavor.deep,
          ),
        ),
        const Spacer(),
        Tooltip(
          message: 'Научные функции · S',
          child: InkWell(
            onTap: calc.toggleScientific,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: gentle
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: calc.scientific ? flavor.light : const Color(0xFFF0EBF3),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.functions_rounded,
                    size: 13,
                    color: calc.scientific ? flavor.deep : Flavor.muted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Наука',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: calc.scientific ? flavor.deep : Flavor.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _display() => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: AnimatedContainer(
        duration: gentle ? Duration.zero : const Duration(milliseconds: 350),
        height: 170,
        padding: const EdgeInsets.fromLTRB(20, 17, 20, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.8),
              flavor.light.withValues(alpha: 0.4),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Text(
                  calc.error != null
                      ? 'ОЙ, ПОПРОБУЕМ ЕЩЁ'
                      : calc.evaluated
                      ? 'ВОТ И ОТВЕТ'
                      : 'ТВОЁ ВЫРАЖЕНИЕ',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                    color: calc.error != null ? flavor.deep : Flavor.muted,
                  ),
                ),
                const Spacer(),
                if (calc.memory != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(
                      'M',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: flavor.deep,
                      ),
                    ),
                  ),
                Tooltip(
                  message: 'Копировать результат',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _copy,
                    child: const Padding(
                      padding: EdgeInsets.all(3),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 13,
                        color: Flavor.muted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 17),
            SizedBox(
              height: 24,
              child: SingleChildScrollView(
                reverse: true,
                scrollDirection: Axis.horizontal,
                child: Text(
                  calc.evaluated && calc.history.isNotEmpty
                      ? '${calc.history.first.expression} ='
                      : calc.expression.isEmpty
                      ? 'Можно начать с чего угодно'
                      : calc.expression
                            .replaceAll('×', ' × ')
                            .replaceAll('÷', ' ÷ ')
                            .replaceAll('+', ' + '),
                  key: const ValueKey('expression'),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Flavor.muted,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedSwitcher(
                  duration: gentle
                      ? Duration.zero
                      : const Duration(milliseconds: 380),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.35),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    key: ValueKey('${calc.resultRevision}/${calc.error}'),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        calc.error != null ? 'Упс…' : calc.resultText,
                        key: const ValueKey('result'),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -2.5,
                          height: 1.15,
                          color: calc.error != null ? flavor.deep : Flavor.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 18,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  calc.error ??
                      (calc.evaluated
                          ? 'Красиво получилось.'
                          : calc.expression.isEmpty
                          ? 'Или просто нажми любую цифру'
                          : calc.preview == null
                          ? 'Продолжай, я подожду'
                          : 'Ответ уже здесь · Enter, чтобы сохранить'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: calc.error != null ? flavor.deep : Flavor.muted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _memoryRow() => SizedBox(
    height: 29,
    child: Row(
      children: [
        for (final label in const ['MC', 'MR', 'M+', 'M−'])
          Expanded(
            child: Tooltip(
              message: {
                'MC': 'Очистить память',
                'MR': 'Вернуть число из памяти',
                'M+': 'Прибавить к памяти',
                'M−': 'Вычесть из памяти',
              }[label]!,
              child: TextButton(
                onPressed: () => _activate(label),
                style: TextButton.styleFrom(
                  foregroundColor: Flavor.muted,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  textStyle: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(label),
              ),
            ),
          ),
        SizedBox(
          width: 1,
          height: 12,
          child: ColoredBox(color: Flavor.muted.withValues(alpha: 0.22)),
        ),
        Expanded(
          child: TextButton(
            onPressed: () => _activate('Ans'),
            style: TextButton.styleFrom(
              foregroundColor: flavor.deep,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
            ),
            child: const Text(
              'Ans',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _scientificPad() => SizedBox(
    height: 118,
    child: Column(
      children: [
        Row(
          children: [
            Text(
              'Чуть больше магии',
              style: TextStyle(fontSize: 10, color: flavor.deep),
            ),
            const Spacer(),
            InkWell(
              onTap: calc.toggleDegrees,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                child: Text(
                  calc.degrees ? 'DEG / RAD' : 'RAD / DEG',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Flavor.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        for (final row in const [
          ['sin', 'cos', 'tan', '(', ')', 'π'],
          ['ln', 'log', '√', 'x²', 'x^y', 'n!'],
        ]) ...[
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: 7),
                  Expanded(
                    child: JellyButton(
                      label: row[i],
                      small: true,
                      color: flavor.light,
                      foreground: flavor.deep,
                      gentle: gentle,
                      pulse: _pulses[row[i]] ?? 0,
                      onPressed: () => _activate(row[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (row.first == 'sin') const SizedBox(height: 8),
        ],
      ],
    ),
  );

  Widget _keypad() => Column(
    children: [
      for (final row in const [
        ['AC', '±', '%', '÷'],
        ['7', '8', '9', '×'],
        ['4', '5', '6', '−'],
        ['1', '2', '3', '+'],
        ['⌫', '0', '.', '='],
      ]) ...[
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < row.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: JellyButton(
                    key: ValueKey('key-${row[i]}'),
                    label: row[i],
                    icon: row[i] == '⌫' ? Icons.backspace_outlined : null,
                    semanticLabel: {
                      'AC': 'Очистить',
                      '±': 'Сменить знак',
                      '%': 'Процент',
                      '÷': 'Разделить',
                      '×': 'Умножить',
                      '−': 'Вычесть',
                      '+': 'Сложить',
                      '⌫': 'Удалить символ',
                      '=': 'Равно',
                      '.': 'Десятичная точка',
                    }[row[i]],
                    color: row[i] == '='
                        ? flavor.accent
                        : i == 3
                        ? flavor.operatorColor
                        : row.first == 'AC'
                        ? flavor.light
                        : const Color(0xFFEDE8F0),
                    foreground: row[i] == '='
                        ? Colors.white
                        : row.first == 'AC'
                        ? flavor.deep
                        : Flavor.ink,
                    gentle: gentle,
                    pulse: _pulses[row[i]] ?? 0,
                    onPressed: () => _activate(row[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (row.first != '⌫') const SizedBox(height: 12),
      ],
    ],
  );

  Widget _history({VoidCallback? onRecall}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            const Icon(Icons.history_rounded, size: 18, color: Flavor.muted),
            const SizedBox(width: 9),
            const Text(
              'История',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (calc.history.isNotEmpty)
              _iconButton(
                Icons.delete_outline_rounded,
                'Очистить историю',
                calc.clearHistory,
                size: 17,
              ),
          ],
        ),
      ),
      const SizedBox(height: 7),
      const Text(
        'Твои маленькие открытия.',
        style: TextStyle(fontSize: 11, color: Flavor.muted),
      ),
      const SizedBox(height: 24),
      Container(height: 1, color: Flavor.muted.withValues(alpha: 0.14)),
      const SizedBox(height: 18),
      Expanded(
        child: calc.history.isEmpty
            ? _emptyHistory()
            : ListView.separated(
                itemCount: calc.history.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final entry = calc.history[i];
                  return Tooltip(
                    message: 'Вернуть выражение',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(19),
                      onTap: () {
                        calc.recall(entry);
                        onRecall?.call();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: i == 0 ? 0.68 : 0.39,
                          ),
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _date(entry.timestamp),
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: Flavor.muted,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.north_west_rounded,
                                  size: 11,
                                  color: flavor.deep.withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                            const SizedBox(height: 11),
                            Text(
                              entry.expression,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Flavor.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '= ${ExpressionEngine.format(entry.result, grouped: true)}',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.6,
                                color: i == 0 ? flavor.deep : Flavor.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Icon(
            calc.storageError == null
                ? Icons.lock_outline_rounded
                : Icons.info_outline_rounded,
            size: 12,
            color: Flavor.muted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              calc.storageError ?? 'Сохраняется только на этом устройстве',
              style: const TextStyle(fontSize: 8, color: Flavor.muted),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
    ],
  );

  Widget _emptyHistory() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: flavor.light.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white),
        ),
        child: Icon(
          Icons.more_horiz_rounded,
          size: 28,
          color: flavor.deep.withValues(alpha: 0.6),
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'Пока чистый лист',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      const Text(
        'Первый ответ появится здесь.\nА за ним — всё остальное.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, height: 1.8, color: Flavor.muted),
      ),
      const SizedBox(height: 60),
    ],
  );

  String _date(DateTime value) {
    final now = DateTime.now();
    final today =
        value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return today
        ? 'СЕГОДНЯ · $time'
        : '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')} · $time';
  }

  Widget _bottomBar(bool compact) => SizedBox(
    height: 25,
    child: Row(
      children: [
        if (compact || MediaQuery.sizeOf(context).width < 1100)
          _flavors()
        else
          Text(
            'SOFT ON THE OUTSIDE. SMART ON THE INSIDE.',
            style: TextStyle(
              fontSize: 8,
              letterSpacing: 1.4,
              color: Flavor.muted.withValues(alpha: 0.75),
            ),
          ),
        const Spacer(),
        if (!compact)
          const Text(
            'Enter — ответ   ·   Esc — чистый лист',
            style: TextStyle(fontSize: 9, color: Flavor.muted),
          )
        else
          Text(
            flavor.name,
            style: const TextStyle(fontSize: 10, color: Flavor.muted),
          ),
      ],
    ),
  );
}
