import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gummy_calculator/engine/calculator.dart';
import 'package:gummy_calculator/main.dart';

/// Records real Flutter frames; these can be assembled into a GIF with Pillow.
void main() {
  const enabled = bool.fromEnvironment('RENDER_MOTION');
  testWidgets(
    'Record squish, spring recovery and live result',
    (tester) async {
      tester.view.physicalSize = const Size(460, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final (family, asset) in [
        ('Manrope', 'assets/fonts/Manrope.ttf'),
        ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ]) {
        await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
      }
      final c = Calculator();
      c.paste('24×3');
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: GummyApp(calculator: c),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      final key = find.byKey(const ValueKey('key-='));
      final point = tester.getCenter(key);
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: point - const Offset(80, 0));
      await mouse.moveTo(point);
      await tester.pump(const Duration(milliseconds: 16));
      final transforms = find.descendant(
        of: key,
        matching: find.byType(Transform),
      );
      var mostSquashed = 1.0;
      for (var frame = 0; frame < 46; frame++) {
        if (frame == 4) await mouse.down(point);
        if (frame == 10) await mouse.up();
        if (frame == 28) await mouse.moveTo(point - const Offset(135, 55));
        await tester.pump(const Duration(milliseconds: 40));
        final transform = tester.widget<Transform>(transforms.last).transform;
        if (transform.entry(1, 1) < mostSquashed) {
          mostSquashed = transform.entry(1, 1);
        }
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('docs/motion-frames').create(recursive: true);
          await File(
            'docs/motion-frames/${frame.toString().padLeft(3, '0')}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(
        mostSquashed,
        lessThan(0.94),
        reason: 'The key really deforms under a press',
      );
      expect(c.answer, 72);
      expect(tester.takeException(), null);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
    },
    skip: !enabled,
    timeout: const Timeout(Duration(seconds: 50)),
  );
}
