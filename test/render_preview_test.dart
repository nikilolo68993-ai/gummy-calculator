import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gummy_calculator/engine/calculator.dart';
import 'package:gummy_calculator/main.dart';

/// Produces screenshots of the real Flutter renderer for visual inspection.
/// Enable explicitly: flutter test test/render_preview_test.dart --dart-define=RENDER_PREVIEWS=true
void main() {
  const enabled = bool.fromEnvironment('RENDER_PREVIEWS');
  testWidgets('Render desktop and compact previews', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final c = Calculator()..gentleMotion = true;
    for (final expression in [
      '2480×3',
      '12000−15%',
      '(64+36)×8',
      'sqrt(144)+28',
    ]) {
      c.paste(expression);
      c.equals();
    }
    c.paste('2480×3');
    c.equals();
    final boundaryKey = GlobalKey();
    final cases = <(String, Size, int, bool)>[
      ('gummy-desktop.png', const Size(1180, 860), 0, false),
      ('gummy-lavender.png', const Size(1180, 860), 1, false),
      ('gummy-mint-scientific.png', const Size(1180, 990), 2, true),
      ('gummy-compact.png', const Size(460, 840), 0, false),
    ];
    for (final (name, size, flavor, scientific) in cases) {
      tester.view.physicalSize = size;
      c.flavor = flavor;
      c.scientific = scientific;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: GummyApp(calculator: c),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), null, reason: name);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('docs/previews').create(recursive: true);
        await File(
          'docs/previews/$name',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  }, skip: !enabled);
}
