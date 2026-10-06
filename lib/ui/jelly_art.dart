import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'flavor.dart';

class CandyBackground extends StatelessWidget {
  const CandyBackground({
    super.key,
    required this.flavor,
    required this.child,
  });
  final Flavor flavor;
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(painter: _BackgroundPainter(flavor)),
          ),
        ),
      ),
      RepaintBoundary(child: child),
    ],
  );
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter(this.flavor);
  final Flavor flavor;
  static final List<Offset> _grain = List.generate(
    1800,
    (i) => Offset(
      math.Random(i * 37).nextDouble(),
      math.Random(i * 79 + 4).nextDouble(),
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = Flavor.paper);
    final halos = [
      (
        Offset(size.width * 0.47, size.height * 0.53),
        flavor.orb.withValues(alpha: 0.23),
        size.width * 0.46,
      ),
      (
        Offset(size.width * 0.84, size.height * 0.12),
        flavor.accent.withValues(alpha: 0.12),
        size.width * 0.36,
      ),
      (
        Offset(size.width * 0.05, size.height * 0.95),
        const Color(0xFFF5DAB1).withValues(alpha: 0.25),
        size.width * 0.33,
      ),
    ];
    for (final (center, color, radius) in halos) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(center, radius, [
            color,
            color.withValues(alpha: 0),
          ]),
      );
    }
    canvas.drawPoints(
      ui.PointMode.points,
      [
        for (final point in _grain)
          Offset(point.dx * size.width, point.dy * size.height),
      ],
      Paint()
        ..color = Flavor.ink.withValues(alpha: 0.035)
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => old.flavor != flavor;
}

class JellyMascot extends StatefulWidget {
  const JellyMascot({
    super.key,
    required this.flavor,
    required this.gentle,
    this.revision = 0,
    this.compact = false,
  });
  final Flavor flavor;
  final bool gentle;
  final int revision;
  final bool compact;
  @override
  State<JellyMascot> createState() => _JellyMascotState();
}

class _JellyMascotState extends State<JellyMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _time = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _reduce = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(JellyMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
    if (!_reduce && oldWidget.revision != widget.revision) {
      _time.forward(from: 0);
    }
  }

  void _sync() {
    _reduce = widget.gentle || MediaQuery.disableAnimationsOf(context);
    if (_reduce) {
      _time.stop();
      _time.value = 0;
    }
  }

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _time,
        builder: (context, _) => CustomPaint(
          size: widget.compact ? const Size(38, 38) : const Size(224, 190),
          painter: _MascotPainter(
            widget.flavor,
            _reduce ? 0 : _time.value,
            widget.compact,
          ),
        ),
      ),
    ),
  );
}

class _MascotPainter extends CustomPainter {
  _MascotPainter(this.flavor, this.time, this.compact);
  final Flavor flavor;
  final double time;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time * math.pi * 2;
    canvas.save();
    canvas.scale(size.width / 224, size.height / 190);
    canvas.drawOval(
      const Rect.fromLTWH(42, 157, 144, 15),
      Paint()
        ..color = flavor.deep.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.translate(0, math.sin(t) * 5);
    final wobble = math.sin(t + 1) * 7;
    final body = Path()
      ..moveTo(48, 143)
      ..cubicTo(22 + wobble, 121, 38, 72, 70, 49)
      ..cubicTo(83, 13 + wobble, 153, 17, 168, 55)
      ..cubicTo(205, 77, 198 - wobble, 131, 176, 145)
      ..cubicTo(156, 162, 69, 163, 48, 143);
    final bounds = const Rect.fromLTWH(31, 25, 169, 136);
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          bounds.topLeft,
          bounds.bottomRight,
          [
            Color.lerp(flavor.light, Colors.white, 0.35)!,
            flavor.accent.withValues(alpha: 0.83),
            flavor.deep.withValues(alpha: 0.79),
          ],
          [0, 0.57, 1],
        ),
    );
    canvas.save();
    canvas.clipPath(body);
    canvas.drawOval(
      const Rect.fromLTWH(54, 39, 106, 54),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 42),
          const Offset(0, 99),
          [Colors.white.withValues(alpha: 0.62), Colors.transparent],
        ),
    );
    canvas.drawOval(
      const Rect.fromLTWH(64, 134, 121, 21),
      Paint()
        ..color = flavor.light.withValues(alpha: 0.65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
    );
    canvas.drawOval(
      const Rect.fromLTWH(50, 57, 17, 37),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = ui.Gradient.linear(bounds.topLeft, bounds.bottomRight, [
          Colors.white.withValues(alpha: 0.95),
          Colors.white.withValues(alpha: 0.1),
        ]),
    );
    // A quiet little face. The icon uses the same exact material as the mascot.
    final ink = Paint()
      ..color = flavor.deep.withValues(alpha: 0.87)
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(98, 102), const Offset(98, 106), ink);
    canvas.drawLine(const Offset(132, 102), const Offset(132, 106), ink);
    canvas.drawArc(
      const Rect.fromLTWH(107, 107, 16, 12),
      0.1,
      math.pi - 0.2,
      false,
      ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    if (!compact) {
      final sparkle = Paint()
        ..color = flavor.orb.withValues(alpha: 0.8)
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(196, 41), const Offset(196, 55), sparkle);
      canvas.drawLine(const Offset(189, 48), const Offset(203, 48), sparkle);
      canvas.drawCircle(
        const Offset(29, 115),
        3,
        Paint()..color = flavor.accent.withValues(alpha: 0.5),
      );
      canvas.drawCircle(
        const Offset(171, 18),
        2,
        Paint()..color = flavor.orb.withValues(alpha: 0.65),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MascotPainter old) =>
      old.flavor != flavor || old.time != time || old.compact != compact;
}
