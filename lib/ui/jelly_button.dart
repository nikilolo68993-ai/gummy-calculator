import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'flavor.dart';

/// Physical squash/stretch with a moving specular highlight, rather than a GIF.
class JellyButton extends StatefulWidget {
  const JellyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.foreground = Flavor.ink,
    this.icon,
    this.small = false,
    this.gentle = false,
    this.pulse = 0,
    this.semanticLabel,
  });
  final String label;
  final String? semanticLabel;
  final VoidCallback onPressed;
  final Color? color;
  final Color foreground;
  final IconData? icon;
  final bool small;
  final bool gentle;
  final int pulse;

  @override
  State<JellyButton> createState() => _JellyButtonState();
}

class _JellyButtonState extends State<JellyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spring = AnimationController.unbounded(
    vsync: this,
  );
  bool _hover = false;
  bool _focused = false;
  bool _pressed = false;
  Alignment _highlight = const Alignment(-0.5, -0.8);

  bool get _reduceMotion =>
      widget.gentle || MediaQuery.disableAnimationsOf(context);

  @override
  void didUpdateWidget(JellyButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulse != widget.pulse && widget.pulse > 0) _bounce();
    if (widget.gentle && !oldWidget.gentle) _spring.value = 0;
  }

  void _bounce() {
    if (_reduceMotion) return;
    _spring.value = 1;
    _spring.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 280, damping: 11),
        1,
        0,
        0,
      ),
    );
  }

  void _press(bool pressed) {
    setState(() => _pressed = pressed);
    if (_reduceMotion) return;
    if (pressed) {
      _spring.animateTo(
        1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
      );
    } else {
      _spring.animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 280, damping: 11),
          _spring.value,
          0,
          -1,
        ),
      );
    }
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.color ?? const Color(0xFFEDE8F0);
    final active = _hover || _focused;
    return Semantics(
      button: true,
      label: widget.semanticLabel ?? widget.label,
      child: Tooltip(
        message: widget.semanticLabel ?? widget.label,
        waitDuration: const Duration(milliseconds: 650),
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _bounce();
                widget.onPressed();
                return null;
              },
            ),
          },
          child: MouseRegion(
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() {
              _hover = false;
              _highlight = const Alignment(-0.5, -0.8);
            }),
            onHover: (event) {
              if (_reduceMotion) return;
              final box = context.findRenderObject() as RenderBox;
              setState(
                () => _highlight = Alignment(
                  (event.localPosition.dx / box.size.width * 2 - 1).clamp(
                    -1.0,
                    1.0,
                  ),
                  (event.localPosition.dy / box.size.height * 2 - 1).clamp(
                    -1.0,
                    1.0,
                  ),
                ),
              );
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _press(true),
              onTapUp: (_) => _press(false),
              onTapCancel: () => _press(false),
              onTap: widget.onPressed,
              child: AnimatedBuilder(
                animation: _spring,
                builder: (context, _) {
                  final wobble = _reduceMotion ? 0.0 : _spring.value;
                  final squash = 1 - wobble * 0.11;
                  final stretch = 1 + wobble * 0.055;
                  final tilt = _reduceMotion
                      ? 0.0
                      : (active ? _highlight.x * 0.025 : 0.0) +
                            math.sin(wobble * 2.4) * 0.016;
                  return Transform.translate(
                    offset: Offset(
                      0,
                      wobble * 4 - (active && !_reduceMotion ? 3 : 0),
                    ),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..rotateZ(tilt)
                        ..scaleByDouble(stretch, squash, 1, 1),
                      child: AnimatedContainer(
                        duration: _reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            widget.small ? 17 : 25,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color.lerp(
                                base,
                                Flavor.ink,
                                0.45,
                              )!.withValues(alpha: active ? 0.19 : 0.11),
                              offset: Offset(0, active ? 9 : 5),
                              blurRadius: active ? 18 : 9,
                              spreadRadius: -3,
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.95),
                              offset: const Offset(-2, -3),
                              blurRadius: 6,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: CustomPaint(
                          painter: _JellyPainter(
                            color: base,
                            highlight: _highlight,
                            active: active,
                            pressed: _pressed,
                            small: widget.small,
                          ),
                          child: Center(
                            child: widget.icon != null
                                ? Icon(
                                    widget.icon,
                                    size: widget.small ? 19 : 24,
                                    color: widget.foreground,
                                  )
                                : Text(
                                    widget.label,
                                    style: TextStyle(
                                      color: widget.foreground,
                                      fontSize: widget.small ? 14 : 28,
                                      fontWeight: FontWeight.w600,
                                      height: 1,
                                      letterSpacing: -0.8,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JellyPainter extends CustomPainter {
  _JellyPainter({
    required this.color,
    required this.highlight,
    required this.active,
    required this.pressed,
    required this.small,
  });
  final Color color;
  final Alignment highlight;
  final bool active;
  final bool pressed;
  final bool small;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = small ? 17.0 : 25.0;
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.save();
    canvas.clipRRect(shape);
    final top = Color.lerp(color, Colors.white, pressed ? 0.27 : 0.52)!;
    final bottom = Color.lerp(color, Flavor.ink, 0.07)!;
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width * 0.35, size.height),
          [top, color, bottom],
          [0, 0.6, 1],
        ),
    );
    // Subsurface glow gives the material depth and a translucent edge.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.57, size.height * 1.13),
        width: size.width * 1.1,
        height: size.height * 0.75,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    final shineRect = Rect.fromLTWH(7, 5, size.width - 14, size.height * 0.46);
    canvas.drawRRect(
      RRect.fromRectAndRadius(shineRect, Radius.circular(radius - 4)),
      Paint()
        ..shader =
            ui.Gradient.linear(shineRect.topCenter, shineRect.bottomCenter, [
              Colors.white.withValues(alpha: active ? 0.65 : 0.48),
              Colors.white.withValues(alpha: 0),
            ]),
    );
    final center = Offset(
      (highlight.x + 1) * size.width / 2,
      (highlight.y + 1) * size.height / 2,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(center, size.longestSide * 0.75, [
          Colors.white.withValues(alpha: active ? 0.32 : 0.12),
          Colors.transparent,
        ]),
    );
    canvas.restore();
    canvas.drawRRect(
      shape.deflate(0.65),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.15),
            bottom.withValues(alpha: 0.4),
          ],
          [0, 0.55, 1],
        ),
    );
    final edge = RRect.fromRectAndRadius(
      rect.deflate(4),
      Radius.circular(radius - 4),
    );
    canvas.drawRRect(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.65
        ..color = Colors.white.withValues(alpha: 0.24),
    );
  }

  @override
  bool shouldRepaint(_JellyPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.highlight != highlight ||
      oldDelegate.active != active ||
      oldDelegate.pressed != pressed ||
      oldDelegate.small != small;
}
